from __future__ import annotations

import asyncio
import json
import os
import ssl
from pathlib import Path
from typing import Any

from aiokafka import AIOKafkaProducer

EVE_FILE = os.getenv("EVE_FILE", "/var/log/suricata/eve.json")
BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
TOPIC = os.getenv("KAFKA_TOPIC", "suricata-eve")


def _producer_kwargs() -> dict[str, Any]:
    proto = os.getenv("KAFKA_SECURITY_PROTOCOL", "PLAINTEXT").upper()
    kwargs: dict[str, Any] = {
        "bootstrap_servers": BOOTSTRAP,
        "security_protocol": proto,
    }
    if proto in ("SASL_SSL", "SASL_PLAINTEXT"):
        kwargs["sasl_mechanism"] = os.getenv("KAFKA_SASL_MECHANISM", "SCRAM-SHA-512")
        kwargs["sasl_plain_username"] = os.getenv("KAFKA_SASL_USERNAME", "")
        kwargs["sasl_plain_password"] = os.getenv("KAFKA_SASL_PASSWORD", "")
    ca = os.getenv("KAFKA_SSL_CA_LOCATION", "").strip()
    if proto == "SASL_SSL" and ca:
        kwargs["ssl_context"] = ssl.create_default_context(cafile=ca)
    return kwargs


async def tail_and_forward() -> None:
    producer = AIOKafkaProducer(**_producer_kwargs())
    await producer.start()
    try:
        path = Path(EVE_FILE)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.touch(exist_ok=True)
        with path.open("r", encoding="utf-8", errors="ignore") as f:
            f.seek(0, 2)
            while True:
                line = f.readline()
                if not line:
                    await asyncio.sleep(0.5)
                    continue
                try:
                    payload = json.loads(line)
                except json.JSONDecodeError:
                    continue
                await producer.send_and_wait(TOPIC, json.dumps(payload).encode("utf-8"))
    finally:
        await producer.stop()


if __name__ == "__main__":
    asyncio.run(tail_and_forward())
