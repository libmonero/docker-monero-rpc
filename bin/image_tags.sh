#!/usr/bin/env bash

# usage: image_tags.sh <tags> <latest: true|false>
# prints the tags, adding latest when requested
set -euo pipefail

TAGS=$1
LATEST=$2

list=$TAGS
[ "$LATEST" != true ] || list="$list latest"
echo "$list"
