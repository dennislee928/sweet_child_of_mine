#!/usr/bin/env bash
set -euo pipefail

# Default overlay keeps placeholder images; set OVERLAY or edit k8s/overlays/my-registry.
OVERLAY="${OVERLAY:-k8s/overlays/my-registry}"

manifest_file="/tmp/deploy-rendered.yaml"
if command -v kustomize >/dev/null 2>&1; then
  kustomize build "$OVERLAY" > "$manifest_file"
else
  kubectl kustomize "$OVERLAY" > "$manifest_file"
fi

if [[ "${VERIFY_SIGNATURES:-false}" == "true" ]]; then
  bash scripts/verify-deploy-images.sh "$manifest_file"
fi

kubectl apply -f "$manifest_file"

echo "Applied kustomize overlay: $OVERLAY"
