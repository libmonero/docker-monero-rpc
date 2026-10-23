#!/usr/bin/env bash

# usage: sync_monero_cpp.sh <monero-cpp tag>, e.g. v0.9.10
# moves the monero-project submodule to the commit pinned by that monero-cpp release
set -euo pipefail

TAG=${1:?usage: $0 <monero-cpp tag>}
MONERO_CPP=${MONERO_CPP:-woodser/monero-cpp}

cd "$(dirname "$0")/.."

commit=$(curl -fsSL "https://api.github.com/repos/$MONERO_CPP/contents/external/monero-project?ref=$TAG" |
    sed -n 's/^ *"sha": "\([0-9a-f]\{40\}\)".*/\1/p' | head -1)
[ -n "$commit" ] || { echo "no monero-project commit found in $MONERO_CPP $TAG"; exit 1; }

cd external/monero-project
git fetch --quiet origin "$commit"
git checkout --quiet "$commit"
git submodule update --init --recursive --force --quiet
cd ../..

echo "$MONERO_CPP $TAG pins monero-project ${commit:0:9}, $(./bin/monero_version.sh)"
