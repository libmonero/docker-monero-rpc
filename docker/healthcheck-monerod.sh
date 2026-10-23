#!/bin/sh

# monerod healthcheck: network, rpc port and credentials are read from the
# daemon command line (PID 1) and from its config file, so it follows the
# container configuration whichever way it is given (command line has priority)
set -eu

# shellcheck source=healthcheck-common.sh
. /usr/local/lib/healthcheck-common.sh

has_flag() {
    args | grep -qx -- "--$1" && return 0
    case "$(get_conf "$1")" in 1|true|on|yes) return 0 ;; esac
    return 1
}

# default config file is <data-dir>/bitmonero.conf, in testnet/ on testnet
CONFIG_FILE="$(get_arg config-file)"
if [ -z "${CONFIG_FILE}" ]; then
    DATA_DIR="${HOME}/.bitmonero"
    args | grep -qx -- '--testnet' && DATA_DIR="${DATA_DIR}/testnet"
    CONFIG_FILE="${DATA_DIR}/bitmonero.conf"
fi

RPC_PORT="$(get_option rpc-bind-port)"
if [ -z "${RPC_PORT}" ]; then
    if has_flag stagenet; then RPC_PORT=38081
    elif has_flag testnet; then RPC_PORT=28081
    else RPC_PORT=18081
    fi
fi
RPC_LOGIN="$(get_option rpc-login)"
RPC_URL="http://127.0.0.1:${RPC_PORT}/get_height"

if [ -n "${RPC_LOGIN}" ]; then
    curl --fail --silent --digest --user "${RPC_LOGIN}" "${RPC_URL}"
else
    # a 401 still proves the rpc server is alive
    status="$(curl --silent --output /dev/null --write-out '%{http_code}' "${RPC_URL}")"
    [ "${status}" = "200" ] || [ "${status}" = "401" ]
fi
