from __future__ import annotations

from datetime import datetime, timezone
from typing import Literal
from uuid import uuid4

from pydantic import BaseModel, Field


class OrderRequest(BaseModel):
    symbol: str
    side: Literal["buy", "sell"]
    price: float = Field(gt=0)
    quantity: float = Field(gt=0)
    account_id: str


class Order(BaseModel):
    id: str
    symbol: str
    side: Literal["buy", "sell"]
    price: float
    quantity: float
    account_id: str
    status: Literal["accepted", "canceled"]
    ts: str

    @classmethod
    def from_request(cls, req: OrderRequest) -> "Order":
        return cls(
            id=str(uuid4()),
            symbol=req.symbol,
            side=req.side,
            price=req.price,
            quantity=req.quantity,
            account_id=req.account_id,
            status="accepted",
            ts=datetime.now(timezone.utc).isoformat(),
        )
