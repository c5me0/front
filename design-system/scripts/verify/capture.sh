#!/usr/bin/env bash
# Capture the dedicated app simulator without synthesizing desktop input. Usage: capture.sh flutter <route> <output.png|output.mp4> [seconds] [--video].
#   capture.sh rn|flutter <route> <out.png> [waitSec=6]
#   capture.sh rn|flutter <route> <out.mp4> [recordSec=8] --video
set -euo pipefail
PLATFORM=$1; ROUTE=$2; OUT=$3; T=${4:-}; MODE=${5:-}
if [ "${CAMEO_SIM:-}" = legacy ]; then
  RN_SIM=3FE7E214-A5EA-4FDF-B188-2CAA0F6E5FEE
  FL_SIM=78599B42-80DD-4698-8A00-32D4D66A84EC
else
  RN_SIM=00AE6EDF-1978-4576-B4A3-09EE21521169
  FL_SIM=FF8AFE2C-EE84-4778-91A4-3396205D26FD
fi
mkdir -p "$(dirname "$OUT")"
case "$PLATFORM" in
  rn) U=$RN_SIM; BUNDLE=host.exp.Exponent ;;
  flutter) U=$FL_SIM; BUNDLE=com.cameo.cameo ;;
  *) echo "platform must be rn|flutter" >&2; exit 2 ;;
esac
xcrun simctl status_bar "$U" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100 >/dev/null 2>&1 || true
xcrun simctl terminate "$U" "$BUNDLE" >/dev/null 2>&1 || true
REC_PID=""
if [ "$MODE" = "--video" ]; then
  xcrun simctl io "$U" recordVideo --codec h264 --force "$OUT" >/dev/null 2>&1 &
  REC_PID=$!
  perl -e 'select(undef,undef,undef,0.8)'
fi
if [ "$PLATFORM" = rn ]; then
  xcrun simctl launch "$U" "$BUNDLE" --initialUrl "exp://127.0.0.1:8081/--${ROUTE}" >/dev/null
else
  SIMCTL_CHILD_CAMEO_ROUTE="$ROUTE" xcrun simctl launch "$U" "$BUNDLE" >/dev/null
fi
if [ -n "$REC_PID" ]; then
  perl -e "select(undef,undef,undef,${T:-8})"
  kill -INT "$REC_PID"; wait "$REC_PID" 2>/dev/null || true
else
  perl -e "select(undef,undef,undef,${T:-6})"
  xcrun simctl io "$U" screenshot --type=png "$OUT" >/dev/null
fi
echo "$OUT"
