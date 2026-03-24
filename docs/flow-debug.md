# Hubble Flow Debug Guide

This guide provides a repeatable runtime validation flow for Cilium + Hubble.

## Prerequisites

- Cilium installed as CNI
- Hubble Relay enabled
- `cilium` CLI and `hubble` CLI available locally
- target workloads deployed in namespace `telemetry`

## Repeatable commands

### Enable Hubble

```bash
make hubble-enable
```

### Check health

```bash
make hubble-status
```

### Observe core flows

```bash
make flow-observe
```

### Enforced pass/fail verification

```bash
make hubble-check
```

The command returns non-zero if any required flow is missing.

## Expected acceptance criteria

- exchange-simulator -> kafka (`tcp/9093`) is visible
- eve-forwarder/suricata -> kafka (`tcp/9093`) is visible
- indexer-worker -> opensearch (`tcp/9200`) is visible
- dropped flow records (`verdict DROPPED`) are visible

## Troubleshooting

1. Run `make smoke OVERLAY=k8s/overlays/kind` to generate traffic.
2. Confirm pods are Ready in `telemetry`.
3. Check Cilium/Hubble status again.
4. Verify network policy selectors and namespace labels.

## Notes

- Suricata uses `hostNetwork: true`, so some records may appear from host context.
- If the cluster has low traffic, run smoke first to avoid empty flow windows.
