#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
adb=${ADB:-adb}
package=org.isomorphisms.az.search
component="$package/.SearchActivity"
apk=${1:-}

if [ -z "$apk" ]; then
    apk=$(sh "$project_dir/build-apk.sh")
fi

"$adb" get-state >/dev/null
"$adb" install -r "$apk" >/dev/null
"$adb" shell am force-stop "$package"

start_output=$("$adb" shell am start -W -n "$component" 2>&1) || {
    printf '%s\n' "$start_output"
    exit 1
}
printf '%s\n' "$start_output"

if ! printf '%s\n' "$start_output" | grep -F 'Status: ok' >/dev/null; then
    printf '%s\n' 'FAIL: Activity launch did not report Status: ok' >&2
    exit 1
fi

pid=$("$adb" shell pidof "$package" | tr -d '\r')
if [ -z "$pid" ]; then
    printf '%s\n' 'FAIL: package process is not alive after launch' >&2
    exit 1
fi

printf 'PASS: installed and launched %s pid=%s\n' "$component" "$pid"
