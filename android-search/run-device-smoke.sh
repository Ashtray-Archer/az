#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
adb=${ADB:-adb}
package=org.isomorphisms.az.search
component="$package/.SearchActivity"
apk=${1:-}

if [ -t 1 ] && [ "${TERM:-dumb}" != dumb ]; then
    cyan='\033[36m'
    yellow='\033[33m'
    green='\033[32m'
    red='\033[31m'
    reset='\033[0m'
else
    cyan=
    yellow=
    green=
    red=
    reset=
fi

if [ -z "$apk" ]; then
    printf '%bACTION%b build and sign with the persistent AZ Search signer\n' "$yellow" "$reset"
    sh "$project_dir/build-apk.sh" >/dev/null
    apk=$(sh "$project_dir/sign-apk.sh")
fi

printf '%bCHECK%b replacement install and launch\n' "$cyan" "$reset"
"$adb" get-state >/dev/null
if ! "$adb" install -r "$apk" >/dev/null; then
    printf '%bFAIL%b replacement install failed; do not uninstall to hide signer/version problems\n' "$red" "$reset" >&2
    exit 1
fi
"$adb" shell am force-stop "$package"

start_output=$("$adb" shell am start -W -n "$component" 2>&1) || {
    printf '%s\n' "$start_output"
    printf '%bFAIL%b Activity launch command failed\n' "$red" "$reset" >&2
    exit 1
}
printf '%s\n' "$start_output"

if ! printf '%s\n' "$start_output" | grep -F 'Status: ok' >/dev/null; then
    printf '%bFAIL%b Activity launch did not report Status: ok\n' "$red" "$reset" >&2
    exit 1
fi

pid=$("$adb" shell pidof "$package" | tr -d '\r')
if [ -z "$pid" ]; then
    printf '%bFAIL%b package process is not alive after launch\n' "$red" "$reset" >&2
    exit 1
fi

printf '%bPASS%b installed and launched %s pid=%s\n' "$green" "$reset" "$component" "$pid"
