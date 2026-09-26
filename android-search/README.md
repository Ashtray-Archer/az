# Android search UI

This directory is a phone-facing presentation adapter for `az search`.

Android owns presentation and platform handoff. Amazon HTTP, affiliate search,
price lookup, filesystem caches, and product-search semantics remain in
`bin/az`. The APK requests no Internet permission.

The Activity:

- uses native Android views only; no WebView, Compose, Kotlin, Gradle, or
  Material Components dependency;
- parses the existing `az search` TSV contract:
  `asin`, `amount`, `currency`, `buy_url`, `title`;
- accepts TSV through `org.isomorphisms.az.SEARCH_RESULTS_TSV` or Android's
  ordinary `ACTION_SEND` text extra;
- accepts the source query through `org.isomorphisms.az.SEARCH_QUERY`;
- displays that source query separately from the local filter, so filtering
  cannot accidentally replace or reinterpret the original Amazon search;
- updates the loaded-result filter as text changes;
- accepts a later result handoff in the existing Activity instance;
- contains no fixture product results or Amazon credentials;
- opens a result's `buy_url` by handing it to the normal browser.

Current `az search` is deliberately keyless. It extracts up to ten ASINs from
Amazon's ordinary search page and supplies tagged product links. It does not
claim title or price metadata on that path, so the UI plainly shows those fields
as not loaded. The same TSV contract can display them later when a backend path
actually supplies them.

## Grease handoff

With the app installed, the external presentation handoff is:

```sh
grease android-search/show-results 'K&R C programming'
```

The handoff runs:

```text
grease bin/az search WORDS...
```

and supplies only the query and resulting TSV to
`org.isomorphisms.az.search/.SearchActivity` through Android's activity
manager. The Activity can then filter that already-loaded set locally. The APK
does not make the Amazon request itself.

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

Signing is a separate stage because Android update identity must survive rebuilds.
`sign-apk.sh` refuses to create a fresh key. It requires a persistent AZ Search
test keystore supplied by the caller:

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
checks the Android presentation/build boundaries. It is part of the normal
`make test` target.

The `android-search-build` workflow checks out the exact pull-request head,
builds the unsigned APK, verifies alignment and the no-Internet manifest
boundary, and retains the unsigned package plus source/hash receipts. It does
not label unsigned package construction as install or phone evidence.

`run-device-smoke.sh` is an optional host/ADB developer check. It requires a
persistently signed APK, uses replacement installation (`adb install -r`), and
does not uninstall around signer or version failures. It is not required for
the current direct-on-phone workflow.
