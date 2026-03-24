# P2 Advanced Controls

## Wazuh central go/no-go checklist

Promote from external-manager mode to in-cluster Wazuh central only when all items are true:

- Capacity: dedicated node pool and storage budget for Wazuh manager/indexer/dashboard
- Ownership: explicit oncall ownership for Wazuh central operations
- Data split: OpenSearch remains primary for simulator/suricata high-volume events
- Retention/SLO: documented retention policy and backup/restore test results
- Alerting model: no duplicate detection loops between Wazuh and OpenSearch detections

If any item is not met, stay in external-manager integration mode.

## Signature verification admission roadmap

Phase A (current)
- Build, scan, and sign images in CI
- Use digest pinning in production overlays

Phase B (enforcement)
- Add signature-verification admission controller (Kyverno or Policy Controller)
- Start in audit mode on selected namespaces
- Promote to enforce after stable release cycles

Policy intent:
- deny unsigned images
- deny signature identity mismatch
- deny mutable tags in production namespaces

## Multi-tenant isolation roadmap

- Copy `k8s/overlays/tenant-template` per tenant
- Assign tenant labels and dedicated namespaces
- Add tenant-specific Cilium policies and egress allowlists
- Optionally split Kafka users/topics by tenant
- Optionally use dedicated node pools for high-risk tenants

Validation targets:
- no cross-tenant east-west traffic without explicit allow
- dropped cross-tenant flows observable in Hubble
