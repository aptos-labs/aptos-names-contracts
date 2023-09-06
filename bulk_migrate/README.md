This script helps with bulk name migration

Each iteration:
1. Update the script with the appropriate names to migrate
2. Compile the script: `aptos move compile`
3. Run the script: `aptos move run-script --compiled-script-path bulk_migrate/build/bulk_migrate/bytecode_scripts/main.mv --profile admin bulk_migrate=address_that_deploys_the_bulk_migrate_contract`
