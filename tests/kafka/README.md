# Kafka isolation tests

This directory documents cross-tenant Kafka authorization checks.

- `scripts/kafka-cross-tenant-deny.sh` verifies that tenant beta credentials cannot produce to tenant alpha topic.
- Intended usage in CI after generating and applying tenant manifests for alpha and beta.
