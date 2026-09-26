#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sdk_root=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
if [ -z "$sdk_root" ]; then
    echo "ANDROID_HOME or ANDROID_SDK_ROOT is required" >&2
    exit 2
fi

build_tools_version=${ANDROID_BUILD_TOOLS_VERSION:-36.0.0}
platform_version=${ANDROID_PLATFORM_VERSION:-36}
min_sdk=${ANDROID_MIN_SDK:-26}
build_tools="$sdk_root/build-tools/$build_tools_version"
platform_jar="$sdk_root/platforms/android-$platform_version/android.jar"

for required in \
    javac jar zip \
    "$build_tools/aapt2" \
    "$build_tools/d8" \
    "$build_tools/zipalign" \
    "$platform_jar"
do
    if ! command -v "$required" >/dev/null 2>&1 && [ ! -e "$required" ]; then
        echo "missing Android build dependency: $required" >&2
        exit 2
    fi
done

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/az-search-build.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM
classes_dir="$work_dir/classes"
dex_dir="$work_dir/dex"
compiled_resources="$work_dir/resources"
output_dir="$project_dir/build"
mkdir -p "$classes_dir" "$dex_dir" "$compiled_resources" "$output_dir"

base_apk="$work_dir/base.apk"
unsigned_apk="$work_dir/unsigned.apk"
classes_jar="$work_dir/classes.jar"
final_apk="$output_dir/az-search-unsigned.apk"

"$build_tools/aapt2" compile \
    --dir "$project_dir/src/main/res" \
    -o "$compiled_resources"

"$build_tools/aapt2" link \
    -I "$platform_jar" \
    --manifest "$project_dir/src/main/AndroidManifest.xml" \
    --min-sdk-version "$min_sdk" \
    --target-sdk-version "$platform_version" \
    --version-code 2 \
    --version-name 0.2.0 \
    -o "$base_apk" \
    "$compiled_resources"/*.flat

javac \
    -source 8 \
    -target 8 \
    -classpath "$platform_jar" \
    -d "$classes_dir" \
    "$project_dir/src/main/java/org/isomorphisms/az/search/SearchResults.java" \
    "$project_dir/src/main/java/org/isomorphisms/az/search/SearchActivity.java"

jar cf "$classes_jar" -C "$classes_dir" .
"$build_tools/d8" \
    --lib "$platform_jar" \
    --min-api "$min_sdk" \
    --output "$dex_dir" \
    "$classes_jar"

cp "$base_apk" "$unsigned_apk"
(
    cd "$dex_dir"
    zip -0 -q "$unsigned_apk" classes.dex
)

"$build_tools/zipalign" -f -P 16 4 "$unsigned_apk" "$final_apk"
"$build_tools/zipalign" -c -P 16 4 "$final_apk"
permissions=$("$build_tools/aapt2" dump permissions "$final_apk")
if printf '%s\n' "$permissions" | grep -F 'android.permission.INTERNET' >/dev/null; then
    echo 'built APK unexpectedly requests android.permission.INTERNET' >&2
    exit 1
fi
printf '%s\n' "$final_apk"
