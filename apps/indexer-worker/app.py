from __future__ import annotations

import asyncio
import json
import os
from datetime import datetime, timezone

from aiokafka import AIOKafkaConsumer
from opensearchpy import OpenSearch

BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
TOPICS = [t.strip() for t in os.getenv("KAFKA_TOPICS", "market-events,simulator-audit,suricata-eve").split(",") if t.strip()]
OPENSEARCH_URL = os.getenv("OPENSEARCH_URL", "http://localhost:9200")


async def main() -> None:
    consumer = AIOKafkaConsumer(*TOPICS, bootstrap_servers=BOOTSTRAP, enable_auto_commit=True, auto_offset_reset="earliest")
    client = OpenSearch(hosts=[OPENSEARCH_URL])
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
