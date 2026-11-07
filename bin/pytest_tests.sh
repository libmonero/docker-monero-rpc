#!/usr/bin/env bash

# usage: pytest_tests.sh <monero-daemon-rpc image> <monero-wallet-rpc image> <monero-wallet-light image> [pytest arguments]
# runs the pytest tests of tests/, or the arguments, on containers of the images
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VENV=$ROOT/build/tests/venv

IMAGES=(--daemon-image "$1" --wallet-image "$2" --light-image "$3")
shift 3
[ $# -gt 0 ] || set -- "$ROOT/tests"

[ -d "$VENV" ] || python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet -r "$ROOT/tests/requirements.txt"

# the logs of the containers are in build/tests/logs
LOGS=$ROOT/build/tests/logs
rm -rf "$LOGS"

"$VENV/bin/pytest" "$@" "${IMAGES[@]}" --logs-dir "$LOGS" --log-file "$LOGS/pytest.log"
