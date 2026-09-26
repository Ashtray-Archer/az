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
- renders search results immediately and shows a quiet `—` where price has not
  arrived yet;
- starts at most three background `az price ASIN` jobs at a time and updates
  each card only when that result Intent arrives; there is no polling loop;
- keeps the source Amazon query separate from the local loaded-result filter;
- updates the loaded-result filter as text changes;
- can also accept TSV through `org.isomorphisms.az.SEARCH_RESULTS_TSV` or
  Android's ordinary `ACTION_SEND` text extra;
- contains no fixture product results or Amazon credentials;
- opens a result's `buy_url` by handing it to the normal browser.

Current `az search` is deliberately keyless. It extracts up to ten ASINs from
Amazon's ordinary search page and supplies tagged product links. It does not
claim title or price metadata on that path. The UI therefore draws the cards
first, uses `—` for the absent price, and asks the merged `az price` backend
for each ASIN independently. Fresh prices are ordinary filesystem reads; stale
or absent prices are refreshed by the backend before it returns.

## In-app search boundary

The frontend talks to Termux rather than duplicating AZ's search implementation.
The command boundary is fixed to:

```text
/data/data/com.termux/files/usr/bin/az search QUERY
/data/data/com.termux/files/usr/bin/az price ASIN
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

The installed AZ executable must be available at Termux's normal
`/data/data/com.termux/files/usr/bin/az`. From a repo checkout in Termux:

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
rebuilds. AZ Search now has one canonical signing identity.

The public certificate is checked in at:

```text
android-search/signing/az-search-cert.pem
```

and its required SHA-256 fingerprint is:

```text
E4:A7:1B:ED:67:F2:2D:26:38:ED:E9:89:E6:F6:B5:F8:58:7C:1B:21:59:3D:98:21:83:50:77:D5:89:56:DA:86
```

The private keystore is deliberately **not** in Git. `sign-apk.sh` signs with
the supplied private keystore and then verifies the resulting APK against that
checked-in canonical fingerprint. A mismatched signer is rejected and the
output APK is deleted.

Normal signing uses:

```sh
ANDROID_KEYSTORE=/path/to/az-search.keystore \
ANDROID_KEY_ALIAS=az-search \
ANDROID_KEYSTORE_PASSWORD='...' \
ANDROID_KEY_PASSWORD='...' \
sh android-search/sign-apk.sh
```

`create-test-signer.sh` remains useful for forks or experiments that establish
a different application identity, but a newly generated key will not satisfy
this repository's canonical AZ Search signer contract unless the checked-in
public identity is deliberately changed.

The historical September 14 test APK used a disposable debug signer and cannot
be updated in place by the canonical signer. Installing the canonical build is
therefore a one-time signer migration. After that, replacement installation
must work without uninstalling the app.

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
