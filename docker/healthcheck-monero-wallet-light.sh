#!/bin/sh

# monero-lws-daemon healthcheck: the rest server is read from the command line
# of PID 1 and from the config file if there is one (command line has priority)
set -eu

# shellcheck source=healthcheck-common.sh
. /usr/local/lib/healthcheck-common.sh

CONFIG_FILE="$(get_arg config-file)"

# [(https|http)://<address>:]<port>[/<prefix>], the default is https://0.0.0.0:8443
REST="$(get_option rest-server)"
[ -n "${REST}" ] || REST="https://0.0.0.0:8443"
case "${REST}" in
    *://*) scheme="${REST%%://*}" ;;
    *) scheme="https" ;;
esac
rest="${REST#*://}"
hostport="${rest%%/*}"
prefix="${rest#"${hostport}"}"
port="${hostport##*:}"

# the certificate of an https server is not worth checking from the inside
curl --fail --silent --insecure --header 'Content-Type: application/json' --data '{}' "${scheme}://127.0.0.1:${port}${prefix%/}/get_version"
