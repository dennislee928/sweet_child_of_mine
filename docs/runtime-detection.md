# Runtime Detection Baseline (Tetragon)

This repo uses a mixed Tetragon baseline to cover runtime behavior after container start.

## Scope

Policies focus on high-signal runtime behavior:

- shell execution in workload namespaces
- suspicious access to sensitive paths
- unexpected outbound socket activity

## Installed manifests

- `k8s/base/tetragon/tetragon-install.yaml`
- `k8s/base/tetragon/policies/simulator-shell-observe.yaml` (enforce via `Sigkill`)
- `k8s/base/tetragon/policies/suspicious-write-observe.yaml`
- `k8s/base/tetragon/policies/unexpected-outbound-observe.yaml` (enforce via `Sigkill`)

## Mode

Mixed mode:

- `simulator-shell-enforce`: enforce (`Sigkill`) for shell execution.
- `unexpected-outbound-enforce`: enforce (`Sigkill`) for socket state events.
- `suspicious-write-observe`: observe-only to avoid high false-positive risk.

Current namespace scope: `tenant-alpha` and `telemetry`.

## Operational checks

```bash
kubectl -n kube-system get pods -l app=tetragon
kubectl -n kube-system logs ds/tetragon --tail=200
```

## Rollback

If enforcement creates false positives, remove `matchActions` from the enforce policies and re-apply:

```bash
kubectl apply -f k8s/base/tetragon/policies/simulator-shell-observe.yaml
kubectl apply -f k8s/base/tetragon/policies/unexpected-outbound-observe.yaml
```

## Diagnostics artifact expectation

CI failure diagnostics should include Tetragon logs and status output along with Cilium/Hubble evidence.
