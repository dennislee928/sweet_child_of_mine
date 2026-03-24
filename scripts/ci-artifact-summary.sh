#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-/tmp/diag}"
SUMMARY_FILE="${OUT_DIR}/summary.md"

mkdir -p "${OUT_DIR}"

{
  echo "# CI Diagnostics One-Page Summary"
  echo
  echo "Generated at: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo

  echo "## Top failing pods"
  if command -v kubectl >/dev/null 2>&1; then
    top_failed="$(kubectl get pods -A --no-headers 2>/dev/null | awk '$4!="Running" && $4!="Completed" {printf "- %s/%s status=%s ready=%s restarts=%s\\n", $1, $2, $4, $3, $5}' | head -n 20 || true)"
    if [[ -n "${top_failed}" ]]; then
      echo "${top_failed}"
    else
      echo "- No non-running pods detected."
    fi
  else
    echo "- kubectl not available"
  fi
  echo

  echo "## Top restart count pods"
  restart_lines=""
  if command -v kubectl >/dev/null 2>&1; then
    restart_lines="$(
      kubectl get pods -A --no-headers 2>/dev/null \
        | awk '{print $1" "$2" "$3" "$4" "$5}' \
        | sort -k5,5nr \
        | head -n 20 \
        | awk '{printf "- %s/%s restarts=%s status=%s ready=%s\n", $1, $2, $5, $4, $3}'
    )" || true
  fi
  if [[ -n "${restart_lines}" ]]; then
    echo "${restart_lines}"
  else
    echo "- No restart data available."
  fi
  echo

  echo "## Recent drop events"
  drop_lines=""
  if command -v hubble >/dev/null 2>&1; then
    drop_lines="$(hubble observe --verdict DROPPED --last 20 2>/dev/null | sed 's/^/- /' || true)"
  fi
  if [[ -z "${drop_lines}" && -f "${OUT_DIR}/events-all.txt" ]]; then
    drop_lines="$(rg -i 'drop|den(y|ied)|reject|forbidden' "${OUT_DIR}/events-all.txt" -n -m 20 | sed 's/^/- /' || true)"
  fi
  if [[ -n "${drop_lines}" ]]; then
    echo "${drop_lines}"
  else
    echo "- No dropped-flow/event entries detected from available sources."
  fi
  echo

  echo "## Recent 20 policy deny raw lines"
  deny_raw=""
  if [[ -f "${OUT_DIR}/events-all.txt" ]]; then
    deny_raw="$(rg -i 'policy|deny|denied|forbidden|dropped' "${OUT_DIR}/events-all.txt" -n -m 20 || true)"
  fi
  if [[ -n "${deny_raw}" ]]; then
    echo '```text'
    echo "${deny_raw}"
    echo '```'
  else
    echo "- No deny-related raw event lines found in events-all.txt."
  fi
  echo

  echo "## Policy object count"
  np_count="0"
  cnp_count="0"
  if command -v kubectl >/dev/null 2>&1; then
    np_count="$(kubectl get networkpolicies -A -o name 2>/dev/null | wc -l | xargs || true)"
    cnp_count="$(kubectl get ciliumnetworkpolicies -A -o name 2>/dev/null | wc -l | xargs || true)"
    np_count="${np_count:-0}"
    cnp_count="${cnp_count:-0}"
  fi
  echo "- Kubernetes NetworkPolicy: ${np_count}"
  echo "- CiliumNetworkPolicy: ${cnp_count}"
  echo

  echo "## Artifacts included"
  echo "- pods-all.txt"
  echo "- events-all.txt"
  echo "- network-policies.yaml"
  echo "- cilium-network-policies.yaml"
  echo "- cilium-status.txt (if available)"
  echo "- cilium-endpoints.txt (if available)"
  echo "- cilium.log (if available)"
  echo "- hubble-relay.log (if available)"
} > "${SUMMARY_FILE}"

echo "Wrote ${SUMMARY_FILE}"
