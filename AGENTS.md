# Agent instructions

Apply the shared evidence and acceptance guardrails in
`isomorphisms/ai-ci/AGENTS.md`.

Before changing this repository, read its README and repository-local
documentation, inspect the current branch/worktree and nearby active work, and
preserve established architecture, terminology, source/build layout, and
explicit current human corrections.

Keep this file repository-specific. Add local rules as the project develops; do
not copy the shared `ai-ci` rulebook here.

## SMS service boundary

`bin/idric_sms_service` owns command-line invocation and filesystem state for the
SMS service slice. Idric-Net owns SMS meanings and the deterministic
`idric-sms-request` parser. Do not copy that parser into this repository or
replace it with a shell approximation just to make a local test pass.

A syntax check is not an SMS integration receipt. Full SMS acceptance must name
and execute the exact Idric-Net parser revision used by the test.

## Zillow boundary

Keep Zillow Research downloads, Zillow Mortgage partner calls, Bridge products,
Mortech products, Zillow Rentals integrations, and dotloop OAuth as distinct
interfaces. Do not flatten them into one generic request path.

Do not substitute consumer-site page parsing for an unavailable documented API.
Do not restore legacy ZWSID calls from old examples unless a current Zillow
source establishes that the endpoint is still supported.

The files under `docs/zillow/` document source locations and interface shape;
they are not live-service acceptance. A documentation fetch, CSV fixture, or
mock response does not establish permission, authentication, or successful API
execution.

## Grease consumer boundary

Grease is the consumer-facing shell language and command for the Grease-based
programs in this repository. Use `grease` in shebangs, examples, workflows,
receipts, and human-facing instructions. Do not invoke or name `ysh` as the
consumer runtime. The inherited Oils implementation is an internal Grease
implementation detail and belongs only in implementation/provenance discussion
inside the Grease/Oils repositories.

## AZ filesystem state

Treat ordinary filesystem state as an architectural primitive for AZ. Product
identity, disposable Amazon cache entries, durable observations, searches, and
future alternate views should use files, directories, links, timestamps, atomic
rename, and append-oriented files where those semantics fit naturally.

Do not introduce SQLite or another application database by default. Revisit a
database only after a concrete requirement demonstrates that the filesystem
design cannot reasonably satisfy it. Do not copy filesystem patterns from other
projects mechanically; choose the representation that fits each AZ operation.

Amazon price cache entries live under `XDG_CACHE_HOME/az/amazon/ASIN/price`
(or `~/.cache/az/amazon/ASIN/price`) and must be treated as ephemeral. A stale
price is absence, not a usable observation.
Do not model AZ time as mandatory UTC/POSIX epoch seconds. Preserve declared
precision and use filesystem time semantics when they naturally express cache
freshness. Until the shared Idriç imprecise-time type lands, stored observation
times should remain whole-second human-readable text without invented fractional
precision or a forced UTC marker. See issue #15.

