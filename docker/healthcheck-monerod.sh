#!/bin/sh

# monerod healthcheck: network, rpc port and credentials are read from the
# daemon command line (PID 1) and from its config file, so it follows the
# container configuration whichever way it is given (command line has priority)
set -eu

args() {
    tr '\0' '\n' < /proc/1/cmdline
}

# print the value of a command line flag, as "--flag=value" or "--flag value"
get_arg() {
    args | awk -v flag="--$1" '
        prev == flag { print; exit }
        index($0, flag "=") == 1 { print substr($0, length(flag) + 2); exit }
        { prev = $0 }
    '
}

# print the value of a config file option, as "option=value"
get_conf() {
    [ -f "${CONFIG_FILE}" ] || return 0
    awk -v key="$1" '
        /^[ \t]*#/ { next }
        {
            eq = index($0, "=")
            if (eq == 0) next
            name = substr($0, 1, eq - 1)
            gsub(/[ \t]/, "", name)
            if (name != key) next
            value = substr($0, eq + 1)
            sub(/^[ \t]+/, "", value)
            sub(/[ \t\r]+$/, "", value)
            print value
            exit
        }
    ' "${CONFIG_FILE}"
}

has_flag() {
    args | grep -qx -- "--$1" && return 0
    case "$(get_conf "$1")" in 1|true|on|yes) return 0 ;; esac
    return 1
}

get_option() {
    value="$(get_arg "$1")"
    [ -n "${value}" ] || value="$(get_conf "$1")"
    printf '%s' "${value}"
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
