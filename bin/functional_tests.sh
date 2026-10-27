#!/usr/bin/env bash

# usage: functional_tests.sh <directory with monerod and monero-wallet-rpc> [tests...]
# runs the python functional tests of monero-project against the binaries
set -euo pipefail

BINARIES=$(cd "$1" && pwd)
shift
TESTS=("$@")
# left out: validate_address and address_book look up openalias addresses and need dnssec,
# mining and rpc_payment need helpers that are not built
[ ${#TESTS[@]} -gt 0 ] || TESTS=(bans blockchain cold_signing daemon_info get_output_distribution integrated_address multisig p2p proofs sign_message transfer txpool uri wallet)

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=$ROOT/external/monero-project/tests/functional_tests
BUILD=$ROOT/build/functional

rm -rf "${BUILD:?}/bin" "${BUILD:?}/tests" "${BUILD:?}/functional-tests-directory"
mkdir -p "$BUILD/bin" "$BUILD/tests/functional_tests" "$BUILD/functional-tests-directory"
install -m 755 "$BINARIES/monerod" "$BINARIES/monero-wallet-rpc" "$BUILD/bin"

[ -d "$BUILD/venv" ] || python3 -m venv "$BUILD/venv"
"$BUILD/venv/bin/pip" install --quiet requests==2.32.3 psutil==6.1.0 monotonic==1.6 pyzmq==26.2.0 deepdiff==8.0.1

"$BUILD/venv/bin/python" "$SRC/functional_tests_rpc.py" "$BUILD/venv/bin/python" "$SRC" "$BUILD" "${TESTS[@]}"
