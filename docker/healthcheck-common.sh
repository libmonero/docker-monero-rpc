#!/bin/sh

# sourced by the healthcheck scripts, which read their settings from the
# command line of PID 1 and from the config file ($CONFIG_FILE)

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

# command line has priority over the config file
get_option() {
    value="$(get_arg "$1")"
    [ -n "${value}" ] || value="$(get_conf "$1")"
    printf '%s' "${value}"
}
