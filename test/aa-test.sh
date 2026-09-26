#!/bin/bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
AA_BIN="$ROOT/bin/aa"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

expect_eq() {
  local expected=$1
  local actual=$2
  local label=$3
  [[ "$actual" == "$expected" ]] || fail "$label: expected [$expected], got [$actual]"
}

export AA='test key+value'
export AA_BASE_URL='https://annas-archive.gl'
export AA_FAKE_CALLS="$TMP/icu-calls"

cat > "$TMP/bin/icu" <<'ICU'
#!/bin/sh
printf '%s\n' "$*" >> "$AA_FAKE_CALLS"
printf '%s\n' '{"download_url":"https://download.example/member/file.pdf"}'
ICU
chmod +x "$TMP/bin/icu"

# If aa silently falls back to curl, fail the fixture immediately.
cat > "$TMP/bin/curl" <<'CURL'
#!/bin/sh
printf 'curl fallback was invoked\n' >&2
exit 99
CURL
chmod +x "$TMP/bin/curl"

export PATH="$TMP/bin:$PATH"

md5='6722FAECDB9370AD0D2E447CCE370950'
result=$(bash "$AA_BIN" resolve "$md5")
expect_eq 'https://download.example/member/file.pdf' "$result" 'resolved URL'

grep -F 'get https://annas-archive.gl/dyn/api/fast_download.json?md5=6722faecdb9370ad0d2e447cce370950&key=test%20key%2Bvalue' \
  "$AA_FAKE_CALLS" >/dev/null || fail 'ICU did not receive the expected encoded request'

if AA= bash "$AA_BIN" resolve "$md5" >"$TMP/out" 2>"$TMP/err"; then
  fail 'missing secret unexpectedly succeeded'
fi
grep -F 'membership secret is not configured in AA' "$TMP/err" >/dev/null ||
  fail 'missing-secret diagnostic changed'

if bash "$AA_BIN" resolve not-an-md5 >"$TMP/out" 2>"$TMP/err"; then
  fail 'invalid MD5 unexpectedly succeeded'
fi
grep -F 'expected a 32-character hexadecimal MD5' "$TMP/err" >/dev/null ||
  fail 'invalid-MD5 diagnostic changed'

if AA_BASE_URL='https://example.com' bash "$AA_BIN" resolve "$md5" >"$TMP/out" 2>"$TMP/err"; then
  fail 'unapproved secret destination unexpectedly succeeded'
fi
grep -F 'refusing to send the membership secret to unapproved host' "$TMP/err" >/dev/null ||
  fail 'unapproved-host diagnostic changed'

doctor=$(bash "$AA_BIN" doctor)
grep -F $'ok\ticu' <<<"$doctor" >/dev/null || fail 'doctor did not find ICU'
grep -F $'aa_secret\tconfigured' <<<"$doctor" >/dev/null || fail 'doctor did not report secret'

printf 'ok\n'
