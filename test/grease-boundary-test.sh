#!/bin/sh
set -eu

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for program in bin/az bin/abe bin/aa bin/zillow; do
  first_line=$(sed -n '1p' "$program")
  test "$first_line" = '#!/usr/bin/env grease' ||
    fail "$program must use the Grease entry point"
done

if grep -R -n -F '#!/usr/bin/env ysh' bin; then
  fail 'consumer program still has a ysh shebang'
fi

if grep -R -n -E '(^|[[:space:]])ysh[[:space:]]+bin/' README.md docs .github/workflows; then
  fail 'consumer documentation or workflow still invokes ysh directly'
fi

if grep -R -n -F 'command -v ysh' .github/workflows; then
  fail 'workflow still probes ysh instead of Grease'
fi

printf '%s\n' 'Grease consumer boundary passed'
