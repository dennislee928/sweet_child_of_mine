from __future__ import annotations

import asyncio
import json
import logging
from typing import Any

from aiokafka import AIOKafkaProducer

from .config import settings

logger = logging.getLogger(__name__)


class KafkaPublisher:
    def __init__(self) -> None:
        self._producer: AIOKafkaProducer | None = None
        self._lock = asyncio.Lock()

    async def start(self) -> None:
        async with self._lock:
            if self._producer is None:
                self._producer = AIOKafkaProducer(
                    bootstrap_servers=settings.kafka_bootstrap_servers,
                    value_serializer=lambda v: json.dumps(v).encode("utf-8"),
                )
                await self._producer.start()
                logger.info("kafka producer started")

    async def stop(self) -> None:
        async with self._lock:
            if self._producer is not None:
                await self._producer.stop()
                self._producer = None
                logger.info("kafka producer stopped")

    async def publish(self, topic: str, payload: dict[str, Any]) -> None:
        if self._producer is None:
            raise RuntimeError("producer not started")
        await self._producer.send_and_wait(topic, payload)


publisher = KafkaPublisher()
