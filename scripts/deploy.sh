#!/usr/bin/env bash
set -euo pipefail

# Default overlay keeps placeholder images; set OVERLAY or edit k8s/overlays/my-registry.
OVERLAY="${OVERLAY:-k8s/overlays/my-registry}"

kubectl apply -k "$OVERLAY"

echo "Applied kustomize overlay: $OVERLAY"
