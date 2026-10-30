#!/usr/bin/env bash

# usage: load_images.sh <directory>
# loads the images saved by save_images.sh
set -euo pipefail

for file in "$1"/*.tar.zst; do
    zstd -dc "$file" | docker load
done
