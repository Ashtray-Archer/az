#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
keystore=${1:-}

if [ -z "$keystore" ]; then
    echo "usage: ANDROID_KEYSTORE_PASSWORD=... sh android-search/create-test-signer.sh /outside/repo/az-search-test.keystore" >&2
    exit 2
fi

: "${ANDROID_KEYSTORE_PASSWORD:?ANDROID_KEYSTORE_PASSWORD is required}"
ANDROID_KEY_ALIAS=${ANDROID_KEY_ALIAS:-az-search-test}
ANDROID_KEY_PASSWORD=${ANDROID_KEY_PASSWORD:-$ANDROID_KEYSTORE_PASSWORD}

command -v keytool >/dev/null 2>&1 || {
    echo "missing keytool" >&2
    exit 2
}

keystore_dir=$(dirname -- "$keystore")
mkdir -p "$keystore_dir"
keystore_dir=$(CDPATH= cd -- "$keystore_dir" && pwd)
keystore="$keystore_dir/$(basename -- "$keystore")"

case "$keystore" in
    "$project_dir"/*)
        echo "refusing to store the persistent signer inside the repository" >&2
        exit 2
        ;;
esac

if [ -e "$keystore" ]; then
    echo "refusing to replace existing signer: $keystore" >&2
    exit 2
fi

umask 077
keytool -genkeypair -noprompt     -keystore "$keystore"     -storepass "$ANDROID_KEYSTORE_PASSWORD"     -keypass "$ANDROID_KEY_PASSWORD"     -alias "$ANDROID_KEY_ALIAS"     -dname "CN=AZ Search Test,O=AZ,C=US"     -keyalg RSA     -keysize 2048     -validity 10000

echo "created persistent AZ Search test signer: $keystore"
echo "record this public certificate fingerprint in the acceptance record:"
keytool -list -v     -keystore "$keystore"     -storepass "$ANDROID_KEYSTORE_PASSWORD"     -alias "$ANDROID_KEY_ALIAS" |
    sed -n 's/^[[:space:]]*SHA256: /SHA-256: /p'
