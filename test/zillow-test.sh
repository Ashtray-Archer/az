#!/usr/bin/env bash
set -euo pipefail

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repository_directory=$(CDPATH= cd -- "$script_directory/.." && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

zillow="$repository_directory/bin/zillow"
expected_zhvi_dataset='zhvi-metro-all-homes-mid-tier-smoothed-seasonally-adjusted-monthly'
expected_zhvi_url='https://files.zillowstatic.com/research/public_csvs/zhvi/Metro_zhvi_uc_sfrcondo_tier_0.33_0.67_sm_sa_month.csv'
request_record="$temporary_directory/request"

cat > "$temporary_directory/icu" <<'FAKE_ICU'
#!/bin/sh
printf '%s\n' "$*" > "$ZILLOW_TEST_REQUEST_RECORD"
printf '%s\n' 'RegionID,RegionName' '1,Example'
FAKE_ICU
chmod +x "$temporary_directory/icu"

catalog=$(bash "$zillow" research list)
test "$(printf '%s\n' "$catalog" | wc -l | tr -d ' ')" = 10
printf '%s\n' "$catalog" | grep -q '^zhvi-metro-all-homes-mid-tier-smoothed-seasonally-adjusted-monthly[[:space:]]'
printf '%s\n' "$catalog" | grep -q '^zori-metro-all-homes-and-multifamily-smoothed-monthly[[:space:]]'
printf '%s\n' "$catalog" | grep -q '^new-homeowner-income-needed-metro-20-percent-down-mid-tier-smoothed-seasonally-adjusted-monthly[[:space:]]'

actual_url=$(bash "$zillow" research url "$expected_zhvi_dataset")
test "$actual_url" = "$expected_zhvi_url"

download_output=$(ZILLOW_TEST_REQUEST_RECORD="$request_record" ICU="$temporary_directory/icu" \
  bash "$zillow" research download "$expected_zhvi_dataset")
test "$download_output" = $'RegionID,RegionName\n1,Example'
test "$(cat "$request_record")" = "get $expected_zhvi_url"

rm -f "$request_record"
if ZILLOW_TEST_REQUEST_RECORD="$request_record" ICU="$temporary_directory/icu" \
    bash "$zillow" research download unsupported-dataset \
    >"$temporary_directory/unsupported.out" 2>"$temporary_directory/unsupported.err"; then
  printf 'zillow test: unsupported dataset unexpectedly succeeded\n' >&2
  exit 1
fi
test ! -e "$request_record"
grep -q 'unsupported research dataset' "$temporary_directory/unsupported.err"

rates_url=$(ZILLOW_PARTNER_ID='RD-EXAMPLE' bash "$zillow" mortgage url rates \
  durationDays=30 includeCurrentRate=true)
test "$rates_url" = 'https://mortgageapi.zillow.com/getRates?partnerId=RD-EXAMPLE&durationDays=30&includeCurrentRate=true'

current_rates_url=$(ZILLOW_PARTNER_ID='RD-EXAMPLE' bash "$zillow" mortgage url current-rates \
  'queries={"default":{"loanPurpose":"Purchase"}}')
test "$current_rates_url" = 'https://mortgageapi.zillow.com/getCurrentRates?partnerId=RD-EXAMPLE&queries=%7B%22default%22%3A%7B%22loanPurpose%22%3A%22Purchase%22%7D%7D'

lender_reviews_url=$(ZILLOW_PARTNER_ID='RD-EXAMPLE' bash "$zillow" mortgage url lender-reviews \
  nmlsId=1234 'companyName=A B' reviewLimit=10)
test "$lender_reviews_url" = 'https://mortgageapi.zillow.com/zillowLenderReviews?partnerId=RD-EXAMPLE&nmlsId=1234&companyName=A%20B&reviewLimit=10'

rm -f "$request_record"
mortgage_output=$(ZILLOW_TEST_REQUEST_RECORD="$request_record" ICU="$temporary_directory/icu" \
  ZILLOW_PARTNER_ID='RD-EXAMPLE' bash "$zillow" mortgage lender-reviews nmlsId=1234 reviewLimit=3)
test "$mortgage_output" = $'RegionID,RegionName\n1,Example'
test "$(cat "$request_record")" = 'get https://mortgageapi.zillow.com/zillowLenderReviews?partnerId=RD-EXAMPLE&nmlsId=1234&reviewLimit=3'

if ZILLOW_PARTNER_ID='RD-EXAMPLE' bash "$zillow" mortgage url lender-reviews reviewLimit=3 \
    >"$temporary_directory/missing-nmls.out" 2>"$temporary_directory/missing-nmls.err"; then
  printf 'zillow test: lender reviews without nmlsId unexpectedly succeeded\n' >&2
  exit 1
fi
grep -q 'requires nmlsId=VALUE' "$temporary_directory/missing-nmls.err"

if ZILLOW_PARTNER_ID='RD-EXAMPLE' bash "$zillow" mortgage url rates invented=value \
    >"$temporary_directory/invented.out" 2>"$temporary_directory/invented.err"; then
  printf 'zillow test: unsupported mortgage parameter unexpectedly succeeded\n' >&2
  exit 1
fi
grep -q 'unsupported rates parameter: invented' "$temporary_directory/invented.err"

if bash "$zillow" mortgage url rates \
    >"$temporary_directory/no-partner.out" 2>"$temporary_directory/no-partner.err"; then
  printf 'zillow test: mortgage request without partner ID unexpectedly succeeded\n' >&2
  exit 1
fi
grep -q 'mortgage partner ID is not configured' "$temporary_directory/no-partner.err"

ICU="$temporary_directory/icu" bash "$zillow" doctor >"$temporary_directory/doctor.out" || true
grep -q '^research_dataset_count[[:space:]]10$' "$temporary_directory/doctor.out"
grep -q '^mortgage_partner_id[[:space:]]missing$' "$temporary_directory/doctor.out"

printf 'zillow tests passed\n'
