#!/usr/bin/env bash

# usage: extract_binaries.sh <directory> <image> <binary>...
set -euo pipefail

DIR=$1
IMAGE=$2
shift 2

mkdir -p "$DIR"

container=$(docker create "$IMAGE")
for binary in "$@"; do
    docker cp "$container:/usr/local/bin/$binary" "$DIR/$binary"
done
docker rm "$container" > /dev/null
