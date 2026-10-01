#!/usr/bin/env bash
# Use the deployed API and local sandbox configuration when available.
set -euo pipefail
cd "$(dirname "$0")/.."
args=(--dart-define="CAMEO_API_BASE_URL=https://api.cameo.deltalab.dev")
app_config="${CAMEO_APP_CONFIG:-../../.local/app-sandbox.json}"
if [ -f "$app_config" ]; then
  args+=(--dart-define-from-file="$app_config")
elif [ -n "${CAMEO_APP_CONFIG:-}" ]; then
  echo "CAMEO_APP_CONFIG file not found: $app_config" >&2
  exit 1
fi
exec ./tool/flutter.sh run "${args[@]}" "$@"
