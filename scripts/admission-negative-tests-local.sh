#!/usr/bin/env bash
set -euo pipefail

for f in \
  tests/policy/deny-privileged.yaml \
  tests/policy/deny-latest.yaml \
  tests/policy/deny-no-limits.yaml \
  tests/policy/deny-no-readonly-rootfs.yaml \
  tests/policy/deny-allow-priv-esc.yaml \
  tests/policy/deny-unsigned-image.yaml; do
  echo "[admission-negative] expect deny: ${f}"
  if kubectl apply --dry-run=server -f "${f}"; then
    echo "ERROR: ${f} was not denied" >&2
    exit 1
  fi
done

echo "[admission-negative] PASS"
