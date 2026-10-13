# Jobicy executable closure — 2026-10-13

The original research at `5bdbe924ad2374af2a077f5d32060f0583db8671` is now
connected to an actual compiled, installed Idriç command. Its implementation
obligation is satisfied on the executed Linux x86-64 host rather than left as a
documentation-only checkpoint.

Implementation: [dilapidated-shed/idric-cli PR #9, “Deliver a tested Idriç Jobicy CLI with live public searches”](https://github.com/dilapidated-shed/idric-cli/pull/9).
Exact tested application revision: `9c7c676618bb007845d8e54264256fda8c70a04e`.

Source-bound closure: [isomorphisms/flexible-pipes PR #110, “Record source-bound Jobicy build and live-provider acceptance”](https://github.com/isomorphisms/flexible-pipes/pull/110).
[Complete receipt](https://github.com/isomorphisms/flexible-pipes/blob/4c86fc0fb6e564754d296d2ddbed0d4ce0a17ffc/receipts/jobicy-cli/README.md),
including exact dependency/toolchain revisions, actual commands/exits, full
test streams, installed artifact digests and raw public-provider evidence.

Final run `jobicy-cli-acceptance-20261013T230751.265008Z` passed all nine stages
with actual exit 0. It includes 55 labelled regression cases, full-description
byte comparisons, Unicode/URI encoding, actual ICU loopback transport,
pagination/status/error cases, installation outside the checkout, six native
build-policy assertions, the independent ai-ci oracle and a rejected
unknown-to-closed mutant. Kitchen owns build/install/test; ICK builds applicable
native C infrastructure. Idriç owns the application behavior and JSON decoding.

Live public API 2.2.19 search `count=3&geo=usa`, observed
2026-10-13T23:08:04Z, received HTTP 200 and actual CLI exit 0:

| Exact ID | Employer | Title | Eligibility |
|---|---|---|---|
| 155204 | Solace | Performance Creative Manager | USA |
| 155200 | Solace | Senior Backend Engineer | USA |
| 155199 | Solace | Staff Software Engineer | USA |

`status 155204` received HTTP 200, exited 0, and returned active. Two real
cursor-page requests also received HTTP 200; the configured two-page bound then
returned exit 9 and withheld incomplete complete-feed output. These observations
are a sample and bounded traversal test, not an employment count. Full original
descriptions and canonical source URLs are retained in the receipt. No salary
was supplied for these three postings.

An earlier genuine transport failure is retained as historical evidence. ICU's
configured proxy repair resolved the host's lack of a direct route; the failed
attempt is not rewritten as a successful empty response. No credentials,
commercial API features or paid application-link credits were used.

A1 ARM32/Termux and C67 ARM64 physical-device acceptance remain **NOT_RUN**.
The delivered host installation has declared native Chez/OpenSSL runtime
dependencies; it is not represented as a portable standalone binary. The PRs
are reviewable and unmerged. This refresh changes only the Jobicy research
records, leaving other providers and unrelated az code untouched.
