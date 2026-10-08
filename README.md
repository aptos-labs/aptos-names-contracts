# Aptos Name Service

Branches
- `main` branch → current dev
- `mainnet` branch → current mainnet deployment
- `testnet` branch → current testnet deployment

## Testnet addresses
- `aptos_names`, `aptos_names_v2_1`, `router`, `bulk`: `0xb1ae61606dfbe0ea5b5c45ffdb4fb08da0dba18c5125182ff63ab280a450ecf4`
- `aptos_names_admin`, `aptos_names_funds`: `0x0d7ef04a0aebcec9238e41775ccc857f60e073a81d4a3ea31442d63be3c5e191`

## Testing

### Unit test
Run `./sh_scripts/move_tests.sh`.

### Deploy to testnet
1. Run `aptos init` to create a new profile.
2. Update the address you want to deploy to and profile in `move_publish.sh`.
3. Run `./sh_scripts/move_publish.sh` to deploy.
4. Set the same addresses in `testnet_setup.sh` and run `./sh_scripts/testnet_setup.sh` to init the reverse lookup registry, switch the router to V1+V2 mode and set testnet metadata URLs.
