#!/usr/bin/env bash

# usage: package_release.sh <registry> <tag>
# packs the binaries of the images of a release for both variants and architectures into release/
set -euo pipefail

REGISTRY=$1
TAG=$2

mkdir release
for variant in default private-testnet; do
    prefix=
    [ "$variant" = default ] || prefix="$variant-"
    for platform in linux/amd64:linux-x86_64 linux/arm64:linux-arm64; do
        arch=${platform#*:}
        staging="monero-rpc-$prefix$TAG-$arch"
        mkdir "$staging"
        for pair in monero-daemon-rpc:monerod monero-wallet-rpc:monero-wallet-rpc monero-wallet-light:monero-lws-daemon monero-wallet-light:monero-lws-admin; do
            id=$(docker create --platform "${platform%:*}" "$REGISTRY/${pair%:*}:$prefix$TAG")
            docker cp "$id:/usr/local/bin/${pair#*:}" "$staging/"
            docker cp "$id:/usr/share/licenses/monero-project/LICENSE" "$staging/LICENSE"
            [ "${pair%:*}" != monero-wallet-light ] || docker cp "$id:/usr/share/licenses/monero-lws/LICENSE" "$staging/LICENSE-monero-lws"
            docker rm "$id" > /dev/null
        done
        tar czf "release/$staging.tar.gz" "$staging"
    done
done
cd release
sha256sum ./*.tar.gz > SHA256SUMS
cat SHA256SUMS
