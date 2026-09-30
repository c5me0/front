#!/usr/bin/env bash
# Record and validate the complete app flow on the dedicated simulator. Preserve failed recordings for diagnosis and reject incomplete step sequences.
#   flowrec.sh rn|flutter <outprefix> <sec> [route='/?demo=flow']
set -u
P=$1; OUT=$2; SEC=$3; ROUTE=${4:-/?demo=flow}
if [ "${CAMEO_SIM:-}" = legacy ]; then RN_SIM=3FE7E214-A5EA-4FDF-B188-2CAA0F6E5FEE; FL_SIM=78599B42-80DD-4698-8A00-32D4D66A84EC
else RN_SIM=00AE6EDF-1978-4576-B4A3-09EE21521169; FL_SIM=FF8AFE2C-EE84-4778-91A4-3396205D26FD; fi
if [ "$P" = rn ]; then U=$RN_SIM; B=host.exp.Exponent; L=/private/tmp/cameo-simulator/cameo-rn-sim.lock
else U=$FL_SIM; B=com.cameo.cameo; L=/private/tmp/cameo-simulator/cameo-fl-sim.lock; fi
mkdir -p "$(dirname "$OUT")" /private/tmp/cameo-simulator
if ! mkdir "$L" 2>/dev/null; then echo "simulator locked: $L" >&2; exit 3; fi
trap 'rmdir "$L"' EXIT
xcrun simctl spawn "$U" log stream --style compact --predicate 'composedMessage CONTAINS "[cameo]" OR composedMessage CONTAINS "Unhandled" OR composedMessage CONTAINS "abort"' > "$OUT-log.txt" 2>&1 &
LP=$!
sleep 1
xcrun simctl status_bar "$U" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 >/dev/null 2>&1 || true
xcrun simctl terminate "$U" "$B" >/dev/null 2>&1 || true
xcrun simctl io "$U" recordVideo --codec h264 --force "$OUT.mp4" 2> >(perl -MTime::HiRes=time -ne '$|=1; printf "%.3f %s", time, $_' > "$OUT-rec.txt") &
RP=$!
perl -e 'select(undef,undef,undef,0.8)'
if [ "$P" = rn ]; then xcrun simctl launch "$U" "$B" --initialUrl "exp://127.0.0.1:8081/--$ROUTE" >/dev/null
else SIMCTL_CHILD_CAMEO_ROUTE="$ROUTE" xcrun simctl launch "$U" "$B" >/dev/null; fi
perl -e "select(undef,undef,undef,$SEC)"
kill -INT $RP; wait $RP 2>/dev/null
sleep 1; kill $LP 2>/dev/null; wait $LP 2>/dev/null
python3 "$(dirname "$0")/check-flow-log.py" "$OUT-log.txt"
