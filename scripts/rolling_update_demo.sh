#!/usr/bin/env bash
set -euo pipefail
# ─────────────────────────────────────────────────────────────────────────────
# The 2-minute graded demo: hammer /predict while rolling the Deployment to a new
# image, and count non-200s. Goal: ZERO dropped requests (maxUnavailable: 0).
#
# Usage: ./scripts/rolling_update_demo.sh <base-url> <new-image-ref>
#   e.g. ./scripts/rolling_update_demo.sh http://localhost:8080 ghcr.io/rfsalas/trustbank-fraud:v2
#
# Note: there is NO Dockerfile in this kit — use the PUBLISHED :v2 tag above; do not try to build it.
# ─────────────────────────────────────────────────────────────────────────────
source "$(dirname "$0")/../config.env"
BASE="${1:?usage: rolling_update_demo.sh <base-url> <new-image-ref>}"
NEW_IMAGE="${2:?provide the new image ref, e.g. trustbank-fraud:v2}"
PAYLOAD="$(dirname "$0")/sample_transaction.json"
STOP="$(mktemp)"

echo "⚠️  QUICK LOOK ONLY — not for graded evidence."
echo "    This script drives load over a port-forward (or other single-target URL). A"
echo "    port-forward binds to ONE pod and dies when that pod is replaced — exactly what"
echo "    a rolling update does — so it can report FALSE drops that are an artifact of the"
echo "    test method, not the deployment. For graded zero-drop evidence use the in-cluster"
echo "    script: ./scripts/rolling_update_demo_incluster.sh <new-image-ref>"
echo

echo "▶ hammering ${BASE}${PREDICT_PATH} … (rollout starts in 3s)"
total=0; ok=0; bad=0
( while [ ! -f "${STOP}.done" ]; do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
           -X POST "${BASE}${PREDICT_PATH}" \
           -H 'Content-Type: application/json' -d @"${PAYLOAD}" || echo 000)
    total=$((total+1)); if [ "$code" = "200" ]; then ok=$((ok+1)); else bad=$((bad+1)); fi
    printf '\r  total=%d  ok=%d  bad=%d ' "$total" "$ok" "$bad"
    sleep 0.2
  done
  echo "$total $ok $bad" > "$STOP"
) &
LOOP=$!

sleep 3
echo; echo "▶ rolling deployment/trustbank-fraud → ${NEW_IMAGE}"
kubectl set image deployment/trustbank-fraud fraud="${NEW_IMAGE}"
kubectl rollout status deployment/trustbank-fraud --timeout=120s
sleep 3

touch "${STOP}.done"; wait "$LOOP" 2>/dev/null || true
read -r T O B < "$STOP"; rm -f "$STOP" "${STOP}.done"
echo; echo "── result ─────────────────────────────"
echo "   requests: ${T}   ok: ${O}   dropped: ${B}"
[ "${B:-1}" = "0" ] && echo "✅ zero-downtime rollout — 0 dropped requests." \
  || echo "⚠️ ${B} dropped — check probes (readiness must gate traffic) and maxUnavailable: 0."
