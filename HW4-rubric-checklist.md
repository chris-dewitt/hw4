# DATA 789 · HW4 Rubric — observable checklist (100 pts)

P2-style: every item is a **check you can see**. Grade from submitted **evidence** (manifests +
`kubectl` screenshots + short answers). No live cluster required at grading time.

> Full marks are reachable **locally**; the required Azure step is a checkbox; AKS is bonus.
> Items marked **[auto]** are verified by the in-repo autograder / `hw4-grade_all.sh`; the rest are graded by eye.

Add a short `README.md` (3–5 lines: what you deployed, how to run it, where the evidence is).

---

## A. Deployment & scaling (55 pts)

| ✔ | Check (observable) | Evidence | Pts |
|---|--------------------|----------|-----|
| ☐ | `kubectl get deploy trustbank-fraud` shows **3/3 READY** | screenshot | 8 |
| ☐ | Container has both resource **requests and limits** | `deployment.yaml` | 5 |
| ☐ | **[auto]** limits **right-sized to spec** (CPU `250m`, mem `192Mi`) | `deployment.yaml` | 5 |
| ☐ | **Readiness + liveness** probes configured | `deployment.yaml` + `kubectl describe pod` | 7 |
| ☐ | **[auto]** `owner: <onyen>` label on the Deployment + pods | `deployment.yaml` | 4 |
| ☐ | **Service** `type: LoadBalancer`, `/predict` reachable | `service.yaml` + smoke 200 | 6 |
| ☐ | **[auto]** **HPA tuned to spec** — 40% CPU, `maxReplicas: 8` (real `TARGETS`, not `<unknown>`) | `hpa.yaml` + `kubectl get hpa` | 8 |
| ☐ | **Self-healing** — a pod deleted, Kubernetes recreates it (back to 3/3) | screenshot | 8 |
| ☐ | **Short answers** (3) reasonable | `ANSWERS.md` | 4 |

## B. Zero-downtime update (25 pts)

| ✔ | Check (observable) | Evidence | Pts |
|---|--------------------|----------|-----|
| ☐ | Deployment uses a **rolling strategy** with `maxUnavailable: 0` | `deployment.yaml` | 5 |
| ☐ | **Student-driven rolling update** — image → `:v2` under a live request loop, **0 dropped** | `bash scripts/rolling_update_demo_incluster.sh ghcr.io/rfsalas/trustbank-fraud:v2` output / recording | 12 |
| ☐ | **Blue-green** cutover + rollback (or articulates rolling vs. blue-green) | blue-green demo / 2–3 sentences | 8 |

## C. Azure Container Apps — required (20 pts)

| ✔ | Check (observable) | Evidence | Pts |
|---|--------------------|----------|-----|
| ☐ | Image imported into **ACR** and running on **Container Apps** | portal screenshot | 7 |
| ☐ | **Public `/predict` returns 200** | smoke against the FQDN | 10 |
| ☐ | **Teardown** same day | `az group exists` → false | 3 |

## Bonus (up to +10 pts)

| ✔ | Check | Evidence | Pts |
|---|-------|----------|-----|
| ☐ | Same manifests on **real AKS**; pods/svc/hpa healthy w/ LoadBalancer EXTERNAL-IP | `kubectl get pods,svc,hpa -o wide` | +8 |
| ☐ | AKS torn down same day | portal / CLI | +2 |

---

### Grading notes
- **[auto] items** are checked by the autograder + `hw4-grade_all.sh` (right-sized limits, `owner`
  label, HPA 40%/max 8, valid YAML, 3 replicas, probes, LoadBalancer). A **bare, un-edited template
  intentionally fails the to-spec checks** — students go green as they complete the edits.
- **`<unknown>` HPA target** = metrics-server not enabled → the HPA check fails; the rest can still pass.
- **Dropped requests > 0** usually means readiness isn't gating traffic or `maxUnavailable` isn't 0 —
  deduct the 12-pt demo item, keep partials.
- **Self-healing + short answers are graded by eye**; everything else can be triaged from `grades.csv`
  or the Actions tab.
- Accept **local (Minikube/kind) full marks**; the required Azure step is its own 20 pts; no live cloud
  resources needed at grading — screenshots are the evidence.
