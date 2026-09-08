# DATA 789 · HW4 — "Scale It" (Kubernetes)

You already **built** the TrustBank fraud service in Project 2. HW4 is **scale it**: you take the
*working* service and make it production-ready on Kubernetes — highly available, autoscaling,
self-healing, and updatable with zero downtime. You do **not** rebuild the app.

The fraud service is provided as a **pre-built image you pull**:
`ghcr.io/rfsalas/trustbank-fraud:v1` — no Dockerfile, no build.

> The kit ships **baseline** manifests. Part of your job is to **tune them to the assignment spec**
> (right-size limits, add your `owner` label, tune the HPA) — the autograder checks those.

---

## What's in this folder

```
hw4/
├─ config.env                     # image ref, port, paths, REDIS_HOST (scripts read this)
├─ k8s/
│  ├─ deployment.yaml             # 3 replicas · probes · YOU right-size limits + add owner label
│  ├─ service.yaml                # LoadBalancer → the API
│  ├─ redis.yaml                  # Redis feature store (the API reads it on /predict)
│  ├─ hpa.yaml                    # autoscaler · YOU tune target % + max (needs metrics-server)
│  ├─ configmap.yaml              # optional app config (off by default)
│  └─ blue-green/                 # instant-cutover alternative to the rolling update
├─ scripts/
│  ├─ local_up.sh                 # one-shot Minikube bring-up (pulls the image + Redis)
│  ├─ smoke_test.sh               # POST a real transaction to /predict
│  ├─ rolling_update_demo.sh      # the 2-min zero-drop demo
│  ├─ bluegreen_switch.sh         # flip blue↔green
│  └─ sample_transaction.json     # a real /predict body
├─ deploy_azure.sh / teardown_azure.sh   # the required Azure step
├─ aks_bonus.sh                   # bonus: same manifests on real AKS
├─ .devcontainer/                 # ready env: kubectl + az + minikube
├─ .github/workflows/autograde.yml# auto-checks your manifests on every push
├─ GITHUB-QUICKSTART.md           # how to submit via GitHub (no command line)
├─ AZURE-QUICKSTART.md            # Azure for Students: sign up, stay free, tear down
├─ ANSWERS.md                     # the 3 short-answer questions — fill these in
├─ HW4-rubric-checklist.md        # exactly what's graded
└─ README-hw4.md                  # you are here
```

## How the pieces fit

- The **API** answers `GET /health` (used by the probes — **no Redis needed**, so pods go Ready)
  and `POST /predict` (scores a transaction; **reads customer features from Redis**).
- `k8s/redis.yaml` runs a small Redis reachable at the DNS name `redis` (`REDIS_HOST=redis`).
  **No data seeding** — an unknown customer falls back to the built-in scorer, so `/predict` still
  returns a valid result.

---

## Parts 1 and 2 — local Kubernetes (80 points)

> Part 3 on Azure (below) is **required** for the remaining 20 points — it is not optional.

Prereqs: Docker Desktop + Minikube, **or** open the repo in the `.devcontainer` / Codespaces
(kubectl + minikube preinstalled).

**1 — Bring up the baseline:**
```bash
./scripts/local_up.sh          # applies Redis + API + Service + HPA, waits for ready
```

**2 — Make the required edits (from the assignment), then re-apply:**
- `k8s/deployment.yaml` → right-size the CPU/memory **limits**, and add your `owner: <onyen>` label
- `k8s/hpa.yaml` → set the HPA **target %** and **max replicas**
```bash
kubectl apply -f k8s/
kubectl get pods,svc,hpa -o wide   # ← screenshot: 3/3 ready, HPA tuned to spec
```

**3 — Verify /predict:**
```bash
kubectl port-forward svc/trustbank-fraud 8080:80
# in a second terminal:
./scripts/smoke_test.sh http://localhost:8080   # ← screenshot: 200 + fraud decision
```

