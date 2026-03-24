#!/usr/bin/env bash
set -euo pipefail

IMAGE_REF="${1:-${IMAGE_REF:-}}"
if [[ -z "${IMAGE_REF}" ]]; then
  echo "Usage: scripts/verify-signed-image.sh <image@sha256:...>" >&2
  exit 1
fi

if [[ "${IMAGE_REF}" != *@sha256:* ]]; then
  echo "image reference must be digest-pinned: ${IMAGE_REF}" >&2
  exit 1
fi

if ! command -v cosign >/dev/null 2>&1; then
  echo "missing command: cosign" >&2
  exit 2
fi

IDENTITY_RE="${COSIGN_CERT_IDENTITY_RE:-https://github.com/.+}"
ISSUER="${COSIGN_CERT_ISSUER:-https://token.actions.githubusercontent.com}"

cosign verify "${IMAGE_REF}" \
  --certificate-identity-regexp "${IDENTITY_RE}" \
  --certificate-oidc-issuer "${ISSUER}"
