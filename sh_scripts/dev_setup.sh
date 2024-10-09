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
    VERSION=4.2.1
    wget https://github.com/aptos-labs/aptos-core/releases/download/aptos-cli-v$VERSION/aptos-cli-$VERSION-$TARGET.zip
    unzip aptos-cli-$VERSION-$TARGET.zip
    chmod +x aptos
else
    echo "aptos already installed"
fi

echo "##### Info #####"
./aptos info
