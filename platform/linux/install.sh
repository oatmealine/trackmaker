#!/usr/bin/env bash

cd $(dirname "$0")
set -eou pipefail

data_home=${XDG_DATA_HOME:=$HOME/.local/share}
desktop_db=$data_home/applications
mime_db=$data_home/mime

echo "writing trackmaker.desktop to '$desktop_db/'"
sed "s~Exec=.*~Exec=$(pwd)/start.sh %f~" ./desktop/trackmaker.desktop > "$desktop_db/trackmaker.desktop"
sed -i "s~Icon=.*~Icon=$(pwd)/desktop/trackmaker.png~" "$desktop_db/trackmaker.desktop"
echo "writing MIME association for application-xdrv to '$mime_db/packages/'"
cp ./desktop/application-xdrv.xml "$mime_db/packages/"

echo "updating .desktop database"
update-desktop-database "$desktop_db"
echo "updating MIME database"
update-mime-database "$mime_db"

echo "done!"
echo "make sure to re-run this script if the location of this folder changes"