from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone

from .config import settings
from .kafka import publisher

logger = logging.getLogger(__name__)
SOH = ""


def _normalize_wire_message(raw: str) -> str:
    return raw.replace("|", SOH).strip()


def _parse_fix(raw: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for item in raw.split(SOH):
        if not item or "=" not in item:
            continue
        k, v = item.split("=", 1)
        result[k] = v
    return result


def _build_logon_ack(seq: str = "1") -> bytes:
    ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H:%M:%S.%f")[:-3]
    msg = SOH.join([
        "8=FIX.4.4",
        "35=A",
        "34=" + seq,
        "49=SIMEX",
        "56=CLIENT",
        f"52={ts}",
        "98=0",
        "108=30",
        "10=000",
        "",
    ])
    return msg.encode("utf-8")


async def handle_fix_client(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
    peer = writer.get_extra_info("peername")
    logger.info("fix client connected: %s", peer)
    while not reader.at_eof():
        line = await reader.readline()
        if not line:
            break
        decoded = _normalize_wire_message(line.decode("utf-8", errors="ignore"))
        parsed = _parse_fix(decoded)
        msg_type = parsed.get("35", "unknown")
        payload = {
            "source": "fix-mock",
            "event_type": "fix_message",
            "msg_type": msg_type,
            "peer": str(peer),
            "fields": parsed,
            "ts": datetime.now(timezone.utc).isoformat(),
        }
        await publisher.publish(settings.audit_topic, payload)

        if msg_type == "A":
            writer.write(_build_logon_ack())
        else:
            writer.write(b"8=FIX.4.435=349=SIMEX56=CLIENT10=000")
        await writer.drain()
    writer.close()
    await writer.wait_closed()
    logger.info("fix client disconnected: %s", peer)


async def start_fix_server() -> asyncio.AbstractServer:
    return await asyncio.start_server(handle_fix_client, settings.fix_listen_host, settings.fix_listen_port)
