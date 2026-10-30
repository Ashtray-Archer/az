#!/bin/bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
AZ="$ROOT/bin/az"
AZ_SHELL=${AZ_SHELL:-bash}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
export XDG_CONFIG_HOME="$TMP/config"
export XDG_STATE_HOME="$TMP/state"
export XDG_CACHE_HOME="$TMP/cache"
export AZ_STATE_DIR="$TMP/state-override"
export AZ_CACHE_DIR="$TMP/cache-override"
export AZ_SECRET_FILE="$TMP/config-override/amazon-secret"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"

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

# Public affiliate-link primitive.
expect_eq \
  'https://www.amazon.com/dp/B012345678?tag=macguyver03-20' \
  "$("$AZ_SHELL" "$AZ" link B012345678)" \
  'ASIN link'

expect_eq \
  'https://www.amazon.com/dp/B012345678?tag=macguyver03-20' \
  "$("$AZ_SHELL" "$AZ" link 'https://www.amazon.com/dp/b012345678?th=1')" \
  'URL ASIN extraction'

doctor=$("$AZ_SHELL" "$AZ" doctor)
printf '%s\n' "$doctor" | grep -F "$(printf 'marketplace\twww.amazon.com')" >/dev/null ||
  fail 'doctor did not report the configured marketplace'
printf '%s\n' "$doctor" | grep -F "$(printf 'ok\tawk')" >/dev/null ||
  fail 'doctor did not complete dependency checks'
printf '%s\n' "$doctor" | grep -F "$(printf 'price_file\t%s' "$AZ_STATE_DIR/prices.tsv")" >/dev/null ||
  fail 'doctor did not preserve AZ_STATE_DIR'
printf '%s\n' "$doctor" | grep -F "$(printf 'price_cache_dir\t%s' "$AZ_CACHE_DIR/amazon")" >/dev/null ||
  fail 'doctor did not report the filesystem price cache'
printf '%s\n' "$doctor" | grep -F "$(printf 'price_fresh_minutes\t60')" >/dev/null ||
  fail 'doctor did not report the one-hour filesystem freshness window'
printf '%s\n' "$doctor" | grep -F "$(printf 'secret_file\t%s' "$AZ_SECRET_FILE")" >/dev/null ||
  fail 'doctor did not preserve AZ_SECRET_FILE'

# Manual observation is immediately useful before Creators credentials exist.
"$AZ_SHELL" "$AZ" observe B012345678 19.99 >/dev/null
PRICE_FILE="$AZ_STATE_DIR/prices.tsv"
[[ -f "$PRICE_FILE" ]] || fail 'price ledger was not created'
[[ $(wc -l < "$PRICE_FILE") -eq 2 ]] || fail 'manual observation should add one row'
grep -F $'www.amazon.com\tmanual\tB012345678\t19.99\tUSD\thttps://www.amazon.com/dp/B012345678?tag=macguyver03-20' "$PRICE_FILE" >/dev/null ||
  fail 'manual observation row is wrong'

# Provider-neutral records use the same ledger and history lookup.
"$AZ_SHELL" "$AZ" record example.test isbn:9780000000000 8.50 USD \
  https://example.test/book html >/dev/null
history=$("$AZ_SHELL" "$AZ" history isbn:9780000000000)
[[ "$history" == *$'example.test\thtml\tisbn:9780000000000\t8.50\tUSD\thttps://example.test/book'* ]] ||
  fail 'provider-neutral history lookup failed'

# Mock curl lets the complete Creators flow run without live credentials or network.
mkdir -p "$TMP/bin"
export AZ_FAKE_CALLS="$TMP/curl-calls"
cat > "$TMP/bin/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$AZ_FAKE_CALLS"
for arg in "$@"; do
  case "$arg" in
    https://mock/token)
      printf '%s\n' '{"access_token":"test-token","expires_in":3600}'
      exit 0
      ;;
    https://mock/catalog/v1/getItems)
      cat <<'JSON'
{"itemsResult":{"items":[{"asin":"B012345678","detailPageURL":"https://www.amazon.com/dp/B012345678?tag=macguyver03-20&linkCode=ogi","offersV2":{"listings":[{"isBuyBoxWinner":true,"price":{"money":{"amount":23.45,"currency":"USD","displayAmount":"$23.45"}}}]}}]}}
JSON
      exit 0
      ;;
    'https://www.amazon.com/s?k=fixture')
      cat "$AZ_FAKE_SEARCH_HTML"
      exit 0
      ;;
    'https://www.amazon.com/s?k=small%20useful%20book')
      cat <<'HTML'
<html><body>
<div data-asin="B098765432" data-component-type="s-search-result"></div>
<div data-asin="B011111111" data-component-type="s-search-result"></div>
<div data-asin="B098765432" data-component-type="s-search-result"></div>
</body></html>
HTML
      exit 0
      ;;
  esac
done
printf 'fake curl: unexpected arguments: %s\n' "$*" >&2
exit 22
EOF
chmod +x "$TMP/bin/curl"

export PATH="$TMP/bin:$PATH"

