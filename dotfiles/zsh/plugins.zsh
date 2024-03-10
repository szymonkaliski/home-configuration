# direnv
load_direnv() {
  if hash direnv 2> /dev/null; then
    eval "$(direnv hook zsh)"
fi
}

# z for better jumps
load_z() {
  if [ ! -f ~/.zsh/plugins/z/z.sh ]; then
    exit
  fi

  source ~/.zsh/plugins/z/z.sh
}

# better pairs
load_autopair() {
  if [ ! -f ~/.zsh/plugins/zsh-autopair/autopair.zsh ]; then
    exit
  fi

  source ~/.zsh/plugins/zsh-autopair/autopair.zsh
}

# live command highlighting like fish, but faster than zsh-syntax-highlight
load_syntax_highlight() {
  if [ ! -f ~/.zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh ]; then
    exit
  fi

  source ~/.zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh

  FAST_HIGHLIGHT_STYLES[precommand]='fg=magenta'
  FAST_HIGHLIGHT_STYLES[commandseparator]='fg=yellow'
  FAST_HIGHLIGHT_STYLES[path]='fg=default'
  FAST_HIGHLIGHT_STYLES[path-to-dir]='fg=default'
  FAST_HIGHLIGHT_STYLES[single-hyphen-option]='fg=yellow'
  FAST_HIGHLIGHT_STYLES[double-hyphen-option]='fg=yellow'
  FAST_HIGHLIGHT_STYLES[back-quoted-argument]='fg=magenta'
  FAST_HIGHLIGHT_STYLES[single-quoted-argument]='fg=red'
  FAST_HIGHLIGHT_STYLES[double-quoted-argument]='fg=red'
  FAST_HIGHLIGHT_STYLES[variable]='fg=red'
  FAST_HIGHLIGHT_STYLES[global-alias]='fg=magenta'

  FAST_HIGHLIGHT[no_check_paths]=1
  FAST_HIGHLIGHT[use_brackets]=1
  FAST_HIGHLIGHT[use_async]=1
}

# gitstatus
load_gitstatus() {
  if [ !-f ~/.zsh/plugins/gitstatus/gitstatus.plugin.zsh ]; then
    exit
  fi

  source ~/.zsh/plugins/gitstatus/gitstatus.plugin.zsh
  gitstatus_stop "GITSTATUS" && gitstatus_start -s -1 -u -1 -c -1 -d -1 -t 16 "GITSTATUS"

  setup_git_prompt_status
}

load_z # I often want to jump somewhere immediately when opening a shell
load_direnv # same for direnv

# deferred loading
zsh-defer -t 0.5 load_autopair
zsh-defer -t 0.5 load_syntax_highlight
zsh-defer -t 1.0 load_gitstatus

