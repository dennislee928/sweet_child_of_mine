from __future__ import annotations

import asyncio
import json
import os
import ssl
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlparse

from aiokafka import AIOKafkaConsumer
from opensearchpy import OpenSearch

BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
TOPICS = [t.strip() for t in os.getenv("KAFKA_TOPICS", "market-events,simulator-audit,suricata-eve").split(",") if t.strip()]
OPENSEARCH_URL = os.getenv("OPENSEARCH_URL", "http://localhost:9200")
OPENSEARCH_USER = os.getenv("OPENSEARCH_USER", "")
OPENSEARCH_PASSWORD = os.getenv("OPENSEARCH_PASSWORD", "")
OPENSEARCH_SSL_VERIFY = os.getenv("OPENSEARCH_SSL_VERIFY", "true").lower() in ("1", "true", "yes")
OPENSEARCH_BOOTSTRAP_TEMPLATE = os.getenv("OPENSEARCH_BOOTSTRAP_TEMPLATE", "true").lower() in ("1", "true", "yes")

DEFAULT_INDEX_TEMPLATE = {
    "index_patterns": ["market-events-*", "simulator-audit-*", "suricata-eve-*"],
    "template": {
        "settings": {
            "index.lifecycle.name": "exchange-honeynet-hot-delete-7d",
            "index.lifecycle.rollover_alias": "exchange-honeynet-events",
            "number_of_shards": 1,
            "number_of_replicas": 0,
        },
        "mappings": {
            "dynamic": True,
            "properties": {
                "@timestamp": {"type": "date"},
                "timestamp": {"type": "date", "ignore_malformed": True},
                "source": {"type": "keyword"},
                "symbol": {"type": "keyword"},
                "event_type": {"type": "keyword"},
            },
        },
    },
    "priority": 200,
}

DEFAULT_ILM_POLICY = {
    "policy": {
        "description": "Delete event indices after 7 days",
        "default_state": "hot",
        "states": [
            {
                "name": "hot",
                "actions": [],
                "transitions": [{"state_name": "delete", "conditions": {"min_index_age": "7d"}}],
            },
            {"name": "delete", "actions": [{"delete": {}}], "transitions": []},
        ],
    }
}


def _consumer_kwargs() -> dict[str, Any]:
    proto = os.getenv("KAFKA_SECURITY_PROTOCOL", "PLAINTEXT").upper()
    kwargs: dict[str, Any] = {
        "bootstrap_servers": BOOTSTRAP,
        "security_protocol": proto,
        "group_id": os.getenv("KAFKA_GROUP_ID", "indexer-worker"),
    }
    if proto in ("SASL_SSL", "SASL_PLAINTEXT"):
        kwargs["sasl_mechanism"] = os.getenv("KAFKA_SASL_MECHANISM", "SCRAM-SHA-512")
        kwargs["sasl_plain_username"] = os.getenv("KAFKA_SASL_USERNAME", "")
        kwargs["sasl_plain_password"] = os.getenv("KAFKA_SASL_PASSWORD", "")
    ca = os.getenv("KAFKA_SSL_CA_LOCATION", "").strip()
    if proto == "SASL_SSL" and ca:
        kwargs["ssl_context"] = ssl.create_default_context(cafile=ca)
    return kwargs


def _opensearch_client() -> OpenSearch:
    parsed = urlparse(OPENSEARCH_URL)
    if not parsed.hostname:
        raise ValueError("OPENSEARCH_URL must include a host")
    scheme = (parsed.scheme or "http").lower()
    port = parsed.port or (443 if scheme == "https" else 9200)
    auth = None
    if OPENSEARCH_USER:
        auth = (OPENSEARCH_USER, OPENSEARCH_PASSWORD)
    use_ssl = scheme == "https"
    return OpenSearch(
        hosts=[{"host": parsed.hostname, "port": port, "scheme": scheme}],
        http_auth=auth,
        use_ssl=use_ssl,
        verify_certs=OPENSEARCH_SSL_VERIFY if use_ssl else False,
        ssl_show_warn=False,
    )


def _bootstrap_opensearch(client: OpenSearch) -> None:
    if not OPENSEARCH_BOOTSTRAP_TEMPLATE:
        return
    # Best-effort bootstrap to keep startup resilient in constrained lab environments.
    try:
        client.transport.perform_request(
            method="PUT",
            url="/_plugins/_ism/policies/exchange-honeynet-hot-delete-7d",
            body=DEFAULT_ILM_POLICY,
        )
    except Exception:
        pass
    try:
        client.transport.perform_request(
            method="PUT",
            url="/_index_template/exchange-honeynet-events",
            body=DEFAULT_INDEX_TEMPLATE,
        )
    except Exception:
        pass


async def main() -> None:
    consumer = AIOKafkaConsumer(
        *TOPICS,
        enable_auto_commit=True,
        auto_offset_reset="earliest",
        **_consumer_kwargs(),
    )
    client = _opensearch_client()
    _bootstrap_opensearch(client)
    await consumer.start()
    try:
        async for msg in consumer:
            try:
                payload = json.loads(msg.value.decode("utf-8"))
            except Exception:
                continue
            idx_date = datetime.now(timezone.utc).strftime("%Y.%m.%d")
            index_name = f"{msg.topic}-{idx_date}".lower()
            client.index(index=index_name, body=payload)
    finally:
        await consumer.stop()


if __name__ == "__main__":
    asyncio.run(main())
