#!/usr/bin/env bash

input=$(cat)
event=$(echo "$input" | jq -r '.hook_event_name // empty')
message=$(echo "$input" | jq -r '.message // empty')
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

if [ "$event" = "Stop" ]; then
  body="Waiting for input"
  if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    last_text=$(tail -50 "$transcript_path" | \
      jq -r 'select(.type == "assistant") | .message.content[] | select(.type == "text") | .text' 2>/dev/null | \
      tail -1 | \
      head -c 200)
    [ -n "$last_text" ] && body="$last_text"
  fi
else
  body="$message"
fi

title="Claude Code ($(hostname))"

# tnotify (desktop notifications)
if command -v tnotify &> /dev/null; then
  if [ -n "$TMUX" ]; then
    tnotify -t "$title" "$body" > "$(tmux display-message -p '#{pane_tty}')"
  else
    tnotify -t "$title" "$body" --native
  fi
  exit 0
fi

# pushover (mobile notifications)
if [ -f ~/.pushoverrc ]; then
  source ~/.pushoverrc
  curl -s -F "token=$PUSHOVER_TOKEN" -F "user=$PUSHOVER_USER" -F "title=$title" -F "message=$body" \
    https://api.pushover.net/1/messages.json > /dev/null
  exit 0
fi
