#!/usr/bin/env bash

# usage: image_tags.sh <default|private-testnet> <tags> <latest: true|false>
# prints the tags of a variant, which are prefixed with its name, its latest is the name
set -euo pipefail

VARIANT=$1
TAGS=$2
LATEST=$3

prefix=
[ "$VARIANT" = default ] || prefix="$VARIANT-"
list=
for tag in $TAGS; do list="$list $prefix$tag"; done
if [ "$LATEST" = true ]; then
    if [ "$VARIANT" = default ]; then list="$list latest"; else list="$list $VARIANT"; fi
fi
echo "${list# }"
