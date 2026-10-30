#!/bin/sh

# usage: retry.sh <command>...
# runs a command again when it fails, the package mirrors and the downloads fail now and then on the runners
set -u

attempts=4
attempt=1
while :; do
    if "$@"; then
        exit 0
    else
        status=$?
    fi
    [ "$attempt" -lt "$attempts" ] || exit "$status"
    echo "retry: '$*' failed with $status (attempt $attempt of $attempts), again in $((attempt * 15))s" >&2
    sleep $((attempt * 15))
    attempt=$((attempt + 1))
done
