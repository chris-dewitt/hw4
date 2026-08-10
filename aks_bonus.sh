#!/usr/bin/env bash
set -euo pipefail
# ─────────────────────────────────────────────────────────────────────────────
# DATA 789 · HW4 BONUS — run the SAME k8s/ manifests on a real AKS cluster.
# One small node, torn down the SAME DAY. The AKS control plane is free; only the
# node costs (a couple of dollars for an afternoon, cents with same-day teardown).
#
# ⚠️  Azure-for-Students has a low vCPU quota. If node creation fails with a quota
#     error, that's EXPECTED — AKS is bonus, not required. Fall back to Minikube
#     (Main / full marks) or the Container Apps floor.
#
# Prereq: run deploy_azure.sh first so the image already lives in your ACR; pass
# that ACR name as $1 so AKS can pull it (AcrPull wired via --attach-acr).
# ─────────────────────────────────────────────────────────────────────────────
source "$(dirname "$0")/config.env"
ACR_NAME="${1:?usage: ./aks_bonus.sh <your-acr-name>   (from deploy_azure.sh output)}"

SUFFIX="$(echo "${USER:-$RANDOM}" | tr -cd 'a-z0-9' | cut -c1-12)"
LOCATION="${LOCATION:-eastus2}"              # default eastus2 (centralus is blocked on Azure for Students); override: export LOCATION=<allowed region>
RG="rg-data789-hw4-aks-${SUFFIX}"
CLUSTER="aks-data789-hw4"

echo "▶ creating resource group: $RG ($LOCATION)"
az group create -n "$RG" -l "$LOCATION" -o none

echo "▶ creating a 1-node AKS cluster (Standard_B2s, within the free B-series hours)…"
az aks create -g "$RG" -n "$CLUSTER" \
  --node-count 1 --node-vm-size Standard_B2s \
  --attach-acr "$ACR_NAME" \
  --generate-ssh-keys -o none

echo "▶ fetching kubeconfig…"
az aks get-credentials -g "$RG" -n "$CLUSTER" --overwrite-existing

echo "▶ applying the SAME manifests you ran locally…"
#   The image in k8s/deployment.yaml must be the ACR ref, not trustbank-fraud:local.
#   Quick override without editing the file:
#     kubectl set image deployment/trustbank-fraud fraud=${ACR_NAME}.azurecr.io/trustbank-fraud:v1
kubectl apply -f k8s/
kubectl rollout status deployment/trustbank-fraud --timeout=180s
kubectl get pods,svc,hpa -o wide

echo
echo "✅ AKS up. Grab the Service EXTERNAL-IP above and screenshot pods/svc/hpa."
echo "   ⚠️  TEAR DOWN SAME DAY:"
echo "      az group delete -n $RG --yes --no-wait"