# Search works before any Creators API credential exists. Amazon's ordinary
# search page supplies ASINs; AZ constructs the tagged product links itself.
search=$("$AZ_SHELL" "$AZ" search small useful book)
search_header=$(printf '%s\n' "$search" | sed -n '1p')
expected_search_header=$(printf 'asin\tamount\tcurrency\tbuy_url\ttitle')
expect_eq "$expected_search_header" "$search_header" \
  'search TSV header consumed by the Android frontend'
first_row=$(printf 'B098765432\t\t\thttps://www.amazon.com/dp/B098765432?tag=macguyver03-20\t')
second_row=$(printf 'B011111111\t\t\thttps://www.amazon.com/dp/B011111111?tag=macguyver03-20\t')
printf '%s\n' "$search" | grep -F "$first_row" >/dev/null ||
  fail 'ordinary Amazon search did not produce the first tagged product link'
printf '%s\n' "$search" | grep -F "$second_row" >/dev/null ||
  fail 'ordinary Amazon search did not produce the second tagged product link'
[[ $(printf '%s\n' "$search" | grep -c '^B098765432') -eq 1 ]] ||
  fail 'ordinary Amazon search did not de-duplicate ASINs'
if grep -F 'https://mock/token' "$AZ_FAKE_CALLS" >/dev/null; then
  fail 'search tried to obtain a Creators API token'
fi

export AZ_AMAZON_CREDENTIAL_ID='test-id'
export AZ_AMAZON_CREDENTIAL_SECRET='test-secret'
export AZ_AMAZON_CREDENTIAL_VERSION='3.1'
export AZ_AMAZON_TOKEN_ENDPOINT='https://mock/token'
export AZ_CREATORS_API_BASE='https://mock'

api_price=$("$AZ_SHELL" "$AZ" price B012345678)
[[ "$api_price" == *$'B012345678\t23.45\tUSD\thttps://www.amazon.com/dp/B012345678?tag=macguyver03-20&linkCode=ogi'* ]] ||
  fail 'Creators price output is wrong'

[[ -f "$AZ_CACHE_DIR/amazon-token.tsv" ]] || fail 'AZ_CACHE_DIR token cache override was not preserved'

