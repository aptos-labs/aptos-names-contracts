#!/bin/sh

set -e

echo "##### Installing aptos cli dependencies #####"
sudo apt-get update
sudo apt-get install libssl-dev

echo "##### Installing aptos cli #####"
if ! command -v aptos &>/dev/null; then
    echo "aptos could not be found"
    echo "installing it..."
    TARGET=Ubuntu-x86_64
    wget https://github.com/aptos-labs/aptos-core/releases/download/aptos-cli-v1.0.1/aptos-cli-1.0.1-$TARGET.zip
    sha=$(shasum -a 256 aptos-cli-1.0.1-Ubuntu-x86_64.zip | awk '{ print $1 }')
    [ "$sha" != "2dceb6da7f4de1c4f9efbb9e171a5721a439e9b2b28554551a51ca8c39230b05" ] && echo "shasum mismatch" && exit 1
    unzip aptos-cli-1.0.1-Ubuntu-x86_64.zip
    chmod +x aptos
else
    echo "aptos already installed"
fi

echo "##### Info #####"
./aptos info
