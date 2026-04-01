############################################################
# Dockerfile - Janus Gateway on Debian Bullseye
# https://github.com/jemmic/docker-janus
############################################################

# set base image debian bullseye with minimal packages installed

# --- Build stage ---
FROM debian:bookworm-slim AS builder

LABEL org.opencontainers.image.authors="Jemmic infrastructure <jemmic-infrastructure@jemmic.com>"

ARG BUILD_SRC="/usr/local/src"

ARG JANUS_VERSION="v1.2.4"
ARG JANUS_LIBNICE_VERSION="0.1.22"
ARG JANUS_PAHO_MQTT_VERSION="v1.3.12"
ARG JANUS_RABBITMQ_VERSION="v0.13.0"
ARG JANUS_LIBSRTP_VERSION="2.6.0"
ARG JANUS_USRSCTP_VERSION="0.9.5.0"
ARG JANUS_BORINGSSL_VERSION="0568c2c1dbff4e1de4d5a63fbaf7d13925df27fa"
ARG JANUS_LIBWEBSOCKETS_VERSION="v4.3.3"

ARG JANUS_WITH_POSTPROCESSING="1"
ARG JANUS_WITH_BORINGSSL="0"
ARG JANUS_WITH_DOCS="0"
ARG JANUS_WITH_REST="1"
ARG JANUS_WITH_DATACHANNELS="1"
ARG JANUS_WITH_WEBSOCKETS="0"
ARG JANUS_WITH_MQTT="0"
ARG JANUS_WITH_PFUNIX="0"
ARG JANUS_WITH_RABBITMQ="0"
ARG JANUS_WITH_FREESWITCH_PATCH="0"
ARG JANUS_CONFIG_DEPS="\
    --prefix=/opt/janus \
    "
ARG JANUS_CONFIG_OPTIONS="\
    "
ARG JANUS_BUILD_DEPS_DEV="\
    libcurl4-openssl-dev \
    libjansson-dev \
    libssl-dev \
    libsofia-sip-ua-dev \
    libglib2.0-dev \
    liblua5.3-dev \
    libconfig-dev \
    libopus-dev \
    libogg-dev \
    pkg-config \
    python3 \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    ninja-build \
    meson \
    libnice-dev \
    zlib1g-dev \
    libsrtp2-dev \
    libmicrohttpd-dev \
    "
ARG JANUS_BUILD_DEPS_EXT="\
    libavutil-dev \
    libavcodec-dev \
    libavformat-dev \
    gengetopt \
    libtool \
    automake \
    git-core \
    build-essential \
    cmake \
    ca-certificates \
    curl \
    gtk-doc-tools \
    "

# Set Janus config options based on build args
RUN if [ "$JANUS_WITH_POSTPROCESSING" = "1" ]; then export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --enable-post-processing"; fi \
    && if [ "$JANUS_WITH_BORINGSSL" = "1" ]; then echo "deb http://deb.debian.org/debian bookworm-backports main" >> /etc/apt/sources.list && export JANUS_BUILD_DEPS_DEV="$JANUS_BUILD_DEPS_DEV golang-go/bookworm-backports golang-src/bookworm-backports" && export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --enable-boringssl --enable-dtls-settimeout"; else export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-boringssl"; fi \
    && if [ "$JANUS_WITH_DOCS" = "1" ]; then export JANUS_BUILD_DEPS_DEV="$JANUS_BUILD_DEPS_DEV graphviz" && export JANUS_BUILD_DEPS_EXT="$JANUS_BUILD_DEPS_EXT flex bison file sensible-utils" && export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --enable-docs"; fi \
    && if [ "$JANUS_WITH_REST" = "1" ]; then export JANUS_BUILD_DEPS_DEV="$JANUS_BUILD_DEPS_DEV libmicrohttpd-dev"; else export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-rest"; fi \
    && if [ "$JANUS_WITH_DATACHANNELS" = "0" ]; then export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-data-channels"; fi \
    && if [ "$JANUS_WITH_WEBSOCKETS" = "0" ]; then export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-websockets"; fi \
    && if [ "$JANUS_WITH_MQTT" = "0" ]; then export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-mqtt"; fi \
    && if [ "$JANUS_WITH_PFUNIX" = "0" ]; then export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-unix-sockets"; fi \
    && if [ "$JANUS_WITH_RABBITMQ" = "0" ]; then export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-rabbitmq"; fi

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get -yq --no-install-recommends install $JANUS_BUILD_DEPS_DEV $JANUS_BUILD_DEPS_EXT

