# Architecture notes

## Design goals

- Deception-friendly exchange / market-data simulation
- Clear telemetry path from app events and packet inspection into a searchable backend
- Kubernetes-native segmentation using Cilium policies
- Kafka as the event spine, not as the analytics engine
- Optional Wazuh integration without forcing a second overlapping full stack into the same tiny lab

## Data flows

1. Clients hit REST / WebSocket / FIX mock endpoints on the exchange simulator.
2. The simulator emits JSON audit and market events to Kafka.
3. Suricata inspects traffic and writes EVE JSON.
4. The sidecar reads EVE JSON and publishes it to Kafka.
5. The indexer worker consumes Kafka topics and writes documents to OpenSearch.
6. Analysts use OpenSearch Dashboards for views, searches, and detections.
7. Optional Wazuh agents forward host/workload telemetry to an external Wazuh manager.

## Kubernetes layout (base manifests)

- **Namespace `telemetry`**: Strimzi Kafka, OpenSearch / Dashboards, indexer-worker, exchange-simulator, and Suricata (so Strimzi-generated Secrets `exchange-app` and `exchange-kafka-cluster-ca-cert` can be mounted without cross-namespace copies).
- **Namespace `exchange-sim`**: reserved / unused in the default overlay; you can repurpose it for stricter isolation with a secret-sync or External Secrets workflow.
- **Namespace `security`**: reserved for future policies or agents; Suricata was moved to `telemetry` for Kafka credentials.
- **Kafka**: internal TLS listener on **9093** with **SCRAM-SHA-512** and simple ACLs on the `exchange-app` user.
- **OpenSearch**: security plugin enabled with init-generated dev certificates; HTTPS on port 9200; Dashboards and indexer use the admin password Secret (replace in non-lab environments).
