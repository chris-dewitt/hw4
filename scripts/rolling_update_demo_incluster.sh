#!/usr/bin/env bash
set -euo pipefail
# ─────────────────────────────────────────────────────────────────────────────
# The graded zero-drop demo — measured from INSIDE the cluster.
#
# Same idea as rolling_update_demo.sh (hammer /predict while rolling the image and
# count non-200s), but the request loop runs from a throwaway pod that hits the
# Service DNS name (trustbank-fraud), NOT a host port-forward.
#
# Why: `kubectl port-forward` binds to ONE pod and dies the moment that pod is
# replaced — which is exactly what a rolling update does. Requests then fail
# because the tunnel dropped, not because the Deployment dropped them. That is a
# false negative, an artifact of the test method. Hitting the Service follows the
# endpoint list as pods come and go, so this measures the deployment itself.
# Use THIS script for the graded "0 dropped requests" evidence.
#
# Usage: ./scripts/rolling_update_demo_incluster.sh <new-image-ref>
#   e.g. ./scripts/rolling_update_demo_incluster.sh ghcr.io/rfsalas/trustbank-fraud:v2
#
# Note: there is NO Dockerfile in this kit — use the PUBLISHED :v2 tag above; do not build it.
# ─────────────────────────────────────────────────────────────────────────────
source "$(dirname "$0")/../config.env"
NEW_IMAGE="${1:?usage: rolling_update_demo_incluster.sh <new-image-ref>   e.g. ghcr.io/rfsalas/trustbank-fraud:v2}"
SVC="trustbank-fraud"                                  # in-cluster Service DNS name (k8s/service.yaml)
POD="rollout-load-$$"
PAYLOAD="$(cat "$(dirname "$0")/sample_transaction.json")"

cleanup() { kubectl delete pod "$POD" --ignore-not-found --now >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "▶ starting in-cluster load pod → http://${SVC}${PREDICT_PATH} (0.2s cadence)"
# A small throwaway curl pod runs the loop until we drop a /tmp/stop file into it.
kubectl run "$POD" --image=curlimages/curl:latest --restart=Never \
  --env="SVC=${SVC}" --env="PREDICT_PATH=${PREDICT_PATH}" --env="PAYLOAD=${PAYLOAD}" \
  --command -- sh -c '
    total=0; ok=0; bad=0
    while [ ! -f /tmp/stop ]; do
      code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
             -X POST "http://${SVC}:80${PREDICT_PATH}" \
             -H "Content-Type: application/json" -d "${PAYLOAD}" || echo 000)
      total=$((total+1)); if [ "$code" = "200" ]; then ok=$((ok+1)); else bad=$((bad+1)); fi
      sleep 0.2
    done
    echo "RESULT ${total} ${ok} ${bad}"
  '

echo "▶ waiting for the load pod to be Ready…"
kubectl wait --for=condition=Ready "pod/${POD}" --timeout=60s

sleep 3
echo "▶ rolling deployment/trustbank-fraud → ${NEW_IMAGE}"
kubectl set image deployment/trustbank-fraud fraud="${NEW_IMAGE}"
kubectl rollout status deployment/trustbank-fraud --timeout=120s
sleep 3

echo "▶ stopping the load loop…"
kubectl exec "${POD}" -- touch /tmp/stop
# Let the container finish its final iteration and flush the RESULT line.
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded "pod/${POD}" --timeout=30s >/dev/null 2>&1 || sleep 3
read -r _ T O B < <(kubectl logs "${POD}" | grep '^RESULT ')

echo; echo "── result ─────────────────────────────"
echo "   requests: ${T}   ok: ${O}   dropped: ${B}"
[ "${B:-1}" = "0" ] && echo "✅ zero-downtime rollout — 0 dropped requests." \
  || echo "⚠️ ${B} dropped — check probes (readiness must gate traffic), the preStop drain, and maxUnavailable: 0."
