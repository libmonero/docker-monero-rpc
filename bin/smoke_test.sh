#!/usr/bin/env bash

# usage: smoke_test.sh <monero-daemon-rpc|monero-wallet-rpc> <image> [default|private-testnet]
set -euo pipefail

NAME=$1
IMAGE=$2
VARIANT=${3:-default}
VERSION=$("$(dirname "$0")/monero_version.sh")
CONTAINER=smoke-test-$$
HARDENED=(--read-only --cap-drop ALL --security-opt no-new-privileges)
OPTS=()
CONFIG=$(mktemp)
# docker cp keeps the owner, the container user has to be able to read it
chmod 644 "$CONFIG"

cleanup() {
    docker rm -fv "$CONTAINER" > /dev/null 2>&1 || true
    rm -f "$CONFIG"
}
trap cleanup EXIT

fail() {
    echo "$*" >&2
    ! docker inspect "$CONTAINER" > /dev/null 2>&1 || docker logs "$CONTAINER" >&2 2>&1
    exit 1
}

# start <config path in container, or empty> <args...>
start() {
    local config_path=$1
    shift
    docker create --name "$CONTAINER" --health-interval=5s --health-start-period=5s ${OPTS[@]+"${OPTS[@]}"} "$IMAGE" "$@" > /dev/null
    [ -z "$config_path" ] || docker cp "$CONFIG" "$CONTAINER:$config_path"
    docker start "$CONTAINER" > /dev/null
}

# earliest height of a hard fork version, as reported by the daemon
hard_fork_height() {
    docker exec "$CONTAINER" curl --fail --silent http://127.0.0.1:28081/json_rpc \
        --header 'Content-Type: application/json' \
        --data "{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"hard_fork_info\",\"params\":{\"version\":$1}}" |
        tr -d ' \n' | sed 's/.*"earliest_height":\([0-9]*\).*/\1/'
}

wait_healthy() {
    local status
    for _ in $(seq 1 24); do
        status=$(docker inspect -f '{{.State.Status}} {{.State.Health.Status}}' "$CONTAINER")
        [ "$status" != "running healthy" ] || return 0
        [ "${status%% *}" = running ] || fail "container is $status"
        sleep 5
    done
    fail "container did not become healthy: $status"
}

stop() {
    docker stop -t 30 "$CONTAINER" > /dev/null
    [ "$(docker inspect -f '{{.State.ExitCode}}' "$CONTAINER")" = 0 ] || fail "unclean exit"
    docker rm -fv "$CONTAINER" > /dev/null
}

output=$(docker run --rm "$IMAGE" --version)
echo "$output"
echo "$output" | grep -qF "($VERSION)" || fail "expected version $VERSION"
[ "$(docker run --rm --entrypoint id "$IMAGE" -u)" != 0 ] || fail "image runs as root"
[ "$(docker inspect -f '{{index .Config.Labels "io.libmonero.variant"}}' "$IMAGE")" = "$VARIANT" ] || fail "image is not the $VARIANT variant"

# testnet heights of hard fork versions 2 and 16
case $VARIANT in
    default) HARD_FORKS=(624634 1983520) ;;
    private-testnet) HARD_FORKS=(10 150) ;;
    *) fail "unknown variant $VARIANT" ;;
esac

case $NAME in
    monero-daemon-rpc)
        start "" --stagenet --offline --rpc-bind-ip=0.0.0.0 --confirm-external-bind --rpc-bind-port=40001 --rpc-login=user:pass
        wait_healthy
        stop

        printf 'stagenet=1\noffline=1\nrpc-bind-ip=0.0.0.0\nconfirm-external-bind=1\nrpc-bind-port=40002\nrpc-login=user:pass\n' > "$CONFIG"
        start /home/monero/.bitmonero/bitmonero.conf
        wait_healthy
        stop

        OPTS=("${HARDENED[@]}")
        start /home/monero/.bitmonero/bitmonero.conf
        wait_healthy
        stop

        OPTS=()
        start "" --testnet --offline --rpc-bind-ip=0.0.0.0 --confirm-external-bind
        wait_healthy
        [ "$(hard_fork_height 2)" = "${HARD_FORKS[0]}" ] || fail "unexpected hard fork 2 height for $VARIANT"
        [ "$(hard_fork_height 16)" = "${HARD_FORKS[1]}" ] || fail "unexpected hard fork 16 height for $VARIANT"
        stop
        ;;
    monero-wallet-rpc)
        start "" --stagenet --rpc-bind-ip=0.0.0.0 --confirm-external-bind --rpc-bind-port=40001 --rpc-login=user:pass --wallet-dir=/home/monero/wallets --log-file=/dev/null
        wait_healthy
        docker exec "$CONTAINER" curl --fail --silent --digest --user user:pass http://127.0.0.1:40001/json_rpc \
            --header 'Content-Type: application/json' \
            --data '{"jsonrpc":"2.0","id":"0","method":"create_wallet","params":{"filename":"smoke","password":"pass","language":"English"}}' | grep -q '"result"' || fail "create_wallet failed"
        docker exec "$CONTAINER" test -f /home/monero/wallets/smoke.keys || fail "wallet was not created"
        stop

        printf 'stagenet=1\nrpc-bind-ip=0.0.0.0\nconfirm-external-bind=1\nrpc-bind-port=40002\nrpc-login=user:pass\nwallet-dir=/home/monero/wallets\nlog-file=/dev/null\n' > "$CONFIG"
        start /home/monero/wallets/wallet.conf --config-file=/home/monero/wallets/wallet.conf
        wait_healthy
        stop

        OPTS=("${HARDENED[@]}")
        start /home/monero/wallets/wallet.conf --config-file=/home/monero/wallets/wallet.conf
        wait_healthy
        stop
        ;;
    *)
        fail "unknown image $NAME"
        ;;
esac

echo "$NAME ok"