# build libnice
RUN git clone https://gitlab.freedesktop.org/libnice/libnice $BUILD_SRC/libnice \
    && cd $BUILD_SRC/libnice \
    && git checkout $JANUS_LIBNICE_VERSION \
    && meson builddir --prefix=/opt/janus --libdir=lib \
    && ninja -C builddir \
    && ninja -C builddir install

# build libsrtp
RUN curl -fSL https://github.com/cisco/libsrtp/archive/v$JANUS_LIBSRTP_VERSION.tar.gz -o $BUILD_SRC/v$JANUS_LIBSRTP_VERSION.tar.gz \
    && tar xzf $BUILD_SRC/v$JANUS_LIBSRTP_VERSION.tar.gz -C $BUILD_SRC \
    && cd $BUILD_SRC/libsrtp-$JANUS_LIBSRTP_VERSION \
    && ./configure --prefix=/opt/janus --enable-openssl \
    && make shared_library \
    && make install

# build boringssl (if enabled)
RUN if [ "$JANUS_WITH_BORINGSSL" = "1" ]; then \
        git clone https://boringssl.googlesource.com/boringssl $BUILD_SRC/boringssl && \
        cd $BUILD_SRC/boringssl && \
        git checkout $JANUS_BORINGSSL_VERSION && \
        sed -i s/" -Werror"//g CMakeLists.txt && \
        mkdir -p $BUILD_SRC/boringssl/build && \
        cd $BUILD_SRC/boringssl/build && \
        cmake -DCMAKE_CXX_FLAGS="-lrt" .. && \
        make && \
        mkdir -p /opt/janus/boringssl && \
        cp -R $BUILD_SRC/boringssl/include /opt/janus/boringssl/ && \
        mkdir -p /opt/janus/boringssl/lib && \
        cp $BUILD_SRC/boringssl/build/ssl/libssl.a /opt/janus/boringssl/lib/ && \
        cp $BUILD_SRC/boringssl/build/crypto/libcrypto.a /opt/janus/boringssl/lib/ ; \
    fi

# build usrsctp (if enabled)
RUN if [ "$JANUS_WITH_DATACHANNELS" = "1" ]; then \
        git clone https://github.com/sctplab/usrsctp $BUILD_SRC/usrsctp && \
        cd $BUILD_SRC/usrsctp && \
        git checkout $JANUS_USRSCTP_VERSION && \
        ./bootstrap && \
        ./configure --prefix=/opt/janus && \
        make && \
        make install ; \
    fi

# build libwebsockets (if enabled)
RUN if [ "$JANUS_WITH_WEBSOCKETS" = "1" ]; then \
        git clone https://github.com/warmcat/libwebsockets.git $BUILD_SRC/libwebsockets && \
        cd $BUILD_SRC/libwebsockets && \
        git checkout $JANUS_LIBWEBSOCKETS_VERSION && \
        mkdir $BUILD_SRC/libwebsockets/build && \
        cd $BUILD_SRC/libwebsockets/build && \
        cmake -DLWS_MAX_SMP=1 -DLWS_IPV6=ON -DCMAKE_INSTALL_PREFIX:PATH=/opt/janus -DCMAKE_C_FLAGS="-fpic" .. && \
        make && \
        make install ; \
    fi

# build paho.mqtt.c (if enabled)
RUN if [ "$JANUS_WITH_MQTT" = "1" ]; then \
        git clone https://github.com/eclipse/paho.mqtt.c.git $BUILD_SRC/paho.mqtt.c && \
        cd $BUILD_SRC/paho.mqtt.c && \
        git checkout $JANUS_PAHO_MQTT_VERSION && \
        make && \
        make install DESTDIR=/opt/janus ; \
    fi

