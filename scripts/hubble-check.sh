#!/usr/bin/env bash
set -euo pipefail

echo "== cilium status =="
cilium status

echo

echo "== hubble status =="
hubble status

echo

echo "== simulator -> kafka (9093) =="
hubble observe --from-pod telemetry/exchange-simulator --to-namespace telemetry --protocol tcp --port 9093 --last 20 || true

echo

echo "== suricata/eve-forwarder -> kafka (9093) =="
hubble observe --from-pod telemetry/suricata --to-namespace telemetry --protocol tcp --port 9093 --last 20 || true

echo

echo "== indexer -> opensearch (9200) =="
hubble observe --from-pod telemetry/indexer-worker --to-pod telemetry/opensearch --protocol tcp --port 9200 --last 20 || true

echo

echo "== dropped flows in telemetry =="
hubble observe --namespace telemetry --verdict DROPPED --last 20 || true
