#!/usr/bin/env bash

MAX_LINES=10000

for log in ~/Library/Logs/com.szymonkaliski.*.log; do
  [ -f "$log" ] || continue
  tail -n "$MAX_LINES" "$log" > "$log.tmp" && mv "$log.tmp" "$log"
done
