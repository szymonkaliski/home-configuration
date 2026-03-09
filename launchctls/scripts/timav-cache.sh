#!/usr/bin/env bash

ts() { while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done; }
exec > >(ts) 2>&1

if pmset -g batt | grep -q "Battery Power"; then
  echo "skipping caching when on battery"
  exit 0
fi

NODE=/Users/szymon/.nix-profile/bin/node
APP=/Users/szymon/.npm/bin/timav

DEBUG=* $NODE $APP cache
