#!/usr/bin/env bash

# usage: lws_test.sh <monero-daemon-rpc image> <monero-wallet-rpc image> <monero-wallet-light image> [default|private-testnet]
# monero-wallet-light follows a chain of the daemon until its top: a regtest chain for the
# default variant, a testnet chain past all the hardforks of the private testnet for the other.
# The zmq pub of the daemon and the one of monero-wallet-light publish what is expected.
set -euo pipefail

DAEMON_IMAGE=$1
WALLET_IMAGE=$2
LIGHT_IMAGE=$3
VARIANT=${4:-default}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
VENV=$ROOT/build/lws-test/venv
OUTPUT=$(mktemp -d)
NETWORK=lws-test-$$
NODE=$NETWORK-node
WALLET=$NETWORK-wallet
LIGHT=$NETWORK-light

case $VARIANT in
    default)
        NODE_ARGS=(--regtest)
        WALLET_ARGS=()
        LIGHT_ARGS=(--regtest)
        BLOCKS=20 ;;
    private-testnet)
        # the last hardfork is at height 150
        NODE_ARGS=(--testnet --fixed-difficulty=1)
        WALLET_ARGS=(--testnet)
        LIGHT_ARGS=(--testnet)
        BLOCKS=160 ;;
    *) echo "unknown variant $VARIANT" >&2; exit 1 ;;
esac

cleanup() {
    jobs -p | xargs -r kill 2> /dev/null || true
    docker rm -fv "$NODE" "$WALLET" "$LIGHT" > /dev/null 2>&1 || true
    docker network rm "$NETWORK" > /dev/null 2>&1 || true
    rm -rf "$OUTPUT"
}
trap cleanup EXIT

fail() {
    echo "$*" >&2
    for container in "$NODE" "$WALLET" "$LIGHT"; do
        echo "--- $container" >&2
        docker logs --tail 30 "$container" >&2 2>&1 || true
    done
    exit 1
}

# start <name> <image> <args...>, PORTS are published to localhost on a free port
start() {
    local name=$1 image=$2 ports=()
    shift 2
    for port in ${PORTS[@]+"${PORTS[@]}"}; do ports+=(--publish "127.0.0.1::$port"); done
    docker run -d --name "$name" --network "$NETWORK" --health-interval=5s --health-start-period=5s ${ports[@]+"${ports[@]}"} "$image" "$@" > /dev/null
}

wait_healthy() {
    for _ in $(seq 1 24); do
        [ "$(docker inspect -f '{{.State.Health.Status}}' "$1")" != healthy ] || return 0
        sleep 5
    done
    fail "$1 did not become healthy"
}

# post <container> <port> <path> <body>
post() {
    docker exec "$1" curl --fail --silent --max-time 120 --header 'Content-Type: application/json' --data "$4" "http://127.0.0.1:$2$3"
}

node_height() {
    docker exec "$NODE" curl --fail --silent http://127.0.0.1:18081/get_height | grep -o '"height": *[0-9]*' | grep -o '[0-9]*$'
}

# pyzmq listens to the pub sockets from outside the containers
[ -d "$VENV" ] || python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet pyzmq==26.2.0

docker network create "$NETWORK" > /dev/null

PORTS=(18083)
start "$NODE" "$DAEMON_IMAGE" "${NODE_ARGS[@]}" --offline --no-igd --rpc-bind-ip=0.0.0.0 --rpc-bind-port=18081 --confirm-external-bind \
    --zmq-rpc-bind-ip=0.0.0.0 --zmq-rpc-bind-port=18082 --confirm-zmq-rpc-external-bind --zmq-pub=tcp://0.0.0.0:18083
PORTS=()
start "$WALLET" "$WALLET_IMAGE" "${WALLET_ARGS[@]}" --offline --rpc-bind-ip=0.0.0.0 --rpc-bind-port=18084 --confirm-external-bind \
    --disable-rpc-login --wallet-dir=/home/monero/wallets --log-file=/dev/null
PORTS=(18090)
start "$LIGHT" "$LIGHT_IMAGE" "${LIGHT_ARGS[@]}" --daemon="tcp://$NODE:18082" --sub="tcp://$NODE:18083" --zmq-pub=tcp://0.0.0.0:18090 \
    --rest-server=http://0.0.0.0:8443 --admin-rest-server=http://0.0.0.0:8444 --disable-admin-auth \
    --confirm-external-bind --auto-accept-creation --log-level=1
