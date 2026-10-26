#!/bin/sh

# install monero-project build dependencies on alpine (static build)
set -e

EXPAT_VERSION=2.7.1
EXPAT_TAG=R_2_7_1
EXPAT_SHA256=45c98ae1e9b5127325d25186cf8c511fa814078e9efeae7987a574b482b79b3d
ZEROMQ_VERSION=4.3.4
ZEROMQ_SHA256=c593001a89f5a85dd2ddf564805deb860e02471171b3f204944857336295c3e5
UNBOUND_VERSION=1.22.0
UNBOUND_SHA256=c5dd1bdef5d5685b2cedb749158dd152c52d44f65529a34ac15cd88d4b1b3d43
NPROC=${NPROC:-$(nproc)}

apk add --no-cache \
    bison boost-atomic boost-chrono boost-date_time boost-dev boost-filesystem \
    boost-program_options boost-random boost-regex boost-serialization boost-static \
    boost-system boost-thread ca-certificates ccache cmake eudev-dev file flex g++ git \
    libsodium-dev libsodium-static libusb-dev linux-headers make miniupnpc-dev \
    openssl-dev openssl-libs-static pcsc-lite-dev pkgconf protobuf-dev rapidjson-dev wget

# static libs built from source, built with -fPIC to match monero-project
export CFLAGS='-fPIC'
export CXXFLAGS='-fPIC'
cd /tmp

wget "https://github.com/libexpat/libexpat/releases/download/${EXPAT_TAG}/expat-${EXPAT_VERSION}.tar.bz2"
echo "${EXPAT_SHA256}  expat-${EXPAT_VERSION}.tar.bz2" | sha256sum -c
tar -xf "expat-${EXPAT_VERSION}.tar.bz2"
(cd "expat-${EXPAT_VERSION}" &&
    ./configure --enable-static --disable-shared --with-pic --prefix=/usr &&
    make -j"${NPROC}" && make install)

wget "https://www.nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz"
echo "${UNBOUND_SHA256}  unbound-${UNBOUND_VERSION}.tar.gz" | sha256sum -c
tar xzf "unbound-${UNBOUND_VERSION}.tar.gz"
(cd "unbound-${UNBOUND_VERSION}" &&
    ./configure --enable-static --disable-shared --with-pic --prefix=/usr \
        --with-libexpat=/usr --with-ssl=/usr --with-libevent=no --with-pthreads \
        --with-libunbound-only --without-pyunbound --without-pythonmodule --disable-flto &&
    make -j"${NPROC}" && make install)

wget "https://github.com/zeromq/libzmq/releases/download/v${ZEROMQ_VERSION}/zeromq-${ZEROMQ_VERSION}.tar.gz"
echo "${ZEROMQ_SHA256}  zeromq-${ZEROMQ_VERSION}.tar.gz" | sha256sum -c
tar xzf "zeromq-${ZEROMQ_VERSION}.tar.gz"
(cd "zeromq-${ZEROMQ_VERSION}" &&
    ./configure --enable-static --disable-shared --with-pic --prefix=/usr --with-libsodium \
        --disable-Werror --disable-libbsd --without-docs &&
    make -j"${NPROC}" && make install)

rm -rf /tmp/expat-* /tmp/unbound-* /tmp/zeromq-*
