#!/usr/bin/env bash

# usage: verify_binaries.sh <directory> <architecture in the output of file, x86-64 or aarch64>
# checks that the binaries are static, for the architecture, without readline and with a stack for the threads
set -euo pipefail

cd "$1"
for bin in monerod monero-wallet-rpc monero-lws-daemon monero-lws-admin; do
    file "$bin"
    file "$bin" | grep -q "$2" || { echo "wrong architecture: $(file "$bin")"; exit 1; }
    file "$bin" | grep -qE 'statically linked|static-pie linked' || { echo "$bin is not statically linked"; exit 1; }
    ! strings "$bin" | grep -qE 'INPUTRC|inputrc' || { echo "$bin contains readline"; exit 1; }
    memsz=$(readelf -lW "$bin" | awk '/GNU_STACK/ {print $6}')
    [ $((memsz)) -ge 8388608 ] || { echo "$bin has a thread stack of $memsz bytes"; exit 1; }
done
