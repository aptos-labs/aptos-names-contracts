#!/bin/sh

set -e

echo "##### Installing aptos cli #####"
if ! command -v aptos &>/dev/null; then
    echo "aptos could not be found"
    echo "installing it..."
    wget https://github.com/aptos-labs/aptos-core/releases/download/aptos-cli-v1.0.1/aptos-cli-1.0.1-Ubuntu-x86_64.zip
    sha=$(shasum -a 256 aptos-cli-1.0.1-Ubuntu-x86_64.zip | awk '{ print $1 }')
    [ "$sha" != "e968d29fd82542ae454455e9cc873575541af690771f1d6e696c66ffe6fd64e2" ] && echo "shasum mismatch" && exit 1
    unzip aptos-cli-1.0.1-Ubuntu-x86_64.zip
    chmod +x aptos
else
    echo "aptos already installed"
fi

echo "##### Info #####"
./aptos info

echo "##### Installing aptos cli dependencies #####"
sudo apt-get update
sudo apt-get install libssl-dev

echo "##### Running tests #####"
./aptos move test --package-dir core
