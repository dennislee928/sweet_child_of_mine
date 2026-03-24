#!/usr/bin/env bash
set -euo pipefail

OVERLAY="${OVERLAY:-k8s/overlays/kind}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-exchange-honeynet}"
CREATE_KIND="${CREATE_KIND:-false}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-300s}"
TENANT="${TENANT:-}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

need_cmd kubectl
need_cmd curl
need_cmd nc

if [[ "${CREATE_KIND}" == "true" ]]; then
  need_cmd kind
  kind get clusters | rg -x "${KIND_CLUSTER_NAME}" >/dev/null 2>&1 || kind create cluster --name "${KIND_CLUSTER_NAME}"
fi

echo "[smoke] building overlay ${OVERLAY}"
if [[ -n "${TENANT}" ]]; then
  tenant_slug="$(echo "${TENANT}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')"
  tenant_ns="tenant-${tenant_slug}"
  service_name="exchange-simulator-${tenant_slug}"
  tenant_file="k8s/tenants/${tenant_slug}/rendered.yaml"
  if [[ ! -f "${tenant_file}" ]]; then
    echo "tenant rendered file missing: ${tenant_file}" >&2
    echo "run: make tenant-create TENANT=${tenant_slug}" >&2
    exit 1
  fi
  echo "[smoke] applying tenant manifests ${tenant_file}"
  kubectl apply -f "${tenant_file}"
else
  tenant_ns="telemetry"
  service_name="exchange-simulator"
  if command -v kustomize >/dev/null 2>&1; then
    kustomize build "${OVERLAY}" >/tmp/exchange-honeynet-rendered.yaml
  else
    kubectl kustomize "${OVERLAY}" >/tmp/exchange-honeynet-rendered.yaml
  fi
  echo "[smoke] applying manifests"
  kubectl apply -f /tmp/exchange-honeynet-rendered.yaml
fi

echo "[smoke] waiting for workloads"
kubectl -n "${tenant_ns}" rollout status "deploy/${service_name}" --timeout="${WAIT_TIMEOUT}"
if [[ -z "${TENANT}" ]]; then
  kubectl -n telemetry rollout status deploy/indexer-worker --timeout="${WAIT_TIMEOUT}"
  kubectl -n telemetry rollout status deploy/opensearch-dashboards --timeout="${WAIT_TIMEOUT}"
  kubectl -n telemetry rollout status statefulset/opensearch --timeout="${WAIT_TIMEOUT}"
fi

PF_PID=""
cleanup() {
  if [[ -n "${PF_PID}" ]]; then
    kill "${PF_PID}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

echo "[smoke] port-forward ${service_name}"
kubectl -n "${tenant_ns}" port-forward "svc/${service_name}" 8080:8080 >/tmp/exchange-sim-port-forward.log 2>&1 &
PF_PID=$!
sleep 5

echo "[smoke] send REST order"
curl -sfS -X POST http://127.0.0.1:8080/api/v1/orders \
  -H 'content-type: application/json' \
  -d "{\"symbol\":\"BTC-USD\",\"side\":\"buy\",\"price\":62500.5,\"quantity\":0.2,\"account_id\":\"ACCT-SMOKE-${TENANT:-base}\"}" >/tmp/smoke-order.json

echo "[smoke] open short WS subscription"
python3 - <<'PY'
import asyncio
import json
import sys

try:
    import websockets
except Exception:
    print("websockets package not available, skipping WS assertion")
    sys.exit(0)

async def main():
    uri = "ws://127.0.0.1:8080/ws/market?symbol=BTC-USD"
    async with websockets.connect(uri) as ws:
        msg = await asyncio.wait_for(ws.recv(), timeout=5)
        json.loads(msg)

asyncio.run(main())
PY

echo "[smoke] send pseudo FIX"
printf '8=FIX.4.4|35=A|49=SMOKE|56=SIMEX|34=1|52=20260324-09:30:00.000|98=0|108=30|\n' | nc 127.0.0.1 9878 || true

sleep 8

echo "[smoke] verify KafkaUser secrets exist"
if [[ -n "${TENANT}" ]]; then
  tenant_slug="$(echo "${TENANT}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')"
  kubectl -n telemetry get secret "tenant-${tenant_slug}-simulator-user" >/dev/null
  kubectl -n telemetry get secret "tenant-${tenant_slug}-eve-forwarder-user" >/dev/null
  kubectl -n telemetry get secret "tenant-${tenant_slug}-indexer-user" >/dev/null
else
  kubectl -n telemetry get secret exchange-simulator-user >/dev/null
  kubectl -n telemetry get secret eve-forwarder-user >/dev/null
  kubectl -n telemetry get secret indexer-worker-user >/dev/null
fi

echo "[smoke] verify OpenSearch indexed docs"
if ! kubectl -n telemetry exec deploy/indexer-worker -- python - <<'PY'
import os
from opensearchpy import OpenSearch
url = os.getenv("OPENSEARCH_URL", "https://opensearch.telemetry.svc.cluster.local:9200")
user = os.getenv("OPENSEARCH_USER", "admin")
password = os.getenv("OPENSEARCH_PASSWORD", "")
client = OpenSearch(hosts=[url], http_auth=(user, password), use_ssl=True, verify_certs=False, ssl_show_warn=False)
result = client.cat.indices(index="*-*", format="json")
if not result:
    raise SystemExit(1)
print("indices", len(result))
PY
then
  echo "OpenSearch smoke check failed" >&2
  exit 1
fi

echo "[smoke] PASS"