PORTS=()
for container in "$NODE" "$WALLET" "$LIGHT"; do wait_healthy "$container"; done

# the account of the light wallet server has the keys of a wallet
post "$WALLET" 18084 /json_rpc '{"jsonrpc":"2.0","id":"0","method":"create_wallet","params":{"filename":"lws","password":"","language":"English"}}' > /dev/null || fail "create_wallet failed"
address=$(post "$WALLET" 18084 /json_rpc '{"jsonrpc":"2.0","id":"0","method":"get_address"}' | grep -o '"address": *"[^"]*"' | head -1 | cut -d'"' -f4)
view_key=$(post "$WALLET" 18084 /json_rpc '{"jsonrpc":"2.0","id":"0","method":"query_key","params":{"key_type":"view_key"}}' | grep -o '"key": *"[^"]*"' | cut -d'"' -f4)
if [ -z "$address" ] || [ -z "$view_key" ]; then fail "no keys from the wallet"; fi
creds="\"address\":\"$address\",\"view_key\":\"$view_key\""
post "$LIGHT" 8443 /login "{$creds,\"create_account\":true,\"generated_locally\":true}" > /dev/null || fail "login failed"

# payments of the account are published on the zmq pub of monero-wallet-light
post "$LIGHT" 8444 /webhook_add "{\"params\":{\"type\":\"tx-confirmation\",\"url\":\"zmq\",\"address\":\"$address\",\"token\":\"lws-test\",\"confirmations\":1}}" > /dev/null || fail "webhook_add failed"

# both listen before the blocks are made, a pub socket does not keep messages for later
endpoint() { echo "tcp://$(docker port "$1" "$2/tcp" | head -1)"; }
"$VENV/bin/python" "$ROOT/bin/zmq_wait.py" "$(endpoint "$NODE" 18083)" json-minimal-chain_main 120 > "$OUTPUT/node" 2>&1 &
node_listener=$!
"$VENV/bin/python" "$ROOT/bin/zmq_wait.py" "$(endpoint "$LIGHT" 18090)" json-full-payment_hook 120 > "$OUTPUT/light" 2>&1 &
light_listener=$!
sleep 2

# blocks come after the account, so the light wallet server also gets them from the zmq pub
if [ "$VARIANT" = default ]; then
    post "$NODE" 18081 /json_rpc "{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"generateblocks\",\"params\":{\"wallet_address\":\"$address\",\"amount_of_blocks\":$BLOCKS}}" > /dev/null || fail "generateblocks failed"
else
    post "$NODE" 18081 /start_mining "{\"miner_address\":\"$address\",\"threads_count\":1,\"do_background_mining\":false,\"ignore_battery\":true}" > /dev/null || fail "start_mining failed"
    for _ in $(seq 1 60); do
        [ "$(node_height)" -lt "$BLOCKS" ] || break
        sleep 2
    done
    post "$NODE" 18081 /stop_mining '' > /dev/null || fail "stop_mining failed"
fi
height=$(node_height)
[ "$height" -ge "$BLOCKS" ] || fail "the node is at height $height, not $BLOCKS"

scanned=0
for _ in $(seq 1 60); do
    scanned=$(post "$LIGHT" 8443 /get_address_info "{$creds}" | grep -o '"scanned_block_height": *[0-9]*' | grep -o '[0-9]*$' || echo 0)
    [ "${scanned:-0}" -lt $((height - 1)) ] || break
    sleep 2
done
[ "${scanned:-0}" -ge $((height - 1)) ] || fail "monero-wallet-light scanned up to $scanned, the node is at $height"

wait "$node_listener" || fail "the node published no block: $(cat "$OUTPUT/node")"
wait "$light_listener" || fail "monero-wallet-light published no payment: $(cat "$OUTPUT/light")"
grep -q 'tx-confirmation' "$OUTPUT/light" || fail "unexpected payment event: $(cut -c1-300 "$OUTPUT/light")"

echo "monero-wallet-light followed the $VARIANT chain to height $scanned and published its payments"
