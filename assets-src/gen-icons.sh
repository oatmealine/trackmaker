#!/usr/bin/env bash

# requires inkscape, imagemagick, icotool, icnsify

set -euo pipefail

svg=$(realpath "$1")

cd "$(dirname "$0")"

# .ico

# https://stackoverflow.com/questions/3236115/which-icon-sizes-should-my-windows-applications-icon-include
inkscape --export-type png -w 256 -h 256 "$svg" -o ./trackmaker-256.png
inkscape --export-type png -w 64 -h 64 "$svg" -o ./trackmaker-64.png
inkscape --export-type png -w 48 -h 48 "$svg" -o ./trackmaker-48.png
inkscape --export-type png -w 32 -h 32 "$svg" -o ./trackmaker-32.png
inkscape --export-type png -w 16 -h 16 "$svg" -o ./trackmaker-16.png

icotool -c ./trackmaker-*.png > trackmaker.ico
rm ./trackmaker-*.png

echo "trackmaker.ico > platform/windows/trackmaker.ico"

# .icns

inkscape --export-type png -w 512 -h 512 "$svg" -o ./trackmaker-512.png
# we want to pad this out by a bit, bc macos icons are smaller by default
convert trackmaker-512.png -resize 412x412 -background transparent -gravity center -extent 512x512 trackmaker-512.png
icnsify ./trackmaker-512.png -o ./trackmaker.icns
rm ./trackmaker-512.png

echo "trackmaker.icns > platform/macos/OS X AppIcon.icns"

# application

inkscape --export-type png -w 256 -h 256 "$svg" -o ./trackmaker-icon.png

echo "trackmaker-icon.png > assets/sprites/trackmaker-icon.png"
echo "trackmaker-icon.png > platform/linux/desktop/trackmaker.png"
