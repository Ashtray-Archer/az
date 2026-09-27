#!/bin/bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
ABE="$ROOT/bin/abe"
AZ_SHELL=${AZ_SHELL:-bash}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
export XDG_CONFIG_HOME="$TMP/config"
export XDG_STATE_HOME="$TMP/state"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$TMP/bin"

# Exercise the checked-in public Impact ID, not a test override.
unset AZ_IMPACT_ID || true
export AZ_ABEBOOKS_CLIENT_KEY=test-client-key
export AZ_ABEBOOKS_SEARCH_URL=https://mock/search
export AZ_FAKE_CALLS="$TMP/curl-calls"

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

# Known Bill Hammack book from the price-search workflow.  This must generate a
# link owned by Impact account 349003 and preserve the exact AbeBooks target.
bill_target='https://www.abebooks.com/9780983966135/Eight-Amazing-Engineering-Stories-Using-0983966133/plp'
bill_link='https://affiliates.abebooks.com/c/349003/77798/2029?u=https%3A%2F%2Fwww.abebooks.com%2F9780983966135%2FEight-Amazing-Engineering-Stories-Using-0983966133%2Fplp'
expect_eq "$bill_link" "$("$AZ_SHELL" "$ABE" link "$bill_target")" 'Bill Hammack Impact link'

# Link generation is useful by itself and needs no Impact API call.
expect_eq \
  'https://affiliates.abebooks.com/c/349003/77798/2029?u=https%3A%2F%2Fwww.abebooks.com%2Fservlet%2FBookDetailsPL%3Fbi%3D42%26x%3Dy' \
  "$("$AZ_SHELL" "$ABE" link 'https://www.abebooks.com/servlet/BookDetailsPL?bi=42&x=y')" \
  'Impact link'

cat > "$TMP/bin/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$AZ_FAKE_CALLS"
cat <<'XML'
<?xml version="1.0" encoding="ISO-8859-1"?>
<SearchResults>
  <Book>
    <bookId>22908240098</bookId>
    <isbn10>0131457578</isbn10>
    <isbn13>9780131457577</isbn13>
    <listingCondition>NOT NEW BOOK</listingCondition>
    <itemCondition>Fair</itemCondition>
    <quantity>1</quantity>
    <vendorCurrency>USD</vendorCurrency>
    <listingPrice>1.00</listingPrice>
    <firstBookShipCost>12.11</firstBookShipCost>
    <totalListingPrice>13.11</totalListingPrice>
    <listingUrl>www.abebooks.com/servlet/BookDetailsPL?bi=22908240098&amp;cm_ven=sws&amp;cm_cat=sws</listingUrl>
    <author>Kotler, P</author>
    <title>Marketing Management</title>
  </Book>
</SearchResults>
XML
EOF
chmod +x "$TMP/bin/curl"
export PATH="$TMP/bin:$PATH"

result=$("$AZ_SHELL" "$ABE" 9780131457577)
expected_link='https://affiliates.abebooks.com/c/349003/77798/2029?u=https%3A%2F%2Fwww.abebooks.com%2Fservlet%2FBookDetailsPL%3Fbi%3D22908240098%26cm_ven%3Dsws%26cm_cat%3Dsws'
expect_eq \
  $'13.11\tUSD\tMarketing Management\t'"$expected_link" \
  "$result" \
  'cheapest delivered result'

grep -F 'sortorder=17' "$AZ_FAKE_CALLS" >/dev/null || fail 'sortorder=17 not sent'
grep -F 'destinationcountry=USA' "$AZ_FAKE_CALLS" >/dev/null || fail 'USA destination not sent'
grep -F 'maxresults=1' "$AZ_FAKE_CALLS" >/dev/null || fail 'maxresults=1 not sent'
grep -F 'isbn=9780131457577' "$AZ_FAKE_CALLS" >/dev/null || fail 'ISBN search not sent'
if grep -F 'bookcondition=' "$AZ_FAKE_CALLS" >/dev/null; then
  fail 'unfiltered lookup unexpectedly sent bookcondition'
fi

PRICE_FILE="$XDG_STATE_HOME/az/prices.tsv"
[[ -f "$PRICE_FILE" ]] || fail 'price ledger was not created'
grep -F $'www.abebooks.com\tabebooks-sws\tisbn:9780131457577\t13.11\tUSD\t'"$expected_link" "$PRICE_FILE" >/dev/null ||
  fail 'AbeBooks result was not recorded'

: > "$AZ_FAKE_CALLS"
used_result=$("$AZ_SHELL" "$ABE" used 9780131457577)
expect_eq \
  $'13.11\tUSD\tMarketing Management\t'"$expected_link" \
  "$used_result" \
  'cheapest delivered used result'
grep -F 'bookcondition=used' "$AZ_FAKE_CALLS" >/dev/null || fail 'used condition not sent'
grep -F 'sortorder=17' "$AZ_FAKE_CALLS" >/dev/null || fail 'used lookup lost delivered-price sort'
grep -F $'www.abebooks.com\tabebooks-sws-used\tisbn:9780131457577\t13.11\tUSD\t'"$expected_link" "$PRICE_FILE" >/dev/null ||
  fail 'used AbeBooks result was not recorded distinctly'

: > "$AZ_FAKE_CALLS"
"$AZ_SHELL" "$ABE" Marketing Management >/dev/null
grep -F 'title=Marketing Management' "$AZ_FAKE_CALLS" >/dev/null || fail 'title search not sent'

if AZ_ABEBOOKS_CLIENT_KEY= "$AZ_SHELL" "$ABE" find 9780131457577 >"$TMP/out" 2>"$TMP/err"; then
  fail 'missing search credentials unexpectedly succeeded'
fi
grep -F 'AZ_ABEBOOKS_CLIENT_KEY is not configured' "$TMP/err" >/dev/null ||
  fail 'missing-credential diagnostic changed'

cp "$AZ_FAKE_CALLS" "$TMP/calls-before-hostile"
if "$AZ_SHELL" "$ABE" find 'book 📖' >"$TMP/out" 2>"$TMP/err"; then
  fail 'unrepresentable title unexpectedly succeeded'
fi
grep -F 'title cannot be represented' "$TMP/err" >/dev/null || fail 'encoding diagnostic changed'
cmp "$AZ_FAKE_CALLS" "$TMP/calls-before-hostile" || fail 'unrepresentable title reached transport'

printf '%s\n' '#!/bin/sh' 'exit 22' > "$TMP/bin/curl"
if "$AZ_SHELL" "$ABE" find 9780131457577 >"$TMP/out" 2>"$TMP/err"; then
  fail 'failed AbeBooks transport unexpectedly succeeded'
fi
grep -F 'AbeBooks search request failed' "$TMP/err" >/dev/null || fail 'transport diagnostic changed'

printf 'ok\n'
