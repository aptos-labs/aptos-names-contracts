This script helps with bulk name migration

Each iteration:
1. Update the script with the appropriate names to migrate
2. Compile the script: `aptos move compile`
3. 
   - Run the script: `aptos move run-script --compiled-script-path bulk_migrate/build/bulk_migrate/bytecode_scripts/main.mv --profile admin bulk_migrate=address_that_deploys_the_bulk_migrate_contract`
   - Deploy the contract: 
   ```
   aptos move publish \
     --profile bulk_migrate_profile \
     --package-dir bulk_migrate \
     --named-addresses aptos_names=$APTOS_NAMES,aptos_names_v2=$APTOS_NAMES_V2,aptos_names_admin=$ADMIN,aptos_names_funds=$FUNDS,router=$ROUTER,router_signer=$ROUTER_SIGNER,bulk_migrate=$BULK_MIGRATE
   ```