PRICE_CACHE="$AZ_CACHE_DIR/amazon/B012345678/price"
[[ -f "$PRICE_CACHE" ]] || fail 'price was not cached as an ordinary file'
IFS=$'\t' read -r cached_at cached_amount cached_currency cached_url < "$PRICE_CACHE"
expect_eq '23.45' "$cached_amount" 'cached amount'
expect_eq 'USD' "$cached_currency" 'cached currency'
[[ "$cached_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] ||
  fail 'cached observation time is not whole-second local text'
[[ "$cached_at" != *Z ]] || fail 'cached observation time was forced to UTC'
cache_fields=$(awk -F '\t' 'NR == 1 { print NF }' "$PRICE_CACHE")
[[ "$cache_fields" -eq 4 ]] ||
  fail 'price cache duplicated expiry metadata instead of using file freshness'

grep -F $'www.amazon.com\tcreators-api\tB012345678\t23.45\tUSD\thttps://www.amazon.com/dp/B012345678?tag=macguyver03-20&linkCode=ogi' "$PRICE_FILE" >/dev/null ||
  fail 'Creators price was not recorded'

# A second lookup is purely a filesystem read. It must not touch either the
# token endpoint or GetItems, and it returns the original observation time.
cached_price=$("$AZ_SHELL" "$AZ" price B012345678)
expect_eq "$api_price" "$cached_price" 'fresh filesystem-cached price'
catalog_calls=$(grep -c 'https://mock/catalog/v1/getItems' "$AZ_FAKE_CALLS")
[[ "$catalog_calls" -eq 1 ]] || fail "fresh price cache still called GetItems ($catalog_calls calls)"

# Make the ordinary cache file stale through its filesystem timestamp. The next
# lookup deletes/ignores it, performs exactly one price-only request, and
# atomically replaces it. No POSIX expiry value lives inside the cache object.
touch -t 200001010000 "$PRICE_CACHE"
refreshed_price=$("$AZ_SHELL" "$AZ" price B012345678)
[[ "$refreshed_price" == *$'B012345678\t23.45\tUSD\thttps://www.amazon.com/dp/B012345678?tag=macguyver03-20&linkCode=ogi'* ]] ||
  fail 'stale price cache was not refreshed'
catalog_calls=$(grep -c 'https://mock/catalog/v1/getItems' "$AZ_FAKE_CALLS")
[[ "$catalog_calls" -eq 2 ]] || fail "stale price cache did not cause exactly one refetch ($catalog_calls calls)"

# Search did not use the token endpoint. The token itself is cached too, so
# both API price fetches still require only one OAuth token request.
token_calls=$(grep -c 'https://mock/token' "$AZ_FAKE_CALLS")
[[ "$token_calls" -eq 1 ]] || fail "expected one token request, got $token_calls"

grep -F 'macguyver03-20' "$AZ_FAKE_CALLS" >/dev/null ||
  fail 'partner tag did not reach Creators request payload'
grep -F 'offersV2.listings.price' "$AZ_FAKE_CALLS" >/dev/null ||
  fail 'price resource did not reach Creators request payload'
if grep -F 'offersV2.listings.isBuyBoxWinner' "$AZ_FAKE_CALLS" >/dev/null; then
  fail 'price lookup requested unnecessary BuyBox metadata'
fi


# Search result status is an independently readable, atomic TSV beside the
# legacy five-column output. A header-only result is never successful.
export AZ_SEARCH_STATUS_FILE="$TMP/search-status.tsv"
export AZ_FAKE_SEARCH_HTML="$TMP/amazon-fixture.html"
cat > "$AZ_FAKE_SEARCH_HTML" <<'HTML'
<html><body><div id="search"><div data-component-type="s-search-result" data-asin="B000PEZ1L4"></div>
<div data-component-type="s-search-result" data-asin="B000CCFXYY"></div>
<div data-component-type="s-search-result" data-asin="B000CCFXYY"></div></div></body></html>
HTML
fixture=$("$AZ_SHELL" "$AZ" search fixture)
[[ "$fixture" == *B000PEZ1L4* && "$fixture" == *B000CCFXYY* ]] ||
  fail 'known candidate ASINs not extracted'
[[ $(printf '%s\n' "$fixture" | grep -c '^B000CCFXYY') -eq 1 ]] ||
  fail 'candidate duplicates not removed'
grep -Fx "$(printf 'status\tEXTRACTED_UNVERIFIED')" "$AZ_SEARCH_STATUS_FILE" >/dev/null ||
  fail 'candidate search status was elevated or not recorded'
grep -Fx "$(printf 'price\tUNKNOWN')" "$AZ_SEARCH_STATUS_FILE" >/dev/null ||
  fail 'scraped search price was invented'

cat > "$AZ_FAKE_SEARCH_HTML" <<'HTML'
<html><head><title>Robot Check</title></head>
<body>Enter the characters you see below <form action="/errors/validateCaptcha"></form></body></html>
HTML
if "$AZ_SHELL" "$AZ" search fixture >"$TMP/search.out" 2>"$TMP/search.err"; then
  fail 'Amazon challenge returned success'
else
  [[ $? -eq 5 ]] || fail 'challenge did not have distinct exit status'
fi
grep -Fx "$(printf 'status\tCHALLENGE')" "$AZ_SEARCH_STATUS_FILE" >/dev/null ||
  fail 'challenge missing from machine-readable status'

cat > "$AZ_FAKE_SEARCH_HTML" <<'HTML'
<html><body><div id="search">No results for fixture</div></body></html>
HTML
if "$AZ_SHELL" "$AZ" search fixture >"$TMP/search.out" 2>"$TMP/search.err"; then
  fail 'confirmed empty search returned success'
else
  [[ $? -eq 3 ]] || fail 'confirmed empty search had wrong status'
fi
grep -Fx "$(printf 'status\tCONFIRMED_EMPTY')" "$AZ_SEARCH_STATUS_FILE" >/dev/null ||
  fail 'confirmed empty missing from status file'

printf '<html><body>changed renderer</body></html>\n' > "$AZ_FAKE_SEARCH_HTML"
if "$AZ_SHELL" "$AZ" search fixture >"$TMP/search.out" 2>"$TMP/search.err"; then
  fail 'unrecognized HTML returned success'
else
  [[ $? -eq 4 ]] || fail 'unrecognized HTML had wrong status'
fi
grep -Fx "$(printf 'status\tHTML_UNVERIFIED')" "$AZ_SEARCH_STATUS_FILE" >/dev/null ||
  fail 'HTML/parser drift missing from status file'

if "$AZ_SHELL" "$AZ" link BAD >"$TMP/link.out" 2>"$TMP/link.err"; then
  fail 'malformed ASIN accepted'
fi
if "$AZ_SHELL" "$AZ" link 'https://unrelated.example/dp/B000CCFXYY' >"$TMP/link.out" 2>"$TMP/link.err"; then
  fail 'non-Amazon URL was accepted as merchant product evidence'
fi
if AZ_PARTNER_TAG='bad?tag' "$AZ_SHELL" "$AZ" link B000CCFXYY >"$TMP/link.out" 2>"$TMP/link.err"; then
  fail 'invalid Associates tag accepted'
fi
expect_eq 'https://www.amazon.com/dp/B000PEZ1L4?tag=macguyver03-20' \
  "$("$AZ_SHELL" "$AZ" link B000PEZ1L4)" 'moisture barrier exact link'
expect_eq 'https://www.amazon.com/dp/B000CCFXYY?tag=macguyver03-20' \
  "$("$AZ_SHELL" "$AZ" link B000CCFXYY)" 'weatherstrip exact link'
expect_eq 'https://www.amazon.com/dp/B000CCFXYY?tag=test-other-20' \
  "$(AZ_PARTNER_TAG=test-other-20 "$AZ_SHELL" "$AZ" link B000CCFXYY)" 'explicit partner tag override'

printf 'ok\n'
