#!/usr/bin/env bash
# Select a project SDK without changing the user's global Flutter installation.
# CAMEO_FLUTTER_SDK > apps/flutter/.flutter-sdk (local symlink) > Flutter on PATH.
set -euo pipefail
app_dir="$(cd "$(dirname "$0")/.." && pwd)"
if [ -n "${CAMEO_FLUTTER_SDK:-}" ]; then
  flutter_bin="$CAMEO_FLUTTER_SDK/bin/flutter"
elif [ -e "$app_dir/.flutter-sdk" ] || [ -L "$app_dir/.flutter-sdk" ]; then
  flutter_bin="$app_dir/.flutter-sdk/bin/flutter"
else
  flutter_bin="$(command -v flutter || true)"
fi
if [ -z "$flutter_bin" ] || [ ! -x "$flutter_bin" ]; then
  echo "Flutter SDK not found. Set CAMEO_FLUTTER_SDK or link apps/flutter/.flutter-sdk to an installed SDK." >&2
  exit 1
fi
exec "$flutter_bin" "$@"
