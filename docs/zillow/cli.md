# Zillow command-line slice

Snapshot: 2026-09-17

The first executable `zillow` command is deliberately limited to one public
Zillow Research download whose current source is the Zillow Research Housing
Data page:

<https://www.zillow.com/research/data/>

The supported dataset identifier is:

`zhvi-metro-all-homes-mid-tier-smoothed-seasonally-adjusted-monthly`

It maps exactly to:

<https://files.zillowstatic.com/research/public_csvs/zhvi/Metro_zhvi_uc_sfrcondo_tier_0.33_0.67_sm_sa_month.csv>

Use:

```sh
grease bin/zillow research url zhvi-metro-all-homes-mid-tier-smoothed-seasonally-adjusted-monthly
grease bin/zillow research download zhvi-metro-all-homes-mid-tier-smoothed-seasonally-adjusted-monthly > zhvi.csv
```

`url` is inspectable and performs no network request. `download` streams the
public CSV through ICU to standard output. The command does not parse Zillow
consumer property pages and does not expose Bridge, mortgage partner, Mortech,
Rentals, dotloop, or legacy ZWSID calls.

The test uses a fake ICU executable only to prove command dispatch, exact URL
selection, output pass-through, and rejection of unsupported dataset names. It
is not a live Zillow Research acceptance receipt. A live download must be
recorded separately if that evidence is needed.

Zillow Research attribution requirements still apply to derived use of the
downloaded data.
