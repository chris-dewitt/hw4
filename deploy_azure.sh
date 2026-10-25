#!/usr/bin/env bash
set -euo pipefail
# ─────────────────────────────────────────────────────────────────────────────
# DATA 789 · HW4 FLOOR (required) — import the provided Project 2 fraud image into
# Azure Container Registry and run it on Azure Container Apps, giving a public URL.
#
# Best run in AZURE CLOUD SHELL (https://shell.azure.com): already signed in, has az.
# The image is pre-built and public, so there's nothing to build — we just import it.
#
# NOTE: this floor runs the API container ALONE (no Redis). /health and /predict both
# work here — /predict scores without customer-history features (the app falls back
# gracefully). The full feature store (Redis) is part of the local-Kubernetes deploy.
#
# Cost: scale-to-zero + same-day teardown ⇒ ~$0 inside the Container Apps free grant.
# Auth: AAD/RBAC only — ACR admin user disabled; the app pulls via a managed identity.
# ─────────────────────────────────────────────────────────────────────────────
source "$(dirname "$0")/config.env"

SUFFIX="$(echo "${USER:-student}" | tr -cd 'a-z0-9' | cut -c1-12)"  # unique-per-student (export USER=<onyen>)
LOCATION="${LOCATION:-eastus2}"               # allowed by the Azure for Students region policy.
                                              # centralus is DISALLOWED there. Override: export LOCATION=<region>.
                                              # Allowed set: eastus2 westus3 northcentralus southcentralus canadacentral
RG="rg-data789-hw4-${SUFFIX}"
ACR_NAME="$(echo "acrdata789hw4${SUFFIX}" | cut -c1-50)"   # 5-50 lower-alnum, globally unique
ENV_NAME="cae-data789-hw4"
APP_NAME="trustbank-fraud"
TAG="v1"

SUB_NAME="$(az account show --query name -o tsv 2>/dev/null)" || { echo 'NOT LOGGED IN — open Azure Cloud Shell, or run: az login'; exit 1; }
echo "▶ subscription : ${SUB_NAME}"
case "$SUB_NAME" in
  *Student*|*student*) : ;;
  *) echo "   ⚠️  This is not an 'Azure for Students' subscription. Cloud Shell often defaults to an"
     echo "      institutional one where you lack rights (AuthorizationFailed). If so, run:"
     echo "        az account set --subscription \"Azure for Students\"   and re-run this script." ;;
esac

# Resolve an allowed region. An explicit `export LOCATION=<region>` wins if the policy allows it.
# Otherwise, if the subscription restricts regions via Azure Policy (common on Azure for Students,
# and the allowed set VARIES per subscription), auto-pick an allowed one so the deploy does not
# fail with RequestDisallowedByAzure.
ALLOWED="$(az policy assignment list --disable-scope-strict-match \
  --query "[?parameters].parameters.listOfAllowedLocations.value[]" -o tsv 2>/dev/null | tr '\t' '\n' | sed '/^[[:space:]]*$/d')"
if [ -n "${ALLOWED}" ] && ! printf '%s\n' "${ALLOWED}" | grep -qx "${LOCATION}"; then
  NEW_LOCATION="$(printf '%s\n' "${ALLOWED}" | head -1)"
  echo "   ⚠️  region '${LOCATION}' is not permitted by your subscription policy."
  echo "      auto-selecting '${NEW_LOCATION}'  (allowed: $(printf '%s ' ${ALLOWED}))"
  echo "      to pick a different allowed region:  export LOCATION=<region>  and re-run."
  LOCATION="${NEW_LOCATION}"
fi
echo "▶ region       : $LOCATION"
echo "▶ source image : $IMAGE"
echo

echo "▶ registering resource providers (idempotent)…"
az provider register -n Microsoft.App --wait
az provider register -n Microsoft.ContainerRegistry --wait
az provider register -n Microsoft.OperationalInsights --wait

echo "▶ creating resource group…"
az group create -n "$RG" -l "$LOCATION" -o none

