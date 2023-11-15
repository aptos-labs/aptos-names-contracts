This script helps with bulk seize name as an admin. It will overrule the renewal window and the max renewal period.  

Preparation:
1. Update `Move.toml` with the correct `repository` account.
2. Use the admin account to run the script.

Each iteration:
1. Update the script with the appropriate names to renew 
2. Update the time period to renew the names for
3. Compile the script: `aptos move compile`
4. Run the script: `aptos move run-script --compiled-script-path bulk_force_seize_name/build/aptos_names_bulk_seize_name/bytecode_scripts/main.mv --profile admin`
