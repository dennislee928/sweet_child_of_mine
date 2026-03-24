#!/usr/bin/env bash
set -euo pipefail

ns="${TETRAGON_TEST_NS:-tenant-alpha}"
selector="${TETRAGON_TEST_SELECTOR:-app=exchange-simulator-alpha}"

pod="$(kubectl -n "${ns}" get pods -l "${selector}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "${pod}" ]]; then
  echo "no pod found for ${selector} in namespace ${ns}" >&2
  exit 1
fi

echo "[tetragon-enforce] trigger shell exec on ${ns}/${pod}"
kubectl -n "${ns}" exec "${pod}" -- /bin/sh -c 'echo tetragon-shell-test' >/tmp/tetragon-shell-test.out 2>&1 || true

echo "[tetragon-enforce] trigger outbound connect on ${ns}/${pod}"
kubectl -n "${ns}" exec "${pod}" -- python -c "import socket; socket.create_connection(('1.1.1.1', 443), 2)" >/tmp/tetragon-outbound-test.out 2>&1 || true

sleep 3
tetragon_pod="$(kubectl -n kube-system get pods -l app=tetragon -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "${tetragon_pod}" ]]; then
  echo "tetragon pod not found" >&2
  exit 1
fi

logs="$(kubectl -n kube-system logs "${tetragon_pod}" --tail=800 || true)"
if [[ "${logs}" != *"simulator-shell-enforce"* ]]; then
  echo "missing simulator-shell-enforce event in tetragon logs" >&2
  exit 1
fi
if [[ "${logs}" != *"unexpected-outbound-enforce"* ]]; then
  echo "missing unexpected-outbound-enforce event in tetragon logs" >&2
  exit 1
fi

echo "[tetragon-enforce] PASS"
