# Define Mosquitto version, see also .github/workflows/build_and_push_docker_images.yml for
# the automatically built images
ARG MOSQUITTO_VERSION=2.0.20
# Define libwebsocket version
ARG LWS_VERSION=4.3.3

# Use debian:stable-slim as a builder for Mosquitto and dependencies.
FROM debian:stable-slim as mosquitto_builder
ARG MOSQUITTO_VERSION
ARG LWS_VERSION

# DeviceLinks MQTT Broker Envs
ENV DLMB_MYSQL_HOST=127.0.0.1 \
    DLMB_MYSQL_PORT=3306 \
    DLMB_MYSQL_DB=mosquitto \
    DLMB_MYSQL_USERNAME=root \
    DLMB_MYSQL_PASSWORD=123456

# Get mosquitto build dependencies.
RUN set -ex; \
    apt-get update; \
    apt-get install -y wget build-essential cmake libssl-dev libcjson-dev

# Get libwebsocket. Debian's libwebsockets is too old for Mosquitto version > 2.x so it gets built from source.
RUN set -ex; \
    wget https://github.com/warmcat/libwebsockets/archive/v${LWS_VERSION}.tar.gz -O /tmp/lws.tar.gz; \
    mkdir -p /build/lws; \
    tar --strip=1 -xf /tmp/lws.tar.gz -C /build/lws; \
    rm /tmp/lws.tar.gz; \
    cd /build/lws; \
    cmake . \
        -DCMAKE_BUILD_TYPE=MinSizeRel \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DLWS_IPV6=ON \
        -DLWS_WITHOUT_BUILTIN_GETIFADDRS=ON \
        -DLWS_WITHOUT_CLIENT=ON \
        -DLWS_WITHOUT_EXTENSIONS=ON \
        -DLWS_WITHOUT_TESTAPPS=ON \
        -DLWS_WITH_HTTP2=OFF \
        -DLWS_WITH_SHARED=OFF \
        -DLWS_WITH_ZIP_FOPS=OFF \
        -DLWS_WITH_ZLIB=OFF \
        -DLWS_WITH_EXTERNAL_POLL=ON; \
    make -j "$(nproc)"; \
    rm -rf /root/.cmake

WORKDIR /app

RUN mkdir -p mosquitto/auth mosquitto/conf.d

RUN wget http://mosquitto.org/files/source/mosquitto-${MOSQUITTO_VERSION}.tar.gz

RUN tar xzvf mosquitto-${MOSQUITTO_VERSION}.tar.gz

# Build mosquitto.
RUN set -ex; \
    cd mosquitto-${MOSQUITTO_VERSION}; \
    make CFLAGS="-Wall -O2 -I/build/lws/include" LDFLAGS="-L/build/lws/lib" WITH_WEBSOCKETS=yes; \
    make install;

# Use golang:latest as a builder for the Mosquitto Go Auth plugin.
FROM --platform=$BUILDPLATFORM golang:latest AS go_auth_builder

ENV CGO_CFLAGS="-I/usr/local/include -fPIC"
ENV CGO_LDFLAGS="-shared -Wl,-unresolved-symbols=ignore-all"
ENV CGO_ENABLED=1

# Bring TARGETPLATFORM to the build scope
ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Install TARGETPLATFORM parser to translate its value to GOOS, GOARCH, and GOARM
COPY --from=tonistiigi/xx:golang / /
RUN go env

# Install needed libc and gcc for target platform.
RUN set -ex; \
  if [ ! -z "$TARGETPLATFORM" ]; then \
    case "$TARGETPLATFORM" in \
  "linux/arm64") \
    apt update && apt install -y gcc-aarch64-linux-gnu libc6-dev-arm64-cross \
    ;; \
  "linux/amd64") \
    apt update && apt install -y libc6 g++-x86-64-linux-gnu libc6-dev-amd64-cross gcc \
    ;; \
  "linux/arm/v7") \
    apt update && apt install -y gcc-arm-linux-gnueabihf libc6-dev-armhf-cross \
    ;; \
  "linux/arm/v6") \
    apt update && apt install -y gcc-arm-linux-gnueabihf libc6-dev-armel-cross libc6-dev-armhf-cross \
    ;; \
  esac \
  fi

WORKDIR /app
COPY --from=mosquitto_builder /usr/local/include/ /usr/local/include/

COPY ./ ./
RUN set -ex; \
    go build -buildmode=c-archive go-auth.go; \
    go build -buildmode=c-shared -o go-auth.so; \
	  go build pw-gen/pw.go

#Start from a new image.
FROM debian:stable-slim

RUN set -ex; \
    apt update; \
    apt install -y libc-ares2 openssl uuid tini wget libssl-dev libcjson-dev

RUN mkdir -p /var/mosquitto/ssl /var/mosquitto/data /var/mosquitto/log /var/mosquitto/conf.d /var/mosquitto/plugins /usr/local/shell

RUN set -ex; \
    groupadd mosquitto; \
    useradd -s /sbin/nologin mosquitto -g mosquitto -d /var/lib/mosquitto; \
    chown -R mosquitto:mosquitto /var/mosquitto/

# init startup
ADD startup.sh /usr/local/shell/startup.sh
RUN set -ex; \
    chmod u+x /usr/local/shell/startup.sh

# init auth.conf
ADD auth-setup.sh /usr/local/shell/auth-setup.sh
RUN set -ex; \
    chmod u+x /usr/local/shell/auth-setup.sh

# init mosquitto.conf
ADD mosquitto-setup.sh /usr/local/shell/mosquitto-setup.sh
RUN set -ex; \
    chmod u+x /usr/local/shell/mosquitto-setup.sh; \
    bash /usr/local/shell/mosquitto-setup.sh; \
    rm -rf /usr/local/shell/mosquitto-setup.sh


#Copy confs, plugin so and mosquitto binary.
COPY --from=mosquitto_builder /app/mosquitto/ /var/mosquitto/
COPY --from=go_auth_builder /app/pw /var/mosquitto/plugins/pw
COPY --from=go_auth_builder /app/go-auth.so /var/mosquitto/plugins/go-auth.so
COPY --from=mosquitto_builder /usr/local/sbin/mosquitto /usr/sbin/mosquitto

COPY --from=mosquitto_builder /usr/local/lib/libmosquitto* /usr/local/lib/

COPY --from=mosquitto_builder /usr/local/bin/mosquitto_passwd /usr/bin/mosquitto_passwd
COPY --from=mosquitto_builder /usr/local/bin/mosquitto_sub /usr/bin/mosquitto_sub
COPY --from=mosquitto_builder /usr/local/bin/mosquitto_pub /usr/bin/mosquitto_pub
COPY --from=mosquitto_builder /usr/local/bin/mosquitto_rr /usr/bin/mosquitto_rr

RUN ldconfig;

EXPOSE 1883 8883 8884

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/shell/startup.sh" ,"$DLMB_MYSQL_HOST","$DLMB_MYSQL_PORT","$DLMB_MYSQL_DB","$DLMB_MYSQL_USERNAME","$DLMB_MYSQL_PASSWORD"]
