#!/usr/bin/env bash
set -euo pipefail

TENANT_ALLOW="${TENANT_ALLOW:-alpha}"
TENANT_DENY="${TENANT_DENY:-beta}"
KAFKA_BOOTSTRAP="${KAFKA_BOOTSTRAP:-exchange-kafka-kafka-bootstrap.telemetry.svc.cluster.local:9093}"

for cmd in kubectl python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "missing command: $cmd" >&2; exit 2; }
done

tenant_allow_slug="$(echo "${TENANT_ALLOW}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')"
tenant_deny_slug="$(echo "${TENANT_DENY}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')"

alpha_topic="tenant-${tenant_allow_slug}.market-events"
beta_user="tenant-${tenant_deny_slug}-simulator-user"

# Ensure user secret exists (created by Strimzi User Operator)
kubectl -n telemetry get secret "${beta_user}" >/dev/null

beta_password="$(kubectl -n telemetry get secret "${beta_user}" -o jsonpath='{.data.password}' | base64 -d)"
if [[ -z "${beta_password}" ]]; then
  echo "unable to fetch password from secret ${beta_user}" >&2
  exit 1
fi

export KAFKA_BOOTSTRAP
export KAFKA_USERNAME="${beta_user}"
export KAFKA_PASSWORD="${beta_password}"
export KAFKA_DENY_TOPIC="${alpha_topic}"

python3 - <<'PY'
import os
import ssl
from kafka import KafkaProducer

bootstrap = os.environ["KAFKA_BOOTSTRAP"]
username = os.environ["KAFKA_USERNAME"]
password = os.environ["KAFKA_PASSWORD"]
topic = os.environ["KAFKA_DENY_TOPIC"]

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

producer = KafkaProducer(
    bootstrap_servers=bootstrap,
    security_protocol="SASL_SSL",
    sasl_mechanism="SCRAM-SHA-512",
    sasl_plain_username=username,
    sasl_plain_password=password,
    ssl_context=ctx,
)

failed = False
try:
    fut = producer.send(topic, b"cross-tenant-deny-check")
    fut.get(timeout=10)
except Exception:
    failed = True
finally:
    producer.close()

if not failed:
    raise SystemExit("cross-tenant produce unexpectedly succeeded")
print("cross-tenant produce denied as expected")
PY
