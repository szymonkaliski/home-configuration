#!/usr/bin/env bash

command -v tnotify &> /dev/null || exit 0

if [ -n "$TMUX" ]; then
  tnotify -t 'Claude Code' "$1" > "$(tmux display-message -p '#{pane_tty}')"
else
  tnotify -t 'Claude Code' "$1" --native
fi
