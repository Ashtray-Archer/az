# Android search UI

This directory is a phone-facing Material-style frontend for `az search`.

Android owns presentation and the narrow platform handoff. Amazon HTTP,
affiliate search, price lookup, filesystem caches, and product-search semantics
remain in `bin/az`. The APK requests no Internet permission.

The Activity:

- uses native Android views only; no WebView, Compose, Kotlin, Gradle, or
  Material Components dependency;
- has a real Amazon search field that invokes the installed AZ command through
  Termux's documented `RUN_COMMAND` service;
- passes the query as an argument to `$PREFIX/bin/az search`, not as shell text;
- receives command stdout through a one-shot `PendingIntent`;
- parses the existing `az search` TSV contract:
  `asin`, `amount`, `currency`, `buy_url`, `title`;
- keeps the source Amazon query separate from the local loaded-result filter;
- updates the loaded-result filter as text changes;
- can also accept TSV through `org.isomorphisms.az.SEARCH_RESULTS_TSV` or
  Android's ordinary `ACTION_SEND` text extra;
- contains no fixture product results or Amazon credentials;
- opens a result's `buy_url` by handing it to the normal browser.

Current `az search` is deliberately keyless. It extracts up to ten ASINs from
Amazon's ordinary search page and supplies tagged product links. It does not
claim title or price metadata on that path, so the UI plainly shows those fields
as not loaded. The same TSV contract can display them later when a backend path
actually supplies them.

## In-app search boundary

The frontend talks to Termux rather than duplicating AZ's search implementation.
The command boundary is fixed to:

```text
$PREFIX/bin/az search QUERY
```

The app declares only Termux's dangerous
`com.termux.permission.RUN_COMMAND` permission; it still does **not** declare
`android.permission.INTERNET`. It asks Android for the command permission when
the user first searches.

Termux also requires its own explicit opt-in:

```text
allow-external-apps=true
```

in `~/.termux/termux.properties`. Termux must then reload its settings. This
is a Termux security boundary, not something the APK silently changes.

The result-return path requires a Termux version supporting
`RUN_COMMAND_PENDING_INTENT` results (Termux >= 0.109). The search runs as a
background Termux command so stdout and stderr are returned separately.

The installed AZ executable must be available at `$PREFIX/bin/az`. From a repo
checkout in Termux:

```sh
make install-az PREFIX="$PREFIX"
```

Cat Food can later own that installation declaratively.

Official Termux contract:
https://github.com/termux/termux-app/wiki/RUN_COMMAND-Intent

## External fallback handoff

The older outside-in path remains useful for acceptance and debugging:

```sh
grease android-search/show-results 'K&R C programming'
```

That runs the repo-local:

```text
grease bin/az search WORDS...
```

and supplies only the query and resulting TSV to
`org.isomorphisms.az.search/.SearchActivity` through Android's activity
manager. It exercises the same parser and result UI without the in-app
Termux-command request path.

## Build stages

There is deliberately no Gradle project.

`build-apk.sh` performs source compilation, DEX construction, resource
packaging, and alignment:

```text
aapt2 -> javac -> d8 -> zipalign
```

With Android SDK platform 36 and build-tools 36.0.0 installed:

```sh
sh android-search/build-apk.sh
```

This writes `android-search/build/az-search-unsigned.apk`. That file is build
evidence, not an installable release claim.

Signing is a separate stage because Android update identity must survive
rebuilds. `sign-apk.sh` refuses to create a fresh key.

For the one-time signer setup, `create-test-signer.sh` creates a keystore only
at an explicitly supplied path **outside this repository** and refuses to
overwrite an existing signer:

```sh
ANDROID_KEYSTORE_PASSWORD='...' \
sh android-search/create-test-signer.sh \
  "$HOME/.local/share/az/az-search-test.keystore"
```

It prints the public SHA-256 certificate fingerprint for the acceptance record.
That setup script is not part of the build path.

Normal signing then reuses the same keystore:

```sh
ANDROID_KEYSTORE=/path/to/persistent-test.keystore \
ANDROID_KEY_ALIAS=az-search-test \
ANDROID_KEYSTORE_PASSWORD='...' \
ANDROID_KEY_PASSWORD='...' \
sh android-search/sign-apk.sh
```

`ANDROID_SIGNER_SHA256` may also be supplied to require an expected signer
certificate digest. The script writes `android-search/build/az-search.apk`.

The historical September 14 test APK was built with a disposable debug signer.
That launch observation remains historical evidence for that old artifact only.
Moving from that artifact to the eventual persistent signer is an explicit
one-time signer migration; after that migration, replacement installation must
work without uninstalling the app.

## Checks

`test/android-search-test.sh` executes the pure-Java TSV parser/filter tests and
checks the Android, Termux-command, presentation, and build boundaries. It is
part of the normal `make test` target.

The `android-search-build` workflow checks out the exact pull-request head,
builds the unsigned APK, verifies alignment and the no-Internet manifest
boundary, and retains the unsigned package plus source/hash receipts. It does
not label unsigned package construction as install or phone evidence.

`run-device-smoke.sh` is an optional host/ADB developer check. It requires a
persistently signed APK, uses replacement installation (`adb install -r`), and
does not uninstall around signer or version failures. It is not required for
the current direct-on-phone workflow.
