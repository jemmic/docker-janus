############################################################
# Dockerfile - Janus Gateway on Debian Buster
# https://github.com/jemmic/docker-janus
############################################################

# set base image debian buster with minimal packages installed
FROM debian:buster-slim

# file maintainer author
MAINTAINER Christophe Kamphaus <christophe.kamphaus@jemmic.com>
LABEL maintainer="Christophe Kamphaus <christophe.kamphaus@jemmic.com>"

# docker build environments
ENV CONFIG_PATH="/opt/janus/etc/janus"

# docker build arguments
ARG BUILD_SRC="/usr/local/src"

ARG JANUS_VERSION="v1.0.0"
ARG JANUS_LIBNICE_VERSION="0.1.18"
ARG JANUS_PAHO_MQTT_VERSION="v1.3.4"
ARG JANUS_RABBITMQ_VERSION="v1.0.4"
ARG JANUS_LIBSRTP_VERSION="2.3.0"
ARG JANUS_USRSCTP_VERSION="0.9.5.0"
ARG JANUS_BORINGSSL_VERSION="ac3f4fb8e1e3fd6da51033514e247e7924b16439"
ARG JANUS_LIBWEBSOCKETS_VERSION="v4.3.0"

ARG JANUS_WITH_POSTPROCESSING="1"
ARG JANUS_WITH_BORINGSSL="1"
ARG JANUS_WITH_DOCS="0"
ARG JANUS_WITH_REST="1"
ARG JANUS_WITH_DATACHANNELS="0"
ARG JANUS_WITH_WEBSOCKETS="0"
ARG JANUS_WITH_MQTT="0"
ARG JANUS_WITH_PFUNIX="0"
ARG JANUS_WITH_RABBITMQ="0"
# https://goo.gl/dmbvc1
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

ADD ./build.sh /tmp
RUN /tmp/build.sh \
    && rm /tmp/build.sh

USER janus

# exposed ports
EXPOSE 10000-10200/udp
EXPOSE 8088
EXPOSE 8089
EXPOSE 8889
EXPOSE 8000
EXPOSE 7088
EXPOSE 7089

CMD ["/opt/janus/bin/janus"]
