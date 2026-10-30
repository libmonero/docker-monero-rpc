#!/usr/bin/env bash

# usage: save_images.sh <directory> <image>...
# saves images to <directory>/<name>.tar.zst, the name is the image without its tag
set -euo pipefail

DIR=$1
shift

mkdir -p "$DIR"
for image in "$@"; do
    name=${image%%:*}
    docker save "$image" | zstd -T0 -3 -o "$DIR/$name.tar.zst"
done
