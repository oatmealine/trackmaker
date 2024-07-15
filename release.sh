#!/bin/bash

# this script assumes you have nfd.dll and nfd.so in your root dir, as well as
# love-release (https://github.com/MisterDA/love-release) installed

ver=$(lua -e 'love = {}; require "conf"; local t = { window = {}, modules = {}, releases = {} }; love.conf(t); print(t.releases.version)')
echo "releasing ver ${ver}"

love-release -W 64

# windows

rm -f releases/trackmaker-win64-*.zip

mkdir -p releases/trackmaker-win64
unzip releases/trackmaker-win64.zip -d releases/
rm releases/trackmaker-win64.zip

cp nfd.dll releases/trackmaker-win64/

cd releases/trackmaker-win64/
zip -9 "../trackmaker-win64-${ver}.zip" ./*
cd ../../
rm -r releases/trackmaker-win64

# linux

rm -f releases/trackmaker-linux-*.zip

mkdir -p releases/trackmaker-linux

cp nfd.so releases/trackmaker-linux/
cp releases/trackmaker.love releases/trackmaker-linux/
cp platform/linux/start.sh releases/trackmaker-linux/

cd "releases/trackmaker-linux/"
zip -9 "../trackmaker-linux-${ver}.zip" ./*
cd ../../
rm -r releases/trackmaker-linux

# love

mv releases/trackmaker.love "releases/trackmaker-${ver}.love"