echo "▶ checking registry name availability…"
if [ "$(az acr check-name -n "$ACR_NAME" --query nameAvailable -o tsv)" = "false" ]; then
  ACR_NAME="$(echo "${ACR_NAME}$(printf '%04x%02x' "$RANDOM" "$((RANDOM % 256))")" | cut -c1-50)"
  echo "   ⚠️  registry name already in use — using '${ACR_NAME}' instead"
fi

echo "▶ creating registry (Basic, admin user disabled — AAD auth only)…"
az acr create -n "$ACR_NAME" -g "$RG" --sku Basic --admin-enabled false -o none

echo "▶ importing the provided public image into your registry (no build, no keys)…"
az acr import -n "$ACR_NAME" -g "$RG" --source "$IMAGE" --image "${APP_NAME}:${TAG}"
FULL_IMAGE="${ACR_NAME}.azurecr.io/${APP_NAME}:${TAG}"

echo "▶ creating Container Apps environment…"
az containerapp env create -n "$ENV_NAME" -g "$RG" -l "$LOCATION" -o none

echo "▶ creating a user-assigned managed identity for ACR pulls…"
# Why a USER-assigned identity (not --registry-identity system): on a fresh Azure for Students
# subscription, the system-identity flow hits a race — the app tries to pull before its AcrPull
# role has propagated, and provisioning fails with 'unable to pull image using Managed identity'.
# Creating the identity + granting AcrPull FIRST (with a propagation wait) makes the pull reliable.
UAMI_NAME="id-${APP_NAME}"
az identity create -n "$UAMI_NAME" -g "$RG" -o none
UAMI_ID="$(az identity show -n "$UAMI_NAME" -g "$RG" --query id -o tsv)"
UAMI_PRINCIPAL="$(az identity show -n "$UAMI_NAME" -g "$RG" --query principalId -o tsv)"
ACR_ID="$(az acr show -n "$ACR_NAME" -g "$RG" --query id -o tsv)"

echo "▶ granting the identity AcrPull and waiting for RBAC to propagate…"
az role assignment create --assignee-object-id "$UAMI_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal --role AcrPull --scope "$ACR_ID" -o none
sleep 90   # AcrPull must be effective BEFORE the app pulls — this avoids the managed-identity race

echo "▶ deploying the container app (user-assigned identity + AcrPull, scale-to-zero)…"
az containerapp create \
  -n "$APP_NAME" -g "$RG" --environment "$ENV_NAME" \
  --image "$FULL_IMAGE" \
  --registry-server "${ACR_NAME}.azurecr.io" \
  --registry-identity "$UAMI_ID" \
  --user-assigned "$UAMI_ID" \
  --target-port "$CONTAINER_PORT" --ingress external \
  --cpu 0.25 --memory 0.5Gi \
  --min-replicas 0 --max-replicas 3 \
  -o none

FQDN="$(az containerapp show -n "$APP_NAME" -g "$RG" \
        --query properties.configuration.ingress.fqdn -o tsv)"

echo
echo "✅ deployed. Your fraud API is live in the cloud — try it:"
echo "      curl https://${FQDN}${HEALTH_PATH}       # → {\"status\":\"ok\"}"
echo "      curl -s -X POST https://${FQDN}${PREDICT_PATH} \\"
echo "        -H 'Content-Type: application/json' \\"
echo "        -d '{\"transaction_id\":\"t1\",\"customer_id\":\"CUST0001\",\"amount\":1500,\"merchant_category\":\"online_retail\",\"is_online\":true,\"timestamp\":\"2026-01-01T00:50:00Z\"}'"
echo "      # → a fraud decision  ← screenshot this"
echo
echo "   ⚠️  capture your screenshot, then TEAR DOWN SAME DAY:"
echo "      ./teardown_azure.sh"
echo
# ── TROUBLESHOOTING ──────────────────────────────────────────────────────────
# Region blocked (RequestDisallowedByAzure)?  export LOCATION=<allowed region> and re-run.
#   Allowed on Azure for Students: eastus2 westus3 northcentralus southcentralus canadacentral
# Wrong subscription (AuthorizationFailed)?    az account set --subscription "Azure for Students"
# Still 'unable to pull with Managed identity'? give RBAC more time, then re-point the image:
#   az containerapp update -n "$APP_NAME" -g "$RG" --image "$FULL_IMAGE"
