#!/usr/bin/env bash

# usage: build_in_docker.sh <target> <binary> <output>
# builds in the docker build stages, on a throwaway copy of the sources without
# git metadata: the version tag is in /version and VARIANT names a patch to apply
set -euo pipefail

TARGET=$1
BINARY=$2
OUTPUT=$3
VARIANT=${VARIANT:-default}
TAG=$(cat /version)

cd /src
rm external/monero-project/.git

[ "$VARIANT" = default ] || git -C external/monero-project apply "/src/patches/$VARIANT.patch"

# what monero-project would have asked git for
release=false
[ "$TAG" != release ] || release=true
sed "s/@VERSIONTAG@/$TAG/;s/@VERSION_IS_RELEASE@/$release/" external/monero-project/src/version.cpp.in > external/monero-project/src/version.cpp.in.new
mv external/monero-project/src/version.cpp.in.new external/monero-project/src/version.cpp.in

MANUAL_SUBMODULES=1 ./bin/build_monero_rpc.sh "$TARGET"
ccache --show-stats
strip --strip-unneeded -o "$OUTPUT" "external/monero-project/build/release/bin/$BINARY"
