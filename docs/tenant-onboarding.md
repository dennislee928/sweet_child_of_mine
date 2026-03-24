# Tenant Onboarding

This repository supports one-command tenant onboarding with rendered manifests.

## Quick start

```bash
make tenant-create TENANT=alpha
kubectl apply -f k8s/tenants/alpha/rendered.yaml
TENANT=alpha bash scripts/smoke.sh
make hubble-check
```

## What `tenant-create` generates

For `TENANT=alpha`, generated file is `k8s/tenants/alpha/rendered.yaml` and includes:

- Namespace `tenant-alpha` with PSA labels (`restricted` enforce/audit/warn)
- Tenant simulator deployment/service (`exchange-simulator-alpha`)
- Tenant Kafka topics:
  - `tenant-alpha.market-events`
  - `tenant-alpha.simulator-audit`
  - `tenant-alpha.suricata-eve`
- Tenant Kafka users and ACLs:
  - `tenant-alpha-simulator-user` (write market/audit)
  - `tenant-alpha-eve-forwarder-user` (write suricata)
  - `tenant-alpha-indexer-user` (read all tenant topics + tenant group)
- Tenant OpenSearch governance ConfigMap:
  - template name
  - alias name
  - ILM policy name

## Production mode

Use digest-pinned image in production generation:

```bash
TENANT=alpha TENANT_ENV=prod SIM_IMAGE=ghcr.io/acme/exchange-simulator@sha256:<digest> \
  bash scripts/tenant-create.sh
```

`TENANT_ENV=prod` rejects mutable image tags.