**4 — Self-healing demo:**
```bash
kubectl delete pod "$(kubectl get pod -l app=trustbank-fraud -o name | head -1)"
kubectl get pods                # ← screenshot: a NEW pod already restoring 3/3
```

**5 — Zero-downtime update + blue-green:**

For the **graded 0-dropped-requests evidence, use the in-cluster demo.** It runs the
request loop from a throwaway pod that hits the Service DNS name (`trustbank-fraud`),
so it follows endpoints as pods are replaced:
```bash
./scripts/rolling_update_demo_incluster.sh ghcr.io/rfsalas/trustbank-fraud:v2
#   → "dropped: 0"  ← screenshot
kubectl apply -f k8s/blue-green/ && ./scripts/bluegreen_switch.sh green
```
> **Do not use `kubectl port-forward` to measure zero-drop.** A port-forward binds to
> **one** pod and dies the instant that pod is replaced — which is exactly what a rolling
> update does. The failed requests you'd see are the tunnel dropping, not the Deployment,
> so they're a false artifact of the test method. The host-based
> `scripts/rolling_update_demo.sh` is fine for a quick look against a stable URL, but the
> in-cluster script above is the one that produces valid graded evidence.

**6 — Answer the 3 questions** in `ANSWERS.md`.

**HPA note:** needs `minikube addons enable metrics-server` (local_up.sh does this); give it a
minute or `kubectl get hpa` shows `<unknown>`.

**HPA shows `<unknown>`? — troubleshoot it:**
1. Enable the metrics pipeline: `minikube addons enable metrics-server` (AKS has it built in).
2. Confirm metrics are flowing: `kubectl top pods` — it should list CPU/memory per pod. If it
   errors or is empty, metrics-server isn't ready yet.
3. Inspect the autoscaler: `kubectl describe hpa trustbank-fraud` — the Events and Conditions
   explain why the target can't be read.
4. The target reads `<unknown>` until the pods actually report metrics. A crash loop (no running
   pod to measure) or a fresh rollout (new pods haven't reported yet) restarts that wait — so
   `<unknown>` right after a change is normal; give it ~1 minute and re-check `kubectl get hpa`.

## Path B · Required — Azure Container Apps

**New to Azure? Read [`AZURE-QUICKSTART.md`](AZURE-QUICKSTART.md) first** — sign-up, staying at ~$0, and one-click teardown.

Easiest in **Azure Cloud Shell** (already signed in). This ships the API to real cloud and gives a
public URL. It runs the API alone (no Redis) — `/predict` still returns a valid score, so you verify
the real cloud endpoint here.
```bash
./deploy_azure.sh                               # imports the image → Container Apps → public URL
curl https://<fqdn>/health                      # → {"status":"ok"}
./scripts/smoke_test.sh https://<fqdn>          # POST /predict → a fraud decision  ← screenshot
./teardown_azure.sh                             # ← DO THIS THE SAME DAY
```
Auth is AAD / managed-identity (no keys); default region `eastus2` (override with `export LOCATION=<allowed region>`).

## Path C · Bonus — real AKS
```bash
./aks_bonus.sh             # 1 node, applies k8s/ (incl. Redis); pulls the public image
# screenshot pods/svc/hpa + the LoadBalancer EXTERNAL-IP, then delete the resource group.
```
Azure-for-Students has a low vCPU quota — if node creation fails on quota, that's expected; AKS is
bonus, so fall back to Minikube or the Container Apps step.

---

## Cost hygiene (non-negotiable)
- Scale-to-zero on Container Apps; 1 small node on AKS.
- Deploy → capture evidence → `az group delete` the **same day**.
- You're graded from **evidence**, not live resources.

## What to submit
See `HW4-rubric-checklist.md`. In short: your **edited** `k8s/` manifests; screenshots of
`kubectl get pods,svc,hpa` (3/3, HPA to spec), a 200 from `/predict`, the **self-healing** recovery,
and the rolling-update demo showing **0 dropped requests**; the Azure step `/predict` 200 + teardown
proof; your `ANSWERS.md`; (bonus) AKS.
