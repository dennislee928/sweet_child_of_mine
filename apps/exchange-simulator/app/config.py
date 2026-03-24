from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(extra="ignore")

    app_name: str = Field(default="exchange-simulator", alias="APP_NAME")
    kafka_bootstrap_servers: str = Field(default="localhost:9092", alias="KAFKA_BOOTSTRAP_SERVERS")
    kafka_security_protocol: str = Field(default="PLAINTEXT", alias="KAFKA_SECURITY_PROTOCOL")
    kafka_sasl_mechanism: str = Field(default="SCRAM-SHA-512", alias="KAFKA_SASL_MECHANISM")
    kafka_sasl_username: str = Field(default="", alias="KAFKA_SASL_USERNAME")
    kafka_sasl_password: str = Field(default="", alias="KAFKA_SASL_PASSWORD")
    kafka_ssl_ca_location: str | None = Field(default=None, alias="KAFKA_SSL_CA_LOCATION")
    market_events_topic: str = Field(default="market-events", alias="MARKET_EVENTS_TOPIC")
    audit_topic: str = Field(default="simulator-audit", alias="AUDIT_TOPIC")
    http_port: int = Field(default=8080, alias="HTTP_PORT")
    fix_listen_host: str = Field(default="0.0.0.0", alias="FIX_LISTEN_HOST")
    fix_listen_port: int = Field(default=9878, alias="FIX_LISTEN_PORT")
    symbols: str = Field(default="BTC-USD,ETH-USD,SOL-USD,AAPL,TSLA,NVDA", alias="SYMBOLS")


settings = Settings()
