#!/bin/sh

# monero-wallet-rpc healthcheck: rpc port and credentials are read from the
# wallet command line (PID 1) and from the config file if there is one, so it
# follows the container configuration whichever way it is given (command line
# has priority)
set -eu

# shellcheck source=healthcheck-common.sh
. /usr/local/lib/healthcheck-common.sh

# there is no default config file
CONFIG_FILE="$(get_arg config-file)"

RPC_PORT="$(get_option rpc-bind-port)"
[ -n "${RPC_PORT}" ] || { echo "rpc-bind-port not set"; exit 1; }
RPC_LOGIN="$(get_option rpc-login)"
RPC_URL="http://127.0.0.1:${RPC_PORT}/json_rpc"
RPC_BODY='{"jsonrpc":"2.0","id":"0","method":"get_version"}'

if [ -n "${RPC_LOGIN}" ]; then
    curl --fail --silent --digest --user "${RPC_LOGIN}" --header 'Content-Type: application/json' --data "${RPC_BODY}" "${RPC_URL}"
else
    # a 401 still proves the rpc server is alive
    status="$(curl --silent --output /dev/null --write-out '%{http_code}' --header 'Content-Type: application/json' --data "${RPC_BODY}" "${RPC_URL}")"
    [ "${status}" = "200" ] || [ "${status}" = "401" ]
fi
