from app.models import OrderRequest, Order


def test_order_factory() -> None:
    req = OrderRequest(symbol="BTC-USD", side="buy", price=1.0, quantity=2.0, account_id="acct")
    order = Order.from_request(req)
    assert order.symbol == "BTC-USD"
    assert order.status == "accepted"
