# Rendered Artifact Strategy

## Source of truth

- **Source of truth**: tenant descriptor inputs and generation script (`scripts/tenant-create.sh`)
- **Generated artifact**: `k8s/tenants/<tenant>/rendered.yaml`

## Rules

- Do not hand-edit `rendered.yaml` files.
- Generate with `make tenant-create TENANT=<name>`.
- `rendered.yaml` is treated as build/deploy artifact; default git ignore is enabled.
- Keep generated files out of source review noise:
  - Python bytecode/cache files (`__pycache__/`, `*.pyc`) must stay untracked.
  - Prefer temporary output (`/tmp`) or CI artifacts for one-off rendered files.
- If a sample rendered file is needed for docs/tests, keep it in a dedicated fixture path and mark clearly as fixture.

## CI implication

- CI validates generated output (`trivy config` + deployment checks), not manual YAML edits.
- Admission negative tests must fail for known-bad manifests.

## Cleanup and recovery

If a rendered tenant file is already tracked, remove it from Git index once:

```bash
git ls-files "k8s/tenants/*/rendered.yaml"
git rm --cached k8s/tenants/*/rendered.yaml
```

Then regenerate locally when needed with `make tenant-create TENANT=<name>`.
