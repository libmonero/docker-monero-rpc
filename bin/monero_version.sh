#!/usr/bin/env bash

# print the version monero-project reports for the submodule commit
cd "$(dirname "$0")/../external/monero-project" || exit 1
version=$(sed -n 's/^#define DEF_MONERO_VERSION "\(.*\)"$/\1/p' src/version.cpp.in)
tag=$(git rev-parse --short=9 HEAD)
test -z "$(git tag -l --points-at HEAD)" || tag=release
echo "v${version}-${tag}"
