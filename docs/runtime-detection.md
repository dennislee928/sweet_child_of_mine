# Runtime Detection Baseline (Tetragon)

This repo uses an observe-only Tetragon baseline to cover runtime behavior after container start.

## Scope

Policies focus on high-signal runtime behavior:

- shell execution in workload namespaces
- suspicious access to sensitive paths
- unexpected outbound socket activity

## Installed manifests

- `k8s/base/tetragon/tetragon-install.yaml`
- `k8s/base/tetragon/policies/simulator-shell-observe.yaml`
- `k8s/base/tetragon/policies/suspicious-write-observe.yaml`
- `k8s/base/tetragon/policies/unexpected-outbound-observe.yaml`

## Mode

Observe-only.
No process kill/enforcement in this stage.

## Operational checks

```bash
kubectl -n kube-system get pods -l app=tetragon
kubectl -n kube-system logs ds/tetragon --tail=200
```

## Diagnostics artifact expectation

CI failure diagnostics should include Tetragon logs and status output along with Cilium/Hubble evidence.
