#!/usr/bin/env bash

set -euo pipefail

# this script assumes you have nfd.dll and nfd.so in your root dir, as well as
# love-release (https://github.com/MisterDA/love-release) installed
# mac also uses nfd.so, so it assumes you either also have nfd_mac.so or
# nfd_linux.so

nfd_windows=nfd.dll
nfd_mac=nfd.so
nfd_linux=nfd.so
if [ -f "nfd_mac.so" ]; then
  nfd_mac=nfd_mac.so
fi
if [ -f "nfd_linux.so" ]; then
  nfd_linux=nfd_linux.so
fi

ver=$(lua -e 'love = {}; require "conf"; local t = { window = {}, modules = {}, releases = {} }; love.conf(t); print(t.releases.version)')
echo "releasing ver ${ver}"

love-release -W 64 -M

# windows

rm -f releases/trackmaker-win64-*.zip

mkdir -p releases/trackmaker-win64
unzip releases/trackmaker-win64.zip -d releases/
rm releases/trackmaker-win64.zip

cp $nfd_windows releases/trackmaker-win64/
cp LICENSE.txt releases/trackmaker-win64/license.txt
cp platform/universal/love-license.txt releases/trackmaker-win64/love-license.txt

cd releases/trackmaker-win64/ || exit 1
zip -9 "../trackmaker-win64-${ver}.zip" ./*
cd ../../
rm -r releases/trackmaker-win64

# mac

rm -f releases/trackmaker-macos-*.zip

unzip releases/trackmaker-macos.zip -d releases/
rm releases/trackmaker-macos.zip

cp $nfd_mac releases/trackmaker.app/Contents/Resources/
cp platform/universal/love-license.txt releases/trackmaker.app/Contents/Resources/
cp LICENSE.txt releases/trackmaker.app/Contents/Resources/

cd releases/ || exit 1
zip -r9 "trackmaker-macos-${ver}.zip" trackmaker.app
cd ../
rm -r releases/trackmaker.app/

# linux

rm -f releases/trackmaker-linux-*.zip

mkdir -p releases/trackmaker-linux

cp "$nfd_linux" releases/trackmaker-linux/
cp releases/trackmaker.love releases/trackmaker-linux/
cp platform/linux/start.sh releases/trackmaker-linux/
cp LICENSE.txt releases/trackmaker-linux/license.txt
cp platform/universal/love-license.txt releases/trackmaker-linux/love-license.txt

cd "releases/trackmaker-linux/" || exit 1
zip -9 "../trackmaker-linux-${ver}.zip" ./*
cd ../../
rm -r releases/trackmaker-linux

# love

rm -f releases/trackmaker-*.love
cp releases/trackmaker.love "releases/trackmaker-${ver}.love"