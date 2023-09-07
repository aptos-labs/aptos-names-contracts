#!/bin/sh

set -e

echo "##### Publishing packages #####"
# Set these to the account address you want to deploy to.
APTOS_NAMES=""
APTOS_NAMES_V2=""
BULK_MIGRATE=""
ADMIN=""
FUNDS=""
ROUTER=""

ROUTER_SIGNER=0x$(aptos account derive-resource-account-address \
  --address $ROUTER \
  --seed "ANS ROUTER" \
  --seed-encoding utf8 | \
  grep "Result" | \
  sed -n 's/.*"Result": "\([^"]*\)".*/\1/p')

aptos move publish \
  --profile core_profile \
  --package-dir core \
  --named-addresses aptos_names=$APTOS_NAMES,aptos_names_admin=$ADMIN,aptos_names_funds=$FUNDS,router_signer=$ROUTER_SIGNER
aptos move publish \
  --profile core_v2_profile \
  --package-dir core_v2 \
  --named-addresses aptos_names=$APTOS_NAMES,aptos_names_v2=$APTOS_NAMES_V2,aptos_names_admin=$ADMIN,aptos_names_funds=$FUNDS,router=$ROUTER,router_signer=$ROUTER_SIGNER
aptos move publish \
  --profile router_profile \
  --package-dir router \
  --named-addresses aptos_names=$APTOS_NAMES,aptos_names_v2=$APTOS_NAMES_V2,aptos_names_admin=$ADMIN,aptos_names_funds=$FUNDS,router=$ROUTER,router_signer=$ROUTER_SIGNER
aptos move publish \
  --profile bulk_migrate_profile \
  --package-dir bulk_migrate \
  --named-addresses aptos_names=$APTOS_NAMES,aptos_names_v2=$APTOS_NAMES_V2,aptos_names_admin=$ADMIN,aptos_names_funds=$FUNDS,router=$ROUTER,router_signer=$ROUTER_SIGNER,bulk_migrate=$BULK_MIGRATE
