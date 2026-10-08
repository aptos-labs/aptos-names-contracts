#!/bin/sh

set -e

echo "##### Configuring testnet deployment #####"
# Set these to the same values used in move_publish.sh.
APTOS_NAMES="0xb1ae61606dfbe0ea5b5c45ffdb4fb08da0dba18c5125182ff63ab280a450ecf4"
APTOS_NAMES_V2_1="0xb1ae61606dfbe0ea5b5c45ffdb4fb08da0dba18c5125182ff63ab280a450ecf4"
ROUTER="0xb1ae61606dfbe0ea5b5c45ffdb4fb08da0dba18c5125182ff63ab280a450ecf4"
PROFILE="ans_testnet"

aptos move run --assume-yes \
  --profile $PROFILE \
  --function-id $APTOS_NAMES::domains::init_reverse_lookup_registry_v1
aptos move run --assume-yes \
  --profile $PROFILE \
  --function-id $ROUTER::router::set_mode \
  --args u8:1
aptos move run --assume-yes \
  --profile $PROFILE \
  --function-id $APTOS_NAMES::config::set_tokendata_url_prefix \
  --args string:https://www.aptosnames.com/api/testnet/v1/metadata/
aptos move run --assume-yes \
  --profile $PROFILE \
  --function-id $APTOS_NAMES_V2_1::v2_1_config::set_tokendata_url_prefix \
  --args string:https://www.aptosnames.com/api/testnet/v2/metadata/
