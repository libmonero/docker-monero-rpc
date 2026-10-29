#!/usr/bin/env bash

# usage: build_in_docker.sh <daemon|wallet_rpc_server|lws> <output directory>
# builds in the docker build stages, on a throwaway copy of the sources without
# git metadata: the version tag is in /version and VARIANT names a patch to apply
set -euo pipefail

TARGET=$1
OUTPUT=$2
VARIANT=${VARIANT:-default}
TAG=$(cat /version)

cd /src
rm -f external/*/.git

[ "$VARIANT" = default ] || git -C external/monero-project apply "/src/patches/$VARIANT.patch"

# what monero-project would have asked git for
release=false
[ "$TAG" != release ] || release=true
sed "s/@VERSIONTAG@/$TAG/;s/@VERSION_IS_RELEASE@/$release/" external/monero-project/src/version.cpp.in > external/monero-project/src/version.cpp.in.new
mv external/monero-project/src/version.cpp.in.new external/monero-project/src/version.cpp.in

case $TARGET in
    daemon)
        MANUAL_SUBMODULES=1 ./bin/build_monero_rpc.sh daemon
        binaries=(external/monero-project/build/release/bin/monerod) ;;
    wallet_rpc_server)
        MANUAL_SUBMODULES=1 ./bin/build_monero_rpc.sh wallet_rpc_server
        binaries=(external/monero-project/build/release/bin/monero-wallet-rpc) ;;
    lws)
        ./bin/build_monero_lws.sh
        external/monero-lws/build/tests/unit/monero-lws-unit
        binaries=(external/monero-lws/build/src/monero-lws-daemon external/monero-lws/build/src/monero-lws-admin) ;;
    *)
        echo "unknown target $TARGET" >&2
        exit 1 ;;
esac
ccache --show-stats

mkdir -p "$OUTPUT"
for binary in "${binaries[@]}"; do
    strip --strip-unneeded -o "$OUTPUT/${binary##*/}" "$binary"
done
