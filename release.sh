#!/bin/bash

# this script assumes you have nfd.dll and nfd.so in your root dir, as well as
# love-release (https://github.com/MisterDA/love-release) installed

ver=$(lua -e 'love = {}; require "conf"; local t = { window = {}, modules = {}, releases = {} }; love.conf(t); print(t.releases.version)')
echo "releasing ver ${ver}"

love-release -W 64

# windows

mkdir -p releases/trackmaker-win64
unzip releases/trackmaker-win64.zip -d releases/trackmaker-win64/
rm releases/trackmaker-win64.zip

cp nfd.dll releases/trackmaker-win64/

zip "releases/trackmaker-win64-${ver}.zip" releases/trackmaker-win64/*
rm -r releases/trackmaker-win64

# linux

mkdir -p releases/trackmaker-linux

cp nfd.so releases/trackmaker-linux/
cp releases/trackmaker.love releases/trackmaker-linux/
cp platform/linux/start.sh releases/trackmaker-linux/

zip "releases/trackmaker-linux-${ver}.zip" releases/trackmaker-linux/*
rm -r releases/trackmaker-linux

# love

mv releases/trackmaker.love "releases/trackmaker-${ver}.love"