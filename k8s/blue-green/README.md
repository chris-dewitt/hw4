# Blue-green rollout (advanced)

This is the Kubernetes-native version of Project 2's Docker-Compose blue-green swap.
It's an **alternative** to the top-level rolling update — apply this folder on a
clean cluster (delete the main `deployment.yaml`/`service.yaml` first, or use a
separate namespace).

## Run it

```bash
# 1. Stand up BOTH colors + the switch Service (starts pointing at blue)
kubectl apply -f k8s/blue-green/

# 2. Watch both come up
kubectl get pods -l app=trustbank-fraud-bg -L color

# 3. Verify GREEN privately before any traffic hits it
kubectl port-forward deploy/trustbank-fraud-green 9000:8000
#   curl the green pod's /predict on localhost:9000 in another terminal

# 4. Cut traffic over to green (instant, atomic)
./scripts/bluegreen_switch.sh green

# 5. Roll back just as fast if green misbehaves
./scripts/bluegreen_switch.sh blue
```

## Blue-green vs. the built-in rolling update

| | Rolling update (`deployment.yaml`) | Blue-green (this folder) |
|---|---|---|
| Mechanism | one Deployment, `maxUnavailable: 0` | two Deployments + a Service selector flip |
| Cutover | gradual, pod by pod | instant, all at once |
| Rollback | `kubectl rollout undo` | flip the selector back |
| Cost | 1× pods (+1 surge) | 2× pods while both colors run |

Demo the **rolling update** for the graded core (zero dropped requests via
`bash scripts/rolling_update_demo_incluster.sh ghcr.io/rfsalas/trustbank-fraud:v2`); show **blue-green** as the "instant cutover +
instant rollback" contrast.
