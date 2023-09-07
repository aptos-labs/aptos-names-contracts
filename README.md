# Aptos Name Service

Branches
- `main` branch → current dev
- `mainnet` branch → current mainnet deployment
- `testnet` branch → current testnet deployment

## Testing

### Unit test
Run `./sh_scripts/move_tests.sh`.

### Deploy to testnet
1. Run `aptos init` to create a new profile.
2. Update the address you want to deploy to and profile in `move_publish.sh`.
3. Run `./sh_scripts/move_publish.sh` to deploy.
