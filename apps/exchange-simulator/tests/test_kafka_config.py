import app.kafka as kafka_mod


def test_producer_kwargs_plaintext(monkeypatch) -> None:
    monkeypatch.setattr(kafka_mod.settings, "kafka_security_protocol", "PLAINTEXT")
    monkeypatch.setattr(kafka_mod.settings, "kafka_bootstrap_servers", "localhost:9092")
    monkeypatch.setattr(kafka_mod.settings, "kafka_ssl_ca_location", None)
    kw = kafka_mod._producer_kwargs()
    assert kw["security_protocol"] == "PLAINTEXT"
    assert kw["bootstrap_servers"] == "localhost:9092"
    assert "sasl_mechanism" not in kw


def test_producer_kwargs_sasl_plaintext(monkeypatch) -> None:
    monkeypatch.setattr(kafka_mod.settings, "kafka_security_protocol", "SASL_PLAINTEXT")
    monkeypatch.setattr(kafka_mod.settings, "kafka_bootstrap_servers", "k:9092")
    monkeypatch.setattr(kafka_mod.settings, "kafka_sasl_mechanism", "SCRAM-SHA-512")
    monkeypatch.setattr(kafka_mod.settings, "kafka_sasl_username", "user")
    monkeypatch.setattr(kafka_mod.settings, "kafka_sasl_password", "secret")
    monkeypatch.setattr(kafka_mod.settings, "kafka_ssl_ca_location", None)
    kw = kafka_mod._producer_kwargs()
    assert kw["sasl_plain_username"] == "user"
    assert kw["sasl_plain_password"] == "secret"
    assert "ssl_context" not in kw
