#!/usr/bin/env bash
set -euo pipefail

manifest="${1:-/tmp/exchange-honeynet-rendered.yaml}"
if [[ ! -f "${manifest}" ]]; then
  echo "manifest not found: ${manifest}" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "missing command: python3" >&2
  exit 2
fi

python3 - <<'PY' "${manifest}" > /tmp/deploy-images-to-verify.txt
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding='utf-8', errors='ignore')
images = sorted(set(re.findall(r'^\s*image:\s*([^\s]+)\s*$', text, flags=re.M)))
for img in images:
    if '@sha256:' in img:
        print(img)
PY

if [[ ! -s /tmp/deploy-images-to-verify.txt ]]; then
  echo "no digest-pinned images found in ${manifest}; nothing to verify"
  exit 0
fi

while IFS= read -r image; do
  echo "Verifying ${image}"
  bash scripts/verify-signed-image.sh "${image}"
done < /tmp/deploy-images-to-verify.txt
