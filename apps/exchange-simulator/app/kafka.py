from __future__ import annotations

import asyncio
import json
import logging
import ssl
from typing import Any

from aiokafka import AIOKafkaProducer

from .config import settings

logger = logging.getLogger(__name__)


def _producer_kwargs() -> dict[str, Any]:
    proto = settings.kafka_security_protocol.upper()
    kwargs: dict[str, Any] = {
        "bootstrap_servers": settings.kafka_bootstrap_servers,
        "value_serializer": lambda v: json.dumps(v).encode("utf-8"),
        "security_protocol": proto,
    }
    if proto in ("SASL_SSL", "SASL_PLAINTEXT"):
        kwargs["sasl_mechanism"] = settings.kafka_sasl_mechanism
        kwargs["sasl_plain_username"] = settings.kafka_sasl_username
        kwargs["sasl_plain_password"] = settings.kafka_sasl_password
    if proto == "SASL_SSL" and settings.kafka_ssl_ca_location:
        kwargs["ssl_context"] = ssl.create_default_context(cafile=settings.kafka_ssl_ca_location)
    return kwargs


class KafkaPublisher:
    def __init__(self) -> None:
        self._producer: AIOKafkaProducer | None = None
        self._lock = asyncio.Lock()

    async def start(self) -> None:
        async with self._lock:
            if self._producer is None:
                self._producer = AIOKafkaProducer(**_producer_kwargs())
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
