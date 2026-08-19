# z with fzf
j() {
  if [[ -z "$*" ]]; then
    cd "$(_z -l 2>&1 | sed -n 's/^[ 0-9.,]*//p' | grep -v '^common:' | tac | fzf --tiebreak=index --prompt='jump > ')"
  else
    _z "$@"
  fi
}

# edit files in editor
fe() {
  local preview="bat --style=plain --color=always --theme=base16-256 --line-range=:200 {}"

  fzf --multi --select-1 --exit-0 --query="$1" --prompt="files > " --preview=$preview | tr "\n" "\0" | xargs -0 -o v
}

# open file
fo() {
  local file=""

  file="$(fzf --select-1 --exit-0 --query="$1" --prompt="open > ")"

  [ -n "$file" ] && open "$file"
}

# cd to directory
fcd() {
  local preview="tree -aC --dirsfirst {}"
  local dir=""

  if hash fd 2> /dev/null; then
    dir="$(fd --type d | fzf --select-1 --exit-0 --query="$1" --prompt='dir > ' --preview=$preview)"
  else
    dir="$(find ${1:-*} -path '*/\.*' -prune -o -type d -print 2> /dev/null | fzf --select-1 --exit-0 --query="$1" --prompt='dir > ' --preview=$preview)"
  fi

  [ -n "$dir" ] && cd "$dir"
}

# search through history
fh() {
  print -z -- "$(fc -l 1 | fzf --tac --tiebreak=index --query="$1" --prompt="history > " | sed 's/ *[0-9]* *//')"
}

# kill process
fkill() {
  ps -ef | fzf --header-lines=1 --multi --query="$1" --prompt="kill > " | awk '{ print $2 }' | xargs -r kill -9
}

# checkout git commit
fcom() {
  local commits=$(git log --pretty=format:"%h%x09 %cr%x09 %s" --decorate --reverse)
  local commit=$(echo "$commits" | fzf --tac --tiebreak=index --exact)

  if [ ! -z $commit ]; then
    git checkout $(echo "$commit" | cut -d " " -f1)
  fi
}

# checkout local git branch
fbr() {
  local branches=$(git branch --sort=-committerdate | grep -v HEAD)
  local branch=$(echo "$branches" | fzf --tiebreak=index)

  [ -n "$branch" ] && git checkout $(echo "$branch" | sed "s/.* //")
}
