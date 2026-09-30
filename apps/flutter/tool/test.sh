#!/usr/bin/env bash
# Exclude exFAT AppleDouble files when enumerating Flutter tests.
set -euo pipefail
cd "$(dirname "$0")/.."
files=()
while IFS= read -r f; do files+=("$f"); done < <(find test -name '*_test.dart' ! -name '._*' | sort)
exec ./tool/flutter.sh test "$@" "${files[@]}"
