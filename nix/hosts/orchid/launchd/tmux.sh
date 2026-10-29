#!/usr/bin/env bash

export PATH="/Users/szymon/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

while true; do
  if ! tmux has-session -t "=home" 2> /dev/null; then
    /bin/zsh -lc 'tmux new-session -d -s home -c "$HOME"'
  fi
  sleep 5
done
