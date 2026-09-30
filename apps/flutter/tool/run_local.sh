#!/usr/bin/env bash
# Run against the local Go backend. Android emulators use their host bridge.
set -euo pipefail
cd "$(dirname "$0")/.."
api_url="${CAMEO_API_BASE_URL:-http://localhost:18080}"
if [ "${1:-}" = android ]; then
  shift
  api_url="${CAMEO_API_BASE_URL:-http://10.0.2.2:18080}"
fi
exec ./tool/flutter.sh run --dart-define="CAMEO_API_BASE_URL=$api_url" "$@"
