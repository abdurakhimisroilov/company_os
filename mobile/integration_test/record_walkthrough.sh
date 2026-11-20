#!/bin/bash
# Usage: DEMO_PASSWORD=... ./record_walkthrough.sh ~/Desktop/out.mp4  (local server on :3000 with the demo seed)
# Runs the walkthrough and records the simulator between REC_START and REC_STOP.
cd ~/StudioProjects/company_os/mobile
DEV=CD655FF8-EE0C-402E-A61D-EBAFDB5E1C6F
OUT="$1"; rm -f "$OUT"
REC=
flutter test integration_test/review_walkthrough_test.dart -d $DEV \
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1 --dart-define=DEMO_PASSWORD="${DEMO_PASSWORD:?set DEMO_PASSWORD}" --dart-define=SKIP_PUSH_PROMPT=true 2>&1 |
while IFS= read -r line; do
  echo "$line"
  case "$line" in
    *REC_START*) xcrun simctl io $DEV recordVideo --codec=h264 --force "$OUT" >/dev/null 2>&1 & REC=$!; echo "[recording pid $REC]";;
    *SNAP*) xcrun simctl io $DEV screenshot /tmp/opero_walkthrough_snap.png >/dev/null 2>&1;;
    *REC_STOP*) [ -n "$REC" ] && kill -INT $REC && wait $REC; echo "[recording saved]";;
  esac
done
pkill -INT -f "recordVideo.*$(basename "$OUT")" 2>/dev/null; sleep 2; true
