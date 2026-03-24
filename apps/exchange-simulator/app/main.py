from __future__ import annotations

import asyncio
import json
import logging
import random
from collections import defaultdict
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Any

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect

from .config import settings
from .fix_server import start_fix_server
from .kafka import publisher
from .models import Order, OrderRequest

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger(__name__)

ORDERS: dict[str, Order] = {}
ORDERBOOKS: dict[str, dict[str, list[list[float]]]] = defaultdict(dict)
WS_CLIENTS: dict[str, set[WebSocket]] = defaultdict(set)
FIX_SERVER = None


for symbol in [s.strip() for s in settings.symbols.split(",") if s.strip()]:
    ORDERBOOKS[symbol] = {
        "bids": [[100.0 - i, round(random.uniform(1, 10), 4)] for i in range(5)],
        "asks": [[100.5 + i, round(random.uniform(1, 10), 4)] for i in range(5)],
    }


async def publish_audit(event: dict[str, Any]) -> None:
    await publisher.publish(settings.audit_topic, event)
    logger.info(json.dumps(event))


async def market_publisher() -> None:
    symbols = list(ORDERBOOKS.keys())
    while True:
        await asyncio.sleep(1)
        symbol = random.choice(symbols)
        mid = round(random.uniform(95, 110), 2)
        event = {
            "source": "exchange-simulator",
            "event_type": "tick",
            "symbol": symbol,
            "best_bid": round(mid - 0.2, 2),
            "best_ask": round(mid + 0.2, 2),
            "ts": datetime.now(timezone.utc).isoformat(),
        }
        await publisher.publish(settings.market_events_topic, event)
        stale = []
        for ws in WS_CLIENTS[symbol]:
            try:
                await ws.send_json(event)
            except Exception:
                stale.append(ws)
        for ws in stale:
            WS_CLIENTS[symbol].discard(ws)


@asynccontextmanager
async def lifespan(_: FastAPI):
    global FIX_SERVER
    await publisher.start()
    FIX_SERVER = await start_fix_server()
    task = asyncio.create_task(market_publisher())
    try:
        yield
    finally:
        task.cancel()
        FIX_SERVER.close()
        await FIX_SERVER.wait_closed()
        await publisher.stop()


app = FastAPI(title=settings.app_name, lifespan=lifespan)


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/v1/symbols")
async def list_symbols() -> dict[str, list[str]]:
    return {"symbols": list(ORDERBOOKS.keys())}


@app.get("/api/v1/orderbook/{symbol}")
async def get_orderbook(symbol: str) -> dict[str, Any]:
    if symbol not in ORDERBOOKS:
        raise HTTPException(status_code=404, detail="symbol not found")
    return {"symbol": symbol, "book": ORDERBOOKS[symbol]}


@app.post("/api/v1/orders")
async def place_order(order_req: OrderRequest) -> Order:
    if order_req.symbol not in ORDERBOOKS:
        raise HTTPException(status_code=400, detail="unsupported symbol")
    order = Order.from_request(order_req)
    ORDERS[order.id] = order
    event = {
        "source": "exchange-simulator",
        "event_type": "order_accepted",
        "order": order.model_dump(),
        "ts": datetime.now(timezone.utc).isoformat(),
    }
    await publish_audit(event)
    return order


@app.delete("/api/v1/orders/{order_id}")
async def cancel_order(order_id: str) -> dict[str, str]:
    order = ORDERS.get(order_id)
    if order is None:
        raise HTTPException(status_code=404, detail="order not found")
    order.status = "canceled"
    event = {
        "source": "exchange-simulator",
        "event_type": "order_canceled",
        "order": order.model_dump(),
        "ts": datetime.now(timezone.utc).isoformat(),
    }
    await publish_audit(event)
    return {"status": "canceled", "id": order_id}


@app.websocket("/ws/market")
async def ws_market(websocket: WebSocket, symbol: str) -> None:
    if symbol not in ORDERBOOKS:
        await websocket.close(code=1008)
        return
    await websocket.accept()
    WS_CLIENTS[symbol].add(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        WS_CLIENTS[symbol].discard(websocket)
