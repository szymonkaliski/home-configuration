#!/usr/bin/env bash

command=$(jq -r '.tool_input.command // ""')

# Strip leading cd ... && chains to get the actual command
actual="$command"
while [[ "$actual" =~ ^cd[[:space:]] ]]; do
  actual="${actual#*&&}"
  actual="${actual# }"
done

first_word="${actual%% *}"

case "$first_word" in
  cat|find|grep|head|hostname|ls|rg|tail|wc|which|file|stat|pwd|realpath|dirname|basename|readlink|diff|sort|uniq|tr|cut|less|more|du|df|env|printenv|uname|id|whoami|date)
    echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
    ;;
esac
