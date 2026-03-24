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
