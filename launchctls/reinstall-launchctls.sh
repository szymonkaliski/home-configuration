#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")"

function reinstall {
  DIR=$(pwd)

  echo "reinstalling: $1"

  ./generate-launchctl.sh "$1.tmpl"

  launchctl unload -w ~/Library/LaunchAgents/"$1"

  rm ~/Library/LaunchAgents/"$1"

  pushd ~/Library/LaunchAgents/ > /dev/null || exit 1
  cp "$DIR/$1" .
  popd > /dev/null || exit 1

  launchctl load -w ~/Library/LaunchAgents/"$1"
}

PLISTS=(
  "com.szymonkaliski.alfred-infinite-clipboard-backup.plist"
  "com.szymonkaliski.muninn-autocommit.plist"
  "com.szymonkaliski.timav-cache.plist"
)

for plist in "${PLISTS[@]}"; do
  reinstall "$plist"
done

echo "status"
launchctl list | grep com.szymonkaliski


