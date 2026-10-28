#!/usr/bin/env bash

# usage: wait_for_run.sh <workflow file> <sha> <event>
# waits for the run of a workflow on a commit, prints its id and fails if it does not succeed
# needs GH_TOKEN and GH_REPO
set -euo pipefail

WORKFLOW=$1
SHA=$2
EVENT=$3

# the run can start together with the caller, give it time to show up
for _ in $(seq 1 30); do
    id=$(gh run list --workflow "$WORKFLOW" --commit "$SHA" --event "$EVENT" --limit 1 --json databaseId --jq '.[0].databaseId // empty')
    [ -z "$id" ] || break
    sleep 10
done
[ -n "$id" ] || { echo "no $WORKFLOW run for $SHA" >&2; exit 1; }

until [ "$(gh run view "$id" --json status --jq .status)" = completed ]; do sleep 15; done
[ "$(gh run view "$id" --json conclusion --jq .conclusion)" = success ] || { echo "$WORKFLOW run $id did not succeed" >&2; exit 1; }
echo "$id"
