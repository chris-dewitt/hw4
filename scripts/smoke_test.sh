#!/usr/bin/env bash
set -euo pipefail
# Smoke-test the fraud API's /predict endpoint.
# Usage: ./scripts/smoke_test.sh <base-url>
#   local:  ./scripts/smoke_test.sh http://localhost:8080
#   azure:  ./scripts/smoke_test.sh https://<your-aca-fqdn>
source "$(dirname "$0")/../config.env"
BASE="${1:?usage: smoke_test.sh <base-url>   e.g. http://localhost:8080}"
PAYLOAD="$(dirname "$0")/sample_transaction.json"
RESP="$(mktemp)"
trap 'rm -f "$RESP"' EXIT

echo "▶ POST ${BASE}${PREDICT_PATH}"
HTTP_CODE=$(curl -sS -o "$RESP" -w '%{http_code}' \
  -X POST "${BASE}${PREDICT_PATH}" \
  -H 'Content-Type: application/json' \
  -d @"${PAYLOAD}")
echo "  HTTP ${HTTP_CODE}"
echo "  response:"; cat "$RESP"; echo
[ "$HTTP_CODE" = "200" ] && echo "✅ /predict returned 200" \
  || { echo "❌ non-200 — check the payload schema (copy a real one from P2 tests/) and CONTAINER_PORT/PREDICT_PATH in config.env"; exit 1; }
