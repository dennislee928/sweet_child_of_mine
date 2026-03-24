#!/usr/bin/env bash
set -euo pipefail

OPENSEARCH_URL="${OPENSEARCH_URL:-https://127.0.0.1:9200}"
OPENSEARCH_USER="${OPENSEARCH_USER:-admin}"
OPENSEARCH_PASSWORD="${OPENSEARCH_PASSWORD:-}"
VERIFY_TLS="${VERIFY_TLS:-false}"

if [[ -z "${OPENSEARCH_PASSWORD}" ]]; then
  echo "OPENSEARCH_PASSWORD is required" >&2
  exit 1
fi

curl_opts=(-sS -u "${OPENSEARCH_USER}:${OPENSEARCH_PASSWORD}" -H "content-type: application/json")
if [[ "${VERIFY_TLS}" != "true" ]]; then
  curl_opts+=( -k )
fi

echo "Applying ILM policy..."
curl "${curl_opts[@]}" -X PUT "${OPENSEARCH_URL}/_plugins/_ism/policies/exchange-honeynet-hot-delete-7d" \
  --data-binary @k8s/base/opensearch/templates/ilm-policy.json >/tmp/opensearch-ilm-bootstrap.json

echo "Applying index template..."
curl "${curl_opts[@]}" -X PUT "${OPENSEARCH_URL}/_index_template/exchange-honeynet-events" \
  --data-binary @k8s/base/opensearch/templates/index-template.json >/tmp/opensearch-template-bootstrap.json

echo "Bootstrap complete."
