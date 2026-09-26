# az

Small Grease-compatible command-line tools and service adapters.

`az` deliberately does not reproduce Amazon's web application. It asks for a
small amount of structured data, reduces it to a price observation, and leaves
the long-lived history in ordinary local files that IB or other programs can
index later.

The scripts target Grease and use the `grease` entry point. Consumers should
not invoke the inherited implementation runtime directly.

## Today

```sh
# Public affiliate links, no API credentials required.
grease bin/az link B012345678
grease bin/az search 'K&R C programming'

# Record something you saw yourself.
grease bin/az observe B012345678 19.99

# Once Creators credentials are configured:
grease bin/az price B012345678
grease bin/az history B012345678

# Once the AbeBooks client key is configured:
grease bin/abe 9780131457577
grease bin/abe used 9780131457577

# On the AA branch, once an Anna's Archive member key is in AA:
grease bin/aa resolve 6722faecdb9370ad0d2e447cce370950
```

`price` uses Amazon Creators API `GetItems` with `OffersV2` and appends one row
to the price ledger. `search` does not use Creators API credentials: it fetches
Amazon's ordinary search-result page, extracts up to ten ASINs, and constructs
ordinary product links with the configured Associates tag. The keyless path does
not claim price or title metadata; those TSV fields are intentionally blank.

`abe` asks AbeBooks Search Web Services for the cheapest delivered listing,
including shipping to the configured destination. `abe used` adds AbeBooks'
`bookcondition=used` filter, so the result is specifically the cheapest
delivered used listing rather than merely the cheapest listing of any
condition. Used observations are recorded with method `abebooks-sws-used`.

`aa resolve` calls Anna's Archive's member `fast_download.json` endpoint for an
MD5 and prints the returned download URL. It uses ICU for HTTP and deliberately
does not add an HTML search scraper or a curl fallback.

The local ledger is append-only TSV:

```text
observed_at  source  method  product  amount  currency  buy_url
```

By default it lives at `~/.local/state/az/prices.tsv`, following
`XDG_STATE_HOME` when set. The same ledger can store observations from other
merchants with `az record`.

## Amazon configuration

The US marketplace and public Associates tag are checked in at
`config/amazon-public`:

```text
AZ_MARKETPLACE=www.amazon.com
AZ_PARTNER_TAG=macguyver03-20
```

Environment variables can override those defaults, so a fork or another
installation can use another tag or no tagged distribution.

Creators credentials are needed for `price`, not for `link` or `search`.
They are secrets and are never committed. Copy the example:

```sh
mkdir -p ~/.config/az
cp config/amazon-secret.example ~/.config/az/amazon-secret
chmod 600 ~/.config/az/amazon-secret
$EDITOR ~/.config/az/amazon-secret
```

It expects:

```text
AZ_AMAZON_CREDENTIAL_ID=...
AZ_AMAZON_CREDENTIAL_SECRET=...
AZ_AMAZON_CREDENTIAL_VERSION=3.1
```

Credential versions 3.1, 3.2, and 3.3 select Amazon's North America, Europe,
and Far East Login-with-Amazon token endpoints respectively. Access tokens are
cached locally until shortly before their one-hour expiry instead of requesting
a new token for every price lookup.

Amazon and AbeBooks still use `curl`. The AA adapter uses ICU only; `jq` is used
for JSON and URI encoding. The remaining small-text tools are `grep`, `sed`,
`awk`, `tr`, and `date` as needed by each command.

```sh
grease bin/az doctor
grease bin/aa doctor
make test
sudo make install
```

## Anna's Archive configuration

`bin/aa` expects the member secret in the environment variable `AA` and only
implements the stable JSON fast-download resolver. The `AA` GitHub Environment
uses an Environment secret with the same name. The manual `AA live resolver`
workflow maps `${{ secrets.AA }}` to `$AA` and exercises the resolver through
ICU without printing the resolved URL in the Actions log.

See [`docs/annas-archive.md`](docs/annas-archive.md) for the transport boundary,
trusted-host rule, and current acceptance limits.

## Product identity

An ASIN is a useful merchant key, not the universal identity of a thing. The
price ledger therefore stores `source` and `product` separately. `az record`
can already write something like `isbn:...` or another application's canonical
product ID. This keeps Amazon as one replaceable source for prices rather than
making the rest of the system an Amazon database.

## SMS service

`bin/idric_sms_service` is the command-line/filesystem half of the first SMS
slice. It consumes the deterministic `idric-sms-request` executable supplied by
Idric-Net, persists inbound messages, per-event consent, reminders,
cancellations, STOP state, and a fake outbound transport in ordinary files.

The full executable acceptance test requires the Idric-Net parser:

```sh
IDRIC_SMS_REQUEST=/path/to/idric-sms-request make test-sms
```

`make test` still performs syntax checks without pretending that a missing
Idric-Net executable is an integration pass. See
[`docs/sms-service.md`](docs/sms-service.md) for the state model and ownership
boundary.

## Associates disclosure

This distribution can generate Amazon links containing the Associates tag
`macguyver03-20`. As an Amazon Associate, the operator of that tag may earn from
qualifying purchases.
