#!/bin/sh

set -e

echo "##### Running tests #####"
./aptos move test --package-dir core --named-addresses aptos_names=0x867ed1f6bf916171b1de3ee92849b8978b7d1b9e0a8cc982a3d19d535dfd9c0c,aptos_names_admin=0x91945b4672607a327019e768dd6045d1254d1102d882df434ca734250bb3581d,aptos_names_funds=0x78ee3915e67ef5d19fa91d1e05e60ae08751efd12ce58e23fc1109de87ea7865
