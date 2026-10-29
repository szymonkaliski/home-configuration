#!/usr/bin/env bash

ts() { while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done; }
exec > >(ts) 2>&1

if [ ! -d /Applications/Dropbox.app ]; then
  exit 0
fi

if pgrep -x Dropbox > /dev/null; then
  exit 0
fi

if pgrep -f 'DropboxUpdater|DropboxMacUpdate|DropboxInstaller' > /dev/null; then
  echo "Dropbox is not running, but updater is active; skipping"
  exit 0
fi

echo "Dropbox is not running; starting Dropbox.app"
open -g -a /Applications/Dropbox.app
