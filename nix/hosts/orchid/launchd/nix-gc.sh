#!/usr/bin/env bash

ts() { while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done; }
exec > >(ts) 2>&1

echo "starting nix-collect-garbage"
/nix/var/nix/profiles/default/bin/nix-collect-garbage --delete-older-than 30d
echo "done"
