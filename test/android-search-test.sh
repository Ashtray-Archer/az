#!/usr/bin/env bash
set -euo pipefail

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
android="$root/android-search"
activity="$android/src/main/java/org/isomorphisms/az/search/SearchActivity.java"
manifest="$android/src/main/AndroidManifest.xml"
handoff="$android/show-results.ysh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

if grep -F 'android.permission.INTERNET' "$manifest" >/dev/null; then
  fail 'Android search APK must not request INTERNET'
fi

if grep -R -E 'AZ_AMAZON_CREDENTIAL_(ID|SECRET)' "$android/src" >/dev/null; then
  fail 'Creator credential names leaked into APK source tree'
fi

if test -e "$android/src/main/assets/sample-search.tsv"; then
  fail 'runtime fixture search results are still packaged'
fi

if grep -F 'loadFixture' "$activity" >/dev/null; then
  fail 'Activity still has a fixture-loading path'
fi

grep -F 'org.isomorphisms.az.SEARCH_RESULTS_TSV' "$activity" >/dev/null
grep -F 'org.isomorphisms.az.SEARCH_QUERY' "$activity" >/dev/null
grep -F '"$az_command" search "$@"' "$handoff" >/dev/null
grep -F -- '--es org.isomorphisms.az.SEARCH_RESULTS_TSV "$results"' "$handoff" >/dev/null

sh -n "$android/build-apk.sh"
sh -n "$android/run-device-smoke.sh"

grep -F 'aapt2' "$android/build-apk.sh" >/dev/null
grep -F 'd8' "$android/build-apk.sh" >/dev/null
grep -F 'zipalign' "$android/build-apk.sh" >/dev/null
grep -F 'apksigner' "$android/build-apk.sh" >/dev/null
grep -F 'am start -W' "$android/run-device-smoke.sh" >/dev/null

printf 'ok - Android search boundary and direct-build source checks\n'
