from __future__ import annotations

import asyncio
import json
import os
from pathlib import Path

from aiokafka import AIOKafkaProducer

EVE_FILE = os.getenv("EVE_FILE", "/var/log/suricata/eve.json")
BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
TOPIC = os.getenv("KAFKA_TOPIC", "suricata-eve")


async def tail_and_forward() -> None:
    producer = AIOKafkaProducer(bootstrap_servers=BOOTSTRAP)
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
