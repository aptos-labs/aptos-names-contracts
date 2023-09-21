#!/bin/sh

set -e

echo "##### Publishing packages #####"
# Set these to the account address you want to deploy to.
APTOS_NAMES="0xc50ebbeba2335882faa281b22888776f1c5f098e5e3176f17374246508645e98"
APTOS_NAMES_V2_1="0xc50ebbeba2335882faa281b22888776f1c5f098e5e3176f17374246508645e98"
BULK="0xc50ebbeba2335882faa281b22888776f1c5f098e5e3176f17374246508645e98"
ADMIN="0xc50ebbeba2335882faa281b22888776f1c5f098e5e3176f17374246508645e98"
FUNDS="0xc50ebbeba2335882faa281b22888776f1c5f098e5e3176f17374246508645e98"
ROUTER="0xc50ebbeba2335882faa281b22888776f1c5f098e5e3176f17374246508645e98"

ROUTER_SIGNER=0x$(aptos account derive-resource-account-address \
  --address $ROUTER \
  --seed "ANS ROUTER" \
  --seed-encoding utf8 | \
  grep "Result" | \
  sed -n 's/.*"Result": "\([^"]*\)".*/\1/p')

aptos move publish \
  --profile jianyi-test3 \
  --package-dir core \
  --named-addresses aptos_names=$APTOS_NAMES,aptos_names_admin=$ADMIN,aptos_names_funds=$FUNDS,router_signer=$ROUTER_SIGNER
aptos move publish \
  --profile jianyi-test3 \
  --package-dir core_v2 \
  --named-addresses aptos_names=$APTOS_NAMES,aptos_names_v2_1=$APTOS_NAMES_V2_1,aptos_names_admin=$ADMIN,aptos_names_funds=$FUNDS,router=$ROUTER,router_signer=$ROUTER_SIGNER
aptos move publish \
  --profile jianyi-test3 \
  --package-dir router \
  --named-addresses aptos_names=$APTOS_NAMES,aptos_names_v2_1=$APTOS_NAMES_V2_1,aptos_names_admin=$ADMIN,aptos_names_funds=$FUNDS,router=$ROUTER,router_signer=$ROUTER_SIGNER
aptos move publish \
  --profile jianyi-test3 \
  --package-dir bulk \
  --named-addresses aptos_names=$APTOS_NAMES,aptos_names_v2_1=$APTOS_NAMES_V2_1,aptos_names_admin=$ADMIN,aptos_names_funds=$FUNDS,router=$ROUTER,router_signer=$ROUTER_SIGNER,bulk=$BULK
