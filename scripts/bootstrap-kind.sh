#!/usr/bin/env bash
set -euo pipefail

cat <<'MSG'
This script documents a minimal local flow.

1. Create a kind cluster.
2. Install Cilium as the CNI.
3. Install the Strimzi operator.
4. Build and load images.
5. Run scripts/deploy.sh.

Example:
  kind create cluster --name exchange-honeynet --config - <<EOF
  kind: Cluster
  apiVersion: kind.x-k8s.io/v1alpha4
  nodes:
    - role: control-plane
    - role: worker
  EOF

Then install Cilium and Strimzi using their official instructions for your current versions.
MSG
