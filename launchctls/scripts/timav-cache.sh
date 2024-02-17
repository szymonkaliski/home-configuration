#!/usr/bin/env bash

date

if pmset -g batt | grep -q "Battery Power"; then
  echo "skipping caching when on battery"
  exit 0
fi

NODE=/Users/szymon/.nix-profile/bin/node
APP=/Users/szymon/.npm/bin/timav

DEBUG=* $NODE $APP cache
