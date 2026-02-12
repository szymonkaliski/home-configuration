if hash nvim 2> /dev/null; then
  export EDITOR="nvim"
else
  export EDITOR="vim"
fi

export MOSH_TITLE_NOPREFIX=1
export NPM_CONFIG_PREFIX="$HOME/.npm"

export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
export FZF_DEFAULT_OPTS="--no-separator --reverse --inline-info --cycle --history=$HOME/.fzfhistory --history-size=1000 --no-bold --color=fg+:007,bg+:018,hl:016,hl+:016 --color=prompt:008,marker:008,pointer:008,spinner:018,info:008,pointer:018"

if [ -d $HOME/.terminfo ]; then
  export TERMINFO=$HOME/.terminfo/
fi

# SSH doesn't forward COLORTERM, so set it for true color support over SSH
if [[ -z "$COLORTERM" && "$TERM" == *256color* ]]; then
  export COLORTERM=truecolor
fi

if [ -d "$HOME/Documents/Projects" ]; then
  export PROJECTS_PATH="$HOME/Documents/Projects"
elif [ -d "$HOME/Projects" ]; then
  export PROJECTS_PATH="$HOME/Projects"
fi

if [ -d "$HOME/Library/CloudStorage/Dropbox" ]; then
  export DROPBOX_PATH="$HOME/Library/CloudStorage/Dropbox"
elif [ -d "$HOME/Dropbox" ]; then
  export DROPBOX_PATH="$HOME/Dropbox"
fi

if [ -n "$DROPBOX_PATH" ]; then
  export WIKI_PATH="$DROPBOX_PATH/Wiki"
  export SCREENSHOTS_PATH="$DROPBOX_PATH/Screenshots"
fi
