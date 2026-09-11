from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=("../.env", ".env"),
        extra="ignore",
    )

    kredxo_env: str = "development"
    api_host: str = "0.0.0.0"
    api_port: int = 8000

    monad_network: str = "testnet"
    monad_chain_id: int = 10143
    monad_rpc_url: str = "https://testnet-rpc.monad.xyz"
    monad_ws_url: str = "wss://testnet-rpc.monad.xyz"
    monad_explorer_url: str = "https://testnet.monadvision.com"
    monad_native_symbol: str = "MON"

    database_url: str = "postgresql+psycopg://kredxo:kredxo@127.0.0.1:15432/kredxo"
    trading_account_address: str = ""
    credit_vault_address: str = ""
    usdc_address: str = ""
    risk_policy_address: str = ""
    risk_controller_address: str = ""
    settlement_address: str = ""
    indexer_from_block: int = 0
    demo_wallet: str = "0x83000000000000000000000000000000000009A2"


settings = Settings()
