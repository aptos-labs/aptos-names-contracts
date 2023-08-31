#!/bin/sh

set -e

echo "##### Running tests #####"
APTOS_NAMES="0x867ed1f6bf916171b1de3ee92849b8978b7d1b9e0a8cc982a3d19d535dfd9c0c"
APTOS_NAMES_V2="0x867ed1f6bf916171b1de3ee92849b8978b7d1b9e0a8cc982a3d19d535dfd9c0c"
ADMIN="0x91945b4672607a327019e768dd6045d1254d1102d882df434ca734250bb3581d"
FUNDS="0x78ee3915e67ef5d19fa91d1e05e60ae08751efd12ce58e23fc1109de87ea7865"
ROUTER="0x867ed1f6bf916171b1de3ee92849b8978b7d1b9e0a8cc982a3d19d535dfd9c0c"
ROUTER_SIGNER=0x$(./aptos account derive-resource-account-address \
  --address $ROUTER \
  --seed "ANS ROUTER" \
  --seed-encoding utf8 | \
  grep "Result" | \
  sed -n 's/.*"Result": "\([^"]*\)".*/\1/p')

./aptos move test \
  --package-dir core \
  --named-addresses aptos_names=$APTOS_NAMES,aptos_names_admin=$ADMIN,aptos_names_funds=$FUNDS
./aptos move test \
  --package-dir core_v2 \
  --named-addresses aptos_names=$APTOS_NAMES,aptos_names_v2=$APTOS_NAMES_V2,aptos_names_admin=$ADMIN,aptos_names_funds=$FUNDS,router=$ROUTER,router_signer=$ROUTER_SIGNER
./aptos move test \
  --package-dir router \
  --named-addresses aptos_names=$APTOS_NAMES,aptos_names_v2=$APTOS_NAMES_V2,aptos_names_admin=$ADMIN,aptos_names_funds=$FUNDS,router=$ROUTER,router_signer=$ROUTER_SIGNER
