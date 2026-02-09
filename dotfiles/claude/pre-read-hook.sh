#!/usr/bin/env bash
file_path=$(jq -r '.tool_input.file_path // ""')
case "$file_path" in
  /tmp/tmux-panes-*) ;;
  *) exit 0 ;;
esac

[ -z "$TMUX" ] && exit 0

current_pane=$(tmux display-message -p '#{pane_id}')
output="/tmp/tmux-panes-${TMUX_PANE}.txt"
> "$output"

for pane_id in $(tmux list-panes -F '#{pane_id}'); do
  [ "$pane_id" = "$current_pane" ] && continue
  pane_index=$(tmux display-message -t "$pane_id" -p '#{pane_index}')
  pane_cmd=$(tmux display-message -t "$pane_id" -p '#{pane_current_command}')
  echo "=== Pane $pane_index [$pane_id] ($pane_cmd) ===" >> "$output"
  tmux capture-pane -t "$pane_id" -p | tail -200 >> "$output"
  echo "" >> "$output"
done
