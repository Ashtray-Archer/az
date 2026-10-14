# Jobicy API

Status: **public and usable without authentication; executable host acceptance delivered**.

Official developer documentation: https://jobicy.com/jobs-rss-feed

Refreshed on 2026-10-13 against https://jobicy.com/api/openapi.json:
OpenAPI **3.1.0**, API **2.2.19**, exact raw SHA-256
`a048b03b1fcf3480e86471c5f9fcaef31b39077a6fe9dadfacf9b232b3eaf5e0`.

The public REST API provides recent remote-job search with cursor pagination,
location/industry taxonomies, and a separate batch posting-status endpoint.
The seven-day publication feed is not a nationwide employment census.

For a command-line job-search backend, this is one of the straightforward services in this inventory because it requires no partner approval or API key.

The documentation-only checkpoint now has an actual Idriç executable, installed
and tested with live public-provider evidence. See [closure.md](closure.md).
A1 ARM32/Termux and C67 ARM64 physical-device tests remain separate NOT_RUN
targets; they are not inferred from Linux results.

## Files

- `endpoints.txt` — literal endpoint inventory.
- `search.md` — REST parameters, response shape, and usage notes.
- `closure.md` — exact implementation revision, executed acceptance and receipts.
