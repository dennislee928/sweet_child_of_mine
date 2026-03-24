#!/usr/bin/env bash
set -euo pipefail

kubectl apply -f k8s/base/sigstore/cluster-image-policy.yaml
echo "Applied ClusterImagePolicy github-actions-keyless"