# build rabbitmq-c (if enabled)
RUN if [ "$JANUS_WITH_RABBITMQ" = "1" ]; then \
        git clone https://github.com/alanxz/rabbitmq-c $BUILD_SRC/rabbitmq-c && \
        cd $BUILD_SRC/rabbitmq-c && \
        git checkout $JANUS_RABBITMQ_VERSION && \
        git submodule init && \
        git submodule update && \
        mkdir $BUILD_SRC/rabbitmq-c/build && \
        cd $BUILD_SRC/rabbitmq-c/build && \
        cmake -DCMAKE_INSTALL_PREFIX=/opt/janus .. && \
        cmake --build . --target install ; \
    fi

# build doxygen (if enabled)
RUN if [ "$JANUS_WITH_DOCS" = "1" ]; then \
        curl -fSL http://ftp.de.debian.org/debian/pool/main/c/checkinstall/checkinstall_1.6.2+git20170426.d24a630-2~bpo10+1_amd64.deb -o $BUILD_SRC/checkinstall.deb && \
        cd $BUILD_SRC && \
        echo "ce3fec00c5129dca445d759bbe5996b8f51cb4fb68744ca4c1c41c04f38aa9a5 checkinstall.deb" | sha256sum -c - && \
        dpkg -i $BUILD_SRC/checkinstall.deb && \
        git clone https://github.com/doxygen/doxygen.git $BUILD_SRC/doxygen && \
        cd $BUILD_SRC/doxygen && \
        git checkout Release_1_8_11 && \
        mkdir $BUILD_SRC/doxygen/build && \
        cd $BUILD_SRC/doxygen/build && \
        cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=/opt/janus .. && \
        make && \
        checkinstall --pkgname doxygen -y --install=no --fstrans=yes --pkgversion=1.8.11 --default --pakdir=/opt/janus ; \
    fi

# build janus-gateway
RUN git clone https://github.com/meetecho/janus-gateway.git $BUILD_SRC/janus-gateway \
    && if [ "$JANUS_WITH_FREESWITCH_PATCH" = "1" ]; then curl -fSL https://raw.githubusercontent.com/krull/docker-misc/master/init_fs/tmp/janus_sip.c.patch -o $BUILD_SRC/janus-gateway/plugins/janus_sip.c.patch && cd $BUILD_SRC/janus-gateway/plugins && patch < janus_sip.c.patch; fi \
    && cd $BUILD_SRC/janus-gateway \
    && git checkout $JANUS_VERSION \
    && ./autogen.sh \
    && ./configure --prefix=/opt/janus $JANUS_CONFIG_DEPS $JANUS_CONFIG_OPTIONS \
    && make \
    && make install \
    && make configs

# Collect all shared library dependencies using ldd and stage them for the scratch image
# Also captures the ELF interpreter (ld-linux-x86-64.so.2) which has no '=>' in ldd output
RUN mkdir -p /depscan/libs && \
    find /opt/janus/bin /opt/janus/lib -type f \( -executable -o -name '*.so*' \) | \
    xargs -I{} ldd {} 2>/dev/null | \
    awk 'NF==4 && /=> \// {print $3} NF==2 && $1~/^\// {print $1}' | \
    sort -u | grep -E '^/' | \
    xargs -I{} cp --parents -v {} /depscan/libs

# --- Production stage ---
FROM scratch AS production

WORKDIR /opt/janus

COPY janus/etc/janus /opt/janus/etc/janus

# Copy Janus binaries, plugins, configs, and all built shared libraries
COPY --from=builder --chown=65534:65534  /opt/janus /opt/janus

# Copy only the required shared libraries discovered by ldd
COPY --from=builder --chown=65534:65534 /depscan/libs/ /

# Set library path for Janus runtime
ENV LD_LIBRARY_PATH="/opt/janus/lib:/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu:/lib:/usr/lib"

# exposed ports
EXPOSE 10000-10200/udp
EXPOSE 8088
EXPOSE 8089
EXPOSE 8889
EXPOSE 8000
EXPOSE 7088
EXPOSE 7089

USER 65534:65534

CMD ["/opt/janus/bin/janus"]
