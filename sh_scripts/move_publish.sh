#!/bin/sh

set -e

echo "##### Publishing packages #####"
# Set these to the account address you want to deploy to.
APTOS_NAMES="0xb1ae61606dfbe0ea5b5c45ffdb4fb08da0dba18c5125182ff63ab280a450ecf4"
APTOS_NAMES_V2_1="0xb1ae61606dfbe0ea5b5c45ffdb4fb08da0dba18c5125182ff63ab280a450ecf4"
BULK="0xb1ae61606dfbe0ea5b5c45ffdb4fb08da0dba18c5125182ff63ab280a450ecf4"
ADMIN="0x0d7ef04a0aebcec9238e41775ccc857f60e073a81d4a3ea31442d63be3c5e191"
FUNDS="0x0d7ef04a0aebcec9238e41775ccc857f60e073a81d4a3ea31442d63be3c5e191"
ROUTER="0xb1ae61606dfbe0ea5b5c45ffdb4fb08da0dba18c5125182ff63ab280a450ecf4"
PROFILE="ans_testnet"

ROUTER_SIGNER=0x$(aptos account derive-resource-account-address \
  --address $ROUTER \
  --seed "ANS ROUTER" \
  --seed-encoding utf8 | \
  grep "Result" | \
  sed -n 's/.*"Result": "\([^"]*\)".*/\1/p')

aptos move publish --assume-yes \
  --profile $PROFILE \
  --package-dir core \
  --named-addresses aptos_names=$APTOS_NAMES,aptos_names_admin=$ADMIN,aptos_names_funds=$FUNDS,router_signer=$ROUTER_SIGNER
aptos move publish --assume-yes \
  --profile $PROFILE \
  --package-dir core_v2 \
  --named-addresses aptos_names=$APTOS_NAMES,aptos_names_v2_1=$APTOS_NAMES_V2_1,aptos_names_admin=$ADMIN,aptos_names_funds=$FUNDS,router=$ROUTER,router_signer=$ROUTER_SIGNER
aptos move publish --assume-yes \
  --profile $PROFILE \
  --package-dir router \
  --named-addresses aptos_names=$APTOS_NAMES,aptos_names_v2_1=$APTOS_NAMES_V2_1,aptos_names_admin=$ADMIN,aptos_names_funds=$FUNDS,router=$ROUTER,router_signer=$ROUTER_SIGNER
aptos move publish --assume-yes \
  --profile $PROFILE \
  --package-dir bulk \
  --named-addresses aptos_names=$APTOS_NAMES,aptos_names_v2_1=$APTOS_NAMES_V2_1,aptos_names_admin=$ADMIN,aptos_names_funds=$FUNDS,router=$ROUTER,router_signer=$ROUTER_SIGNER,bulk=$BULK
