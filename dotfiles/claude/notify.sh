#!/usr/bin/env bash

if [ -n "$TMUX" ]; then
  tnotify -t 'Claude Code' "$1" > "$(tmux display-message -p '#{pane_tty}')"
else
  tnotify -t 'Claude Code' "$1" --native
fi
