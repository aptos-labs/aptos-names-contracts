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
    wget https://github.com/aptos-labs/aptos-core/releases/download/aptos-cli-v1.0.4/aptos-cli-1.0.4-$TARGET.zip
    sha=$(shasum -a 256 aptos-cli-1.0.4-Ubuntu-x86_64.zip | awk '{ print $1 }')
    [ "$sha" != "a78beaeef72cc532fc50d3be666a90cb50d09cc61edbfb8711e4173014a4baed" ] && echo "shasum mismatch" && exit 1
    unzip aptos-cli-1.0.4-Ubuntu-x86_64.zip
    chmod +x aptos
else
    echo "aptos already installed"
fi

echo "##### Info #####"
./aptos info
