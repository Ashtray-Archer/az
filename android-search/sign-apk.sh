#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sdk_root=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
if [ -z "$sdk_root" ]; then
    echo "ANDROID_HOME or ANDROID_SDK_ROOT is required" >&2
    exit 2
fi

build_tools_version=${ANDROID_BUILD_TOOLS_VERSION:-36.0.0}
apksigner="$sdk_root/build-tools/$build_tools_version/apksigner"
if [ ! -x "$apksigner" ]; then
    echo "missing Android build dependency: $apksigner" >&2
    exit 2
fi

canonical_fingerprint_file="$project_dir/signing/az-search-sha256.txt"
if [ ! -f "$canonical_fingerprint_file" ]; then
    echo "missing canonical AZ Search signer fingerprint: $canonical_fingerprint_file" >&2
    exit 2
fi
canonical_fingerprint=$(tr -d ':[:space:]' < "$canonical_fingerprint_file" | tr '[:upper:]' '[:lower:]')
if [ -z "$canonical_fingerprint" ]; then
    echo "canonical AZ Search signer fingerprint is empty" >&2
    exit 2
fi

: "${ANDROID_KEYSTORE:?ANDROID_KEYSTORE must name the persistent AZ Search keystore}"
ANDROID_KEY_ALIAS=${ANDROID_KEY_ALIAS:-az-search}
: "${ANDROID_KEYSTORE_PASSWORD:?ANDROID_KEYSTORE_PASSWORD is required}"
ANDROID_KEY_PASSWORD=${ANDROID_KEY_PASSWORD:-$ANDROID_KEYSTORE_PASSWORD}
export ANDROID_KEY_PASSWORD

if [ ! -f "$ANDROID_KEYSTORE" ]; then
    echo "missing persistent Android signing keystore: $ANDROID_KEYSTORE" >&2
    exit 2
fi

input_apk=${1:-"$project_dir/build/az-search-unsigned.apk"}
if [ ! -f "$input_apk" ]; then
    input_apk=$(sh "$project_dir/build-apk.sh")
fi
output_apk="$project_dir/build/az-search.apk"

"$apksigner" sign \
    --ks "$ANDROID_KEYSTORE" \
    --ks-key-alias "$ANDROID_KEY_ALIAS" \
    --ks-pass env:ANDROID_KEYSTORE_PASSWORD \
    --key-pass env:ANDROID_KEY_PASSWORD \
    --out "$output_apk" \
    "$input_apk"

certificate_report=$("$apksigner" verify --verbose --print-certs "$output_apk")
printf '%s\n' "$certificate_report"

actual_fingerprint=$(printf '%s\n' "$certificate_report" |
    sed -n 's/^Signer #1 certificate SHA-256 digest: //p' |
    head -n 1 |
    tr -d ':[:space:]' |
    tr '[:upper:]' '[:lower:]')

if [ -z "$actual_fingerprint" ]; then
    rm -f "$output_apk"
    echo "could not read signer SHA-256 digest from apksigner output" >&2
    exit 1
fi

if [ "$actual_fingerprint" != "$canonical_fingerprint" ]; then
    rm -f "$output_apk"
    echo "signed APK does not match the canonical AZ Search signer" >&2
    echo "expected: $(cat "$canonical_fingerprint_file")" >&2
    exit 1
fi

printf '%s\n' "$output_apk"
