# Scripts

`check-rpc.sh` — confirms `MONAD_RPC_URL` returns the configured chain ID (default Monad Testnet `10143`).

`ci.sh` — Foundry `--offline` tests, then backend pytest. Same sequence as `.github/workflows/test.yml`.

`deploy-monad.sh` — broadcasts `script/Deploy.s.sol` to Monad Testnet. Requires `PRIVATE_KEY` in `.env`.

`seed-demo.sh` — seeds demo trade history, then deposits USDC and issues credit on the deployed vault.
