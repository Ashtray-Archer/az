#!/usr/bin/env bash
set -euo pipefail

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
android="$root/android-search"
activity="$android/src/main/java/org/isomorphisms/az/search/SearchActivity.java"
results_java="$android/src/main/java/org/isomorphisms/az/search/SearchResults.java"
results_test="$android/test/SearchResultsTest.java"
manifest="$android/src/main/AndroidManifest.xml"
handoff="$android/show-results"
build="$android/build-apk.sh"
sign="$android/sign-apk.sh"
smoke="$android/run-device-smoke.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

if grep -F 'android.permission.INTERNET' "$manifest" >/dev/null; then
  fail 'Android search APK must not request INTERNET'
fi

if grep -R -E 'AZ_AMAZON_CREDENTIAL_(ID|SECRET)' "$android/src" >/dev/null; then
  fail 'Amazon credential names leaked into APK source tree'
fi

if test -e "$android/src/main/assets/sample-search.tsv"; then
  fail 'runtime fixture search results are still packaged'
fi

if grep -F 'loadFixture' "$activity" >/dev/null; then
  fail 'Activity still has a fixture-loading path'
fi

if grep -F 'filter.setText(suppliedQuery)' "$activity" >/dev/null; then
  fail 'source search query is still being reused as the local filter'
fi

grep -F 'org.isomorphisms.az.SEARCH_RESULTS_TSV' "$activity" >/dev/null
grep -F 'org.isomorphisms.az.SEARCH_QUERY' "$activity" >/dev/null
grep -F 'android:launchMode="singleTop"' "$manifest" >/dev/null
grep -F '#!/usr/bin/env grease' "$handoff" >/dev/null
grep -F 'grease "$root/bin/az" search "$@"' "$handoff" >/dev/null
grep -F -- '--es org.isomorphisms.az.SEARCH_RESULTS_TSV "$results"' "$handoff" >/dev/null

sh -n "$build"
sh -n "$sign"
sh -n "$smoke"

grep -F 'aapt2' "$build" >/dev/null
grep -F 'd8' "$build" >/dev/null
grep -F 'zipalign' "$build" >/dev/null
if grep -F 'keytool' "$build" "$sign" >/dev/null; then
  fail 'Android build still generates a disposable signer'
fi
grep -F 'ANDROID_KEYSTORE must name the persistent AZ Search test keystore' "$sign" >/dev/null
grep -F 'apksigner' "$sign" >/dev/null
grep -F 'install -r' "$smoke" >/dev/null
if grep -F 'uninstall' "$smoke" >/dev/null; then
  fail 'device smoke must not uninstall to bypass update identity'
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/classes"
javac -source 8 -target 8 -d "$tmp/classes" "$results_java" "$results_test"
java -cp "$tmp/classes" org.isomorphisms.az.search.SearchResultsTest

printf 'ok - Android search boundary, parser behavior, and build stages\n'
