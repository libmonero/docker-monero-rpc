#!/usr/bin/env bash

# build monerod and monero-wallet-rpc from the monero-project submodule;
# targets can be passed as arguments, e.g. daemon (default: daemon wallet_rpc_server)
cd ./external/monero-project/ || exit 1
if git rev-parse --git-dir > /dev/null 2>&1; then
    git submodule update --init --force || exit 1
fi
TARGETS=${*:-daemon wallet_rpc_server}
HOST_NCORES=${NPROC:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)}

# explicit ARCH avoids -march=native (CPU-specific binaries)
case $(uname -m) in
    x86_64) ARCH="x86-64";;
    arm64|aarch64) ARCH="armv8-a";;
    *) ARCH="native";;
esac

# musl threads get a 128 KB stack, libunbound crashes on it when resolving openalias
# TARGETS and MANUAL_SUBMODULES are split on purpose
# shellcheck disable=SC2086
( mkdir -p build/release &&
  cd build/release &&
  cmake -D STATIC=ON -D ARCH="$ARCH" -D BUILD_64=ON -D CMAKE_BUILD_TYPE=Release -D USE_DEVICE_TREZOR=OFF -D USE_READLINE=OFF -D STACK_TRACE=OFF -D CMAKE_EXE_LINKER_FLAGS="-static -Wl,-z,stack-size=8388608" ${MANUAL_SUBMODULES:+-D MANUAL_SUBMODULES=1} ../../ &&
  make -j"$HOST_NCORES" $TARGETS ) || exit 1
