autoload -Uz colors

# init colors
colors

# grep
export GREP_COLOR=34

# export GREP_COLORS="mt=34" # blue text
export GREP_COLORS="mt=48;5;16;38;5;0" # orange background, black text

# dircolors
load_dircolors() {
  if [ -f ~/.dircolors ]; then
    eval $(dircolors -b ~/.dircolors)
  fi
}
zsh-defer -t 1.0 +1 load_dircolors

# grc for commands
if hash grc 2> /dev/null; then
  alias colourify="grc -es --colour=auto"

  alias diff="colourify diff"
  alias make="colourify make"
  alias gcc="colourify gcc"
  alias g++="colourify g++"
  alias ld="colourify ld"
  alias netstat="colourify netstat"
  alias ping="colourify ping"
  alias traceroute="colourify traceroute"
fi

# base16 for shell colors
if [ -d ~/.zsh/plugins/base16-shell/ ]; then
  export BASE16_SHELL=~/.zsh/plugins/base16-shell

  # update all opened terms on mac os by sending the color values directly to the tty
  # TODO: this could be extended to support linux
  # reference:
  # - https://writing.grantcuster.com/posts/2020-07-12-swapping-color-schemes-across-all-terminals-and-vim-with-pywal-and-base16/
  # - https://github.com/dylanaraps/pywal/blob/42ad8f014dfe11defe094a3ce33b60f7ec27b83b/pywal/sequences.py#L83
  # base16_send() {
  #   # this is still broken!
  #   # something about different escape codes for tmux and non-tmux
  #   for tty in /dev/ttys00[0-9]*; do
  #     if tmux list-clients | grep -q $tty; then
  #       TMUX="FORCE_TMUX" base16_load > $tty
  #     else
  #       TMUX="" base16_load > $tty
  #     fi
  #   done
  # }

  base16_load() {
    source ~/.base16_theme
  }

  base16() {
    local BASE16_DIR="$BASE16_SHELL/scripts"
    local THEME=$1

    if [ -z "$THEME" ]; then
      THEME=$(cd "$BASE16_DIR" && command ls base16-*.sh | sed 's/base16-\(.*\)\.sh/\1/' | fzf --preview-window=up,1 --style=minimal --preview '
        FILE='$BASE16_DIR'/base16-{}.sh
        grep "^color[0-9A-Fa-f]*=\"" "$FILE" | head -16 | while IFS="=" read -r name val; do
          hex=$(echo "$val" | tr -d \"/\")
          r=$((16#${hex:0:2}))
          g=$((16#${hex:2:2}))
          b=$((16#${hex:4:2}))
          printf "\033[48;2;%d;%d;%dm    \033[0m" "$r" "$g" "$b"
        done
      ')

      [ -z "$THEME" ] && return
    fi

    local FILENAME="base16-$THEME.sh"

    rm -f ~/.base16_theme > /dev/null
    ln -s $BASE16_SHELL/scripts/$FILENAME ~/.base16_theme
    echo -e "colorscheme base16-$THEME" > ~/.vimrc_background

    if [ -d ~/.config/ghostty ]; then
      local BG_COLOR="#$(cat ~/.base16_theme | grep "color_background=" | cut -d '"' -f2 | tr -d '/')"
      local FG_COLOR="#$(cat ~/.base16_theme | grep "color_foreground=" | cut -d '"' -f2 | tr -d '/')"
      sed -i '' -e "s/^background = .*/background = $BG_COLOR/" ~/.config/ghostty/config
      sed -i '' -e "s/^foreground = .*/foreground = $FG_COLOR/" ~/.config/ghostty/config
    fi

    base16_load
  }

  # source only if we don't have BASE16_THEME set
  if [ -f ~/.base16_theme ]; then
    local CURRENT_BASE16_THEME="$(basename $(realpath ~/.base16_theme) .sh)"

    if [ -z $BASE16_THEME ] || [ $CURRENT_BASE16_THEME != $BASE16_THEME ]; then
      base16_load
    fi
  fi
fi

