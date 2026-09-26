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
signer_setup="$android/create-test-signer.sh"
sign="$android/sign-apk.sh"
smoke="$android/run-device-smoke.sh"
signing_cert="$android/signing/az-search-cert.pem"
signing_fingerprint="$android/signing/az-search-sha256.txt"

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
grep -F 'com.termux.permission.RUN_COMMAND' "$manifest" >/dev/null
grep -F '<package android:name="com.termux" />' "$manifest" >/dev/null
grep -F 'android:launchMode="singleTop"' "$manifest" >/dev/null

grep -F '"/data/data/com.termux/files/usr/bin/az"' "$activity" >/dev/null
grep -F 'new String[]{"search", query}' "$activity" >/dev/null
grep -F 'new String[]{"price", asin}' "$activity" >/dev/null
grep -F 'MAX_PRICE_JOBS = 3' "$activity" >/dev/null
grep -F 'ACTION_TERMUX_PRICE_RESULT' "$activity" >/dev/null
grep -F 'command.putExtra(TERMUX_BACKGROUND, true)' "$activity" >/dev/null
grep -F 'PendingIntent.FLAG_MUTABLE' "$activity" >/dev/null
grep -F 'intent.getBundleExtra(TERMUX_RESULT_BUNDLE)' "$activity" >/dev/null
grep -F 'requestPermissions(new String[]{TERMUX_PERMISSION}' "$activity" >/dev/null
grep -F '#!/usr/bin/env grease' "$handoff" >/dev/null
grep -F 'grease "$root/bin/az" search "$@"' "$handoff" >/dev/null
grep -F -- '--es org.isomorphisms.az.SEARCH_RESULTS_TSV "$results"' "$handoff" >/dev/null

sh -n "$build"
sh -n "$signer_setup"
sh -n "$sign"
sh -n "$smoke"

grep -F 'aapt2' "$build" >/dev/null
grep -F 'd8' "$build" >/dev/null
grep -F 'zipalign' "$build" >/dev/null
if grep -F 'keytool' "$build" "$sign" >/dev/null; then
  fail 'Android build still generates a disposable signer'
fi
grep -F 'refusing to store the persistent signer inside the repository' "$signer_setup" >/dev/null
grep -F 'refusing to replace existing signer' "$signer_setup" >/dev/null
grep -F 'ANDROID_KEYSTORE must name the persistent AZ Search keystore' "$sign" >/dev/null
grep -F 'canonical AZ Search signer' "$sign" >/dev/null
grep -F 'signing/az-search-sha256.txt' "$sign" >/dev/null
grep -F 'apksigner' "$sign" >/dev/null

test -f "$signing_cert" || fail 'canonical AZ Search public certificate is missing'
test -f "$signing_fingerprint" || fail 'canonical AZ Search fingerprint is missing'
expected_fingerprint=$(tr -d ':[:space:]' < "$signing_fingerprint" | tr '[:upper:]' '[:lower:]')
actual_fingerprint=$(keytool -printcert -file "$signing_cert" |
  sed -n 's/^[[:space:]]*SHA256: //p' |
  head -n 1 |
  tr -d ':[:space:]' |
  tr '[:upper:]' '[:lower:]')
[[ -n "$actual_fingerprint" ]] || fail 'could not read canonical signer certificate fingerprint'
[[ "$actual_fingerprint" == "$expected_fingerprint" ]] ||
  fail 'canonical signer certificate does not match checked-in fingerprint'
grep -F 'install -r' "$smoke" >/dev/null
if grep -F '"$adb" uninstall' "$smoke" >/dev/null; then
  fail 'device smoke must not run an uninstall command to bypass update identity'
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/classes"
javac -source 8 -target 8 -d "$tmp/classes" "$results_java" "$results_test"
java -cp "$tmp/classes" org.isomorphisms.az.search.SearchResultsTest

grep -F 'return "—";' "$results_java" >/dev/null ||
  fail 'missing price should render as an em dash'

printf 'ok - Android search/Termux boundary, bounded price events, parser behavior, and build stages\n'
