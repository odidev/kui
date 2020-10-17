#!/usr/bin/env bash
SCRIPTDIR=$(cd $(dirname "$0") && pwd)
cd "$SCRIPTDIR"/../../tools/go/ibmcloud

echo "Installing Go Stable"
eval "$(gimme 1.15)";

echo "Building ibmcloud kui binary"
make

echo "Installing ibmcloud kui plugin"
make install

echo "Testing Kui dist download and duplicate download"
make test
