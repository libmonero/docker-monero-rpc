#!/usr/bin/env bash

# usage: extract_binaries.sh <monero-daemon-rpc image> <monero-wallet-rpc image> <directory>
set -euo pipefail

DAEMON_IMAGE=$1
WALLET_IMAGE=$2
DIR=$3

mkdir -p "$DIR"

extract() {
    local container
    container=$(docker create "$1")
    docker cp "$container:/usr/local/bin/$2" "$DIR/$2"
    docker rm "$container" > /dev/null
}
extract "$DAEMON_IMAGE" monerod
extract "$WALLET_IMAGE" monero-wallet-rpc
