#!/usr/bin/env bash
set -euo pipefail

if ! command -v helm >/dev/null 2>&1; then
  echo "missing command: helm" >&2
  exit 2
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "missing command: kubectl" >&2
  exit 2
fi

release="${SIGSTORE_RELEASE_NAME:-policy-controller}"
namespace="${SIGSTORE_NAMESPACE:-cosign-system}"
chart_version="${SIGSTORE_POLICY_CONTROLLER_VERSION:-0.10.0}"

helm repo add sigstore https://sigstore.github.io/helm-charts >/dev/null
helm repo update >/dev/null

kubectl create namespace "${namespace}" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install "${release}" sigstore/policy-controller \
  --namespace "${namespace}" \
  --version "${chart_version}" \
  --wait \
  --timeout 5m

kubectl wait --namespace "${namespace}" \
  --for=condition=Available deployment/"${release}-webhook" \
  --timeout=180s

echo "Sigstore policy-controller ready in namespace ${namespace}"
