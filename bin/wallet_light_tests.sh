#!/usr/bin/env bash

# usage: wallet_light_tests.sh <monero-daemon-rpc image> <monero-wallet-rpc image> <monero-wallet-light image> [default|private-testnet]
# runs the tests of tests/ on a node, a wallet and a light wallet server started from the images
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VENV=$ROOT/build/tests/venv

[ -d "$VENV" ] || python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet -r "$ROOT/tests/requirements.txt"

"$VENV/bin/pytest" "$ROOT/tests" --daemon-image "$1" --wallet-image "$2" --light-image "$3" --variant "${4:-default}"
