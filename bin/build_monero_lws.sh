#!/usr/bin/env bash

# build monero-lws-daemon, monero-lws-admin and its unit tests from the monero-lws submodule,
# against the monero-project submodule
cd ./external/monero-lws/ || exit 1
HOST_NCORES=${NPROC:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)}

# same linker flags as build_monero_rpc.sh, monero-lws takes the ARCH of monero-project as default
( mkdir -p build &&
  cd build &&
  cmake -D STATIC=ON -D BUILD_64=ON -D CMAKE_BUILD_TYPE=Release -D MONERO_SOURCE_DIR="$PWD/../../monero-project" -D MANUAL_SUBMODULES=1 -D USE_DEVICE_TREZOR=OFF -D USE_READLINE=OFF -D STACK_TRACE=OFF -D LWS_DEAD_FUNCTION_REMOVAL=ON -D BUILD_TESTS=ON -D CMAKE_EXE_LINKER_FLAGS="-static -Wl,-z,stack-size=8388608" ../ &&
  make -j"$HOST_NCORES" monero-lws-daemon monero-lws-admin monero-lws-unit ) || exit 1
