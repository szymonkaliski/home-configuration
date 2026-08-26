#!/usr/bin/env bash

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir')

hostname=$(hostname -s)

# HOST_COLOR is exported by dotfiles/zsh/colors.zsh
promptcolor=$(( 30 + ${HOST_COLOR:-5} ))

vm_prefix=""
if [[ "$hostname" == vm-* ]]; then
  vm_prefix="$hostname "
fi

cwd_with_tilde=${cwd/#$HOME/\~}
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

model=$(echo "$input" | jq -r '.model.display_name // empty')

now=$(date +%s)

usage_segment() {
  local used=$1 reset=$2
  [ -z "$used" ] && return

  local p color secs d h m rem
  p=$(printf '%.0f' "$used")
  if [ "$p" -ge 80 ]; then color="31"
  elif [ "$p" -ge 50 ]; then color="33"
  else color="32"; fi

  if [ -z "$reset" ]; then
    printf '\033[%sm%d%%\033[0m' "$color" "$p"
    return
  fi

  secs=$(( reset - now ))
  [ "$secs" -lt 0 ] && secs=0
  d=$(( secs / 86400 )); h=$(( secs % 86400 / 3600 )); m=$(( secs % 3600 / 60 ))
  if [ "$d" -gt 0 ] && [ "$h" -gt 0 ]; then rem="${d}d${h}h"
  elif [ "$d" -gt 0 ]; then rem="${d}d"
  elif [ "$h" -gt 0 ] && [ "$m" -gt 0 ]; then rem="${h}h${m}m"
  elif [ "$h" -gt 0 ]; then rem="${h}h"
  elif [ "$m" -gt 0 ]; then rem="${m}m"
  else rem="<1m"; fi

  printf '\033[%sm%d%%\033[0m %s' "$color" "$p" "$rem"
}

usage=""
append_usage() {
  [ -z "$1" ] && return
  if [ -z "$usage" ]; then usage="$1"; else usage="$usage / $1"; fi
}

append_usage "$model"
for window in five_hour seven_day; do
  append_usage "$(usage_segment \
    "$(echo "$input" | jq -r ".rate_limits.${window}.used_percentage // empty")" \
    "$(echo "$input" | jq -r ".rate_limits.${window}.resets_at // empty")")"
done
[ -n "$usage" ] && usage=" $usage"

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
