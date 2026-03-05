#!/bin/sh

# borrowed from olympus's olympus.sh
realpath() {
  [ "." = "${1}" ] && n=${PWD} || n=${1}; while nn=$( readlink -n "$n" ); do n=$nn; done; echo "$n"
}

cd "$(dirname "$(realpath "$0")")" || exit 1

if ! [ -x "$(command -v love)" ];
then
  echo "Please install Love2D: https://love2d.org"
  exit 1
fi

SDL_VIDEO_X11_WMCLASS="trackmaker" SDL_VIDEO_WAYLAND_WMCLASS="trackmaker" \
love trackmaker.love "$@"