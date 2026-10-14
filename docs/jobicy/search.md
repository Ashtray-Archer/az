# Search and discovery

## REST jobs endpoint

```text
GET https://jobicy.com/api/v2/remote-jobs
```

Authentication: none.

Optional query parameters documented by Jobicy:

- `count` — number of results, 1–200; default 200.
- `geo` — location slug such as `usa`, `europe`, or `apac`.
- `industry` — category slug such as `engineering`, `marketing`, or `data-science`.
- `tag` — keyword search over available job content.
- `cursor` — opaque continuation token, returned as `nextCursor`. Pass it
  unchanged and URI-encoded, retaining the original `geo`, `industry`, and `tag`.

`tag` accepts 3–50 bytes after trimming and stripping HTML, rather than a
Unicode character count. Use the documented taxonomy slugs for geographic and
industry filters. Provider `count` defaults to 200; the delivered CLI defaults
to 20 and validates the 1–200 range locally.

The JSON response contains a `jobs` array. Job records include an ID, canonical Jobicy URL, title, company, categories, employment type, geographic eligibility, seniority, description, publication date, and salary fields when supplied.

Jobicy asks integrations to retain the original source URL when displaying a listing.

## Cursor traversal and synchronization

`hasMore` and `nextCursor` describe continuation. Stop when `hasMore=false` and
`nextCursor=null`. Deduplicate by exact Jobicy ID. Tokens expire 24 hours after
the first request. Changing filters, or using an invalid/expired cursor, returns
HTTP 400. The upper publication boundary is fixed at traversal start; the lower
seven-day boundary is rechecked for each request, so older listings can drop out.

The CLI's `--all` traverses sequentially with a default 100-request safety
bound, configurable from 1 to 1000 with `--max-pages`. Repeated cursors,
inconsistent pages, failed requests and exhausted bounds produce nonzero exits
and withhold incomplete complete-feed output. A single page does not establish
feed completeness. This feed is delayed and limited to recent publications,
not a census or an assertion that remote workers may live in every country.

Start automated synchronization no more frequently than once per hour;
sequential pages/batches within a pass are allowed. Public feed responses may
be cached for 3600 seconds, status responses for 60 seconds. Respect throttling;
the CLI returns a distinct failure on HTTP 429 without a tight retry loop.

## Taxonomies and posting status

Use `GET /api/v2/remote-jobs?get=locations` or `?get=industries` for the taxonomy
response shapes and returned `geoSlug`/`industrySlug` values. Cursor parameters
are not part of taxonomy queries.

`GET https://jobicy.com/api/v2/remote-jobs/status?ids=123456,123457` checks stored
Jobicy IDs independently of the publication window. Supply 1–100 positive
integer values, each no greater than 9007199254740991. The limit counts supplied
values before deduplication; duplicates produce one result in first-occurrence
order. No cursor or search filters apply. Public access requires no credentials.

`active`, `closed`, and `unknown` are distinct. A missing/nonpublic ID can be
unknown; it is not confirmed closed. Disappearance from the recent feed does
not prove closure. This is Jobicy's listing state rather than a live employer
ATS probe. Status lookup has no descriptions or application links.

The delivered client retains exact IDs, original full descriptions, optional
salary fields, eligibility, timestamps, canonical source URLs and observation
provenance in TSV/JSONL. It does not activate commercial Bearer-key features or
consume paid direct-link credits.

## Other documented interfaces

- MCP server: `https://jobicy.com/mcp`; current tools include `get_jobs` and `get_taxonomies`.
- RSS: `https://jobicy.com/jobs/feed`.

The separate MCP/RSS notes above are historical inventory, outside this REST
implementation. Current REST source: https://jobicy.com/api/openapi.json,
OpenAPI 3.1.0 / API 2.2.19, retrieved 2026-10-13. Raw specification digest:
`a048b03b1fcf3480e86471c5f9fcaef31b39077a6fe9dadfacf9b232b3eaf5e0`.
Original research was checked against the developer page on 2026-08-31.
