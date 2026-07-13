#!/usr/bin/env bash

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir')

hostname=$(hostname -s)
if [ "$hostname" = "orchid" ]; then
  promptcolor="34"
elif [ "$hostname" = "minix" ]; then
  promptcolor="33"
else
  promptcolor="35"
fi

vm_prefix=""
if [[ "$hostname" == vm-* ]]; then
  vm_prefix="$hostname "
fi

if [ "$(whoami)" = "root" ]; then
  promptcolor="31"
fi

cwd_with_tilde=$(echo "$cwd" | sed "s|^$HOME|~|")
pwd_display=$(echo "$cwd_with_tilde" | awk -F'/' '{
  n = NF
  if (n <= 3) {
    for (i=1; i<=NF; i++) {
      if ($i != "") printf "%s%s", (i==1?"":"/"), $i
    }
  } else {
    for (i=n-2; i<=NF; i++) {
      printf "%s%s", (i==n-2?"":"/"), $i
    }
  }
}')

if [ ${#pwd_display} -gt 50 ]; then
  pwd_display="...${pwd_display: -47}"
fi

export GIT_OPTIONAL_LOCKS=0

usage=""
model=$(echo "$input" | jq -r '.model.display_name // empty')
five_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
if [ -n "$five_used" ]; then
  p=$(printf '%.0f' "$five_used")
  if [ "$p" -ge 80 ]; then color="31"
  elif [ "$p" -ge 50 ]; then color="33"
  else color="32"; fi
  reset_time=$(date -d "@$five_reset" +%H:%M 2>/dev/null || date -r "$five_reset" +%H:%M 2>/dev/null)
  if [ -n "$reset_time" ]; then
    usage=$(printf " \033[${color}m%02d%%\033[0m until %s" "$p" "$reset_time")
  else
    usage=$(printf " \033[${color}m%02d%%\033[0m" "$p")
  fi
fi

if [ -n "$model" ]; then
  usage=$(printf " %s%s" "$model" "$usage")
fi

if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

  if [ ${#branch} -gt 20 ]; then
    branch="...${branch: -17}"
  fi

  if git -C "$cwd" diff-index --quiet HEAD -- 2>/dev/null && [ -z "$(git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null)" ]; then
    branch_color="32"
  else
    branch_color="31"
  fi

  left=$(printf "%s\033[${promptcolor}m%s\033[0m \033[${branch_color}m%s\033[0m" "$vm_prefix" "$pwd_display" "$branch")
else
  left=$(printf "%s\033[${promptcolor}m%s\033[0m" "$vm_prefix" "$pwd_display")
fi

if [ -n "$usage" ] && [ -n "$COLUMNS" ]; then
  esc=$(printf '\033')
  strip="s/${esc}\[[0-9;]*m//g"
  left_len=$(printf '%s' "$left" | sed "$strip" | wc -m | tr -d ' ')
  usage_len=$(printf '%s' "$usage" | sed "$strip" | wc -m | tr -d ' ')
  margin=3
  pad=$(( COLUMNS - left_len - usage_len - margin ))
  if [ "$pad" -ge 1 ]; then
    printf '%s%*s%s' "$left" "$pad" "" "$usage"
  else
    printf '%s%s' "$left" "$usage"
  fi
else
  printf '%s%s' "$left" "$usage"
fi
