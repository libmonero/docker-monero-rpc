#!/bin/sh

# monero-wallet-rpc healthcheck: rpc port and credentials are read from the
# wallet command line (PID 1) and from the config file if there is one, so it
# follows the container configuration whichever way it is given (command line
# has priority)
set -eu

# print the value of a command line flag, as "--flag=value" or "--flag value"
get_arg() {
    tr '\0' '\n' < /proc/1/cmdline | awk -v flag="--$1" '
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

get_option() {
    value="$(get_arg "$1")"
    [ -n "${value}" ] || value="$(get_conf "$1")"
    printf '%s' "${value}"
}

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
