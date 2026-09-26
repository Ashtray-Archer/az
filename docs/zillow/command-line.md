# Zillow command line

`bin/zillow` is a Grease/YSH-compatible adapter for the Zillow interfaces that
this repository can describe exactly without scraping the consumer web site.

## Public Zillow Research data

No credentials are needed.

```sh
grease bin/zillow research list
grease bin/zillow research url zhvi-metro-all-homes-mid-tier-smoothed-seasonally-adjusted-monthly
grease bin/zillow research download zhvi-metro-all-homes-mid-tier-smoothed-seasonally-adjusted-monthly > zhvi.csv
```

`research list` prints tab-separated dataset identifier, description, and exact
upstream CSV URL. The checked-in catalog follows the direct download links
currently exposed by Zillow Research for these default selections:

- Zillow Home Value Index (ZHVI)
- Zillow Home Value Forecast growth (ZHVF)
- Zillow Observed Rent Index (ZORI)
- Zillow Observed Rent Forecast growth (ZORF)
- for-sale inventory
- sales-count nowcast
- mean days to pending
- market heat index
- new-construction sales count
- new-homeowner income needed

The catalog is deliberately explicit. The command does not manufacture URL
patterns for geography/data-type combinations that were not observed in the
current Zillow Research page.

## Zillow Mortgage partner API

The Zillow-hosted mortgage methods require an authorized Zillow partner ID.
Keep it outside Git:

```sh
mkdir -p ~/.config/az
cp config/zillow-secret.example ~/.config/az/zillow-secret
chmod 600 ~/.config/az/zillow-secret
$EDITOR ~/.config/az/zillow-secret
```

The file contains:

```text
ZILLOW_PARTNER_ID=...
```

The three currently documented GET methods are exposed as:

```sh
grease bin/zillow mortgage rates durationDays=30 includeCurrentRate=true
grease bin/zillow mortgage current-rates
grease bin/zillow mortgage lender-reviews nmlsId=123456 reviewLimit=10
```

Use `mortgage url` to inspect the exact request without sending it:

```sh
grease bin/zillow mortgage url rates durationDays=30 includeCurrentRate=true
grease bin/zillow mortgage url current-rates 'queries={"default":{"loanPurpose":"Purchase"}}'
grease bin/zillow mortgage url lender-reviews nmlsId=123456 'companyName=Example Bank'
```

Parameter names are whitelisted per method and values are URI-encoded. The
adapter supplies `partnerId` from configuration; callers do not pass it as a
free-form argument.

`getRates` accepts the documented `queries`, `durationDays`, `end`,
`includeCurrentRate`, `aggregation`, and `fill` names. `getCurrentRates`
accepts `queries`. `zillowLenderReviews` accepts `nmlsId`, `companyName`, and
`reviewLimit`, and `nmlsId` is required.

## Evidence boundary

The fake-transport tests prove command parsing, dataset selection, URI encoding,
parameter allowlists, required-parameter handling, and the exact URL passed to
ICU. They do not prove that this repository owns an authorized Zillow partner
ID or that authenticated/partner behavior succeeds live.

A successful public Research download is likewise evidence for that public CSV
only. It is not evidence for Bridge, Zestimate, MLS, Mortech, Rentals, or
dotloop access.
