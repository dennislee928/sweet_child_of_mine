#!/usr/bin/env bash
set -euo pipefail

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 2
  }
}

require_cmd cilium
require_cmd hubble

echo "== cilium status =="
cilium status

echo
echo "== hubble status =="
hubble status

check_flow() {
  local name="$1"
  shift
  echo
  echo "== ${name} =="
  local out
  out="$(hubble observe "$@" --last 20 2>/dev/null || true)"
  if [[ -n "${out}" ]]; then
    echo "${out}"
    echo "[PASS] ${name}"
    return 0
  fi
  echo "[FAIL] ${name}"
  return 1
}

fail=0
check_flow "simulator -> kafka (9093)" --from-pod telemetry/exchange-simulator --to-namespace telemetry --protocol tcp --port 9093 || fail=1
check_flow "suricata/eve-forwarder -> kafka (9093)" --from-pod telemetry/suricata --to-namespace telemetry --protocol tcp --port 9093 || fail=1
check_flow "indexer -> opensearch (9200)" --from-pod telemetry/indexer-worker --to-pod telemetry/opensearch --protocol tcp --port 9200 || fail=1
check_flow "dropped flows in telemetry" --namespace telemetry --verdict DROPPED || fail=1

echo
if [[ "${fail}" -eq 0 ]]; then
  echo "HUBBLE_CHECK_RESULT=PASS"
  exit 0
fi

echo "HUBBLE_CHECK_RESULT=FAIL"
exit 1
