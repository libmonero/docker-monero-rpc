#!/usr/bin/env bash

# print the next release tag for the monero version of the submodule, e.g. v0.18.5.1-2
# REPO is where the existing tags are looked up
set -euo pipefail

REPO=${REPO:-https://github.com/libmonero/docker-monero-rpc}

version=$("$(dirname "$0")/monero_version.sh")
version=${version%-*}

last=$(git ls-remote --tags --refs "$REPO" "refs/tags/$version-*" | sed 's|.*refs/tags/.*-||' | sort -n | tail -1)
echo "$version-$(( ${last:-0} + 1 ))"
