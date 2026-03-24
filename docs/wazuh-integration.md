# Wazuh integration mode

This repository intentionally does **not** embed a full in-cluster Wazuh server/indexer/dashboard deployment.

Reason:
- this lab already uses OpenSearch + OpenSearch Dashboards for event analytics
- a full Wazuh central plane introduces another search / dashboard tier
- in small clusters, that duplication adds cost and operational overlap

Recommended pattern:
- run the provided Wazuh agent DaemonSet in this cluster
- point agents at an external Wazuh manager / server
- correlate cluster telemetry there, while keeping high-volume app / network event search in OpenSearch
