#!/bin/sh
cd $(dirname "$0")

if ! [ -x "$(command -v love)" ];
then
  echo "Please install Love2D: https://love2d.org"
  exit 1
fi

love trackmaker.love