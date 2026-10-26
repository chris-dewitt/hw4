#!/usr/bin/env bash
set -euo pipefail
# ─────────────────────────────────────────────────────────────────────────────
# DATA 789 · HW4 — tear down the FLOOR deploy. Deletes the whole resource group
# (container app, environment, registry, and Log Analytics workspace) in one shot.
# Run this the SAME DAY you deploy — it's the single most important cost-hygiene step.
# ─────────────────────────────────────────────────────────────────────────────
SUFFIX="$(echo "${USER:-student}" | tr -cd 'a-z0-9' | cut -c1-12)"
RG="${1:-rg-data789-hw4-${SUFFIX}}"          # override: ./teardown_azure.sh <resource-group>

echo "▶ deleting resource group: $RG"
echo "  (removes the app, environment, registry, and workspace)"
az group delete -n "$RG" --yes --no-wait
echo
echo 'Deletion runs in the background and can take up to ~30 minutes. Re-run `az group exists -n <rg>` until it prints false — screenshot that (it is graded) — and do not redeploy until it does.'
echo "      az group exists -n $RG      # should print: false"
