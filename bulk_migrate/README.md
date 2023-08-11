This script helps with bulk name migration

Preparation:
1. Update `Move.toml` with the correct `repository` account.

Each iteration:
1. Update the script with the appropriate names to migrate
2. Compile the script: `aptos move compile`
3. Run the script: `aptos move run-script --compiled-script-path bulk_clear/build/aptos_names_bulk_migrate/bytecode_scripts/main.mv --profile admin`
