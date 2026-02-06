#!/usr/bin/env bash

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir')

hostname=$(hostname -s)
if [ "$hostname" = "Orchid" ]; then
  promptcolor="34"
elif [ "$hostname" = "minix" ]; then
  promptcolor="36"
else
  promptcolor="35"
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

  printf "\033[${promptcolor}m%s\033[0m \033[${branch_color}m%s\033[0m" "$pwd_display" "$branch"
else
  printf "\033[${promptcolor}m%s\033[0m" "$pwd_display"
fi
