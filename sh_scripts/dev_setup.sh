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
    VERSION=2.0.2
    wget https://github.com/aptos-labs/aptos-core/releases/download/aptos-cli-v$VERSION/aptos-cli-$VERSION-$TARGET.zip
    sha=$(shasum -a 256 aptos-cli-$VERSION-$TARGET.zip | awk '{ print $1 }')
    [ "$sha" != "1f0ed0d0e042ff8b48b428eaaff9f52e6ff2b246a2054740d017f514c753c6cb" ] && echo "shasum mismatch" && exit 1
    unzip aptos-cli-$VERSION-$TARGET.zip
    chmod +x aptos
else
    echo "aptos already installed"
fi

echo "##### Info #####"
./aptos info
