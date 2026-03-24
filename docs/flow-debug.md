# Hubble Flow Debug Guide

This guide covers a practical Phase 2 workflow for validating Cilium policy behavior with Hubble.

## Prerequisites

- Cilium installed as CNI
- Hubble Relay enabled
- `cilium` CLI and `hubble` CLI available locally

## Enable Hubble

If Hubble is not enabled yet:

```bash
cilium hubble enable
cilium status --wait
```

For local access to Relay/UI:

```bash
cilium hubble port-forward &
cilium hubble ui &
```

## Health checks

```bash
cilium status
hubble status
```

## Core flow queries

### 1) exchange-simulator -> Kafka

```bash
hubble observe --from-pod telemetry/exchange-simulator --to-namespace telemetry --protocol tcp --port 9093
```

### 2) eve-forwarder -> Kafka

```bash
hubble observe --from-pod telemetry/suricata --to-namespace telemetry --protocol tcp --port 9093
```

### 3) indexer-worker -> OpenSearch

```bash
hubble observe --from-pod telemetry/indexer-worker --to-pod telemetry/opensearch --protocol tcp --port 9200
```

### 4) default-deny verification

```bash
hubble observe --verdict DROPPED --namespace telemetry
```

## Suggested troubleshooting sequence

1. Confirm target pods are Ready.
2. Run the three allow-path queries above and verify `FORWARDED` verdicts.
3. Run the dropped-flow query and confirm expected denies only.
4. If traffic is missing, check policy selectors and namespace labels first.

## Notes

- Suricata runs with `hostNetwork: true`, so some flows may appear with host context.
- For repeatable checks, run these commands while `scripts/smoke.sh` is generating traffic.
