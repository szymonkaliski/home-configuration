#!/usr/bin/env bash

ts() { while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done; }
exec > >(ts) 2>&1

NODE=/Users/szymon/.nix-profile/bin/node
APP=/Users/szymon/.npm/bin/alfred-infinite-clipboard

$NODE $APP backup
