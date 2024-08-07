if hash nvim 2> /dev/null; then
  export EDITOR="nvim"
else
  export EDITOR="vim"
fi

export MOSH_TITLE_NOPREFIX=1

export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
export FZF_DEFAULT_OPTS="--no-separator --reverse --inline-info --cycle --history=$HOME/.fzfhistory --history-size=1000 --no-bold --color=fg+:007,bg+:018,hl:016,hl+:016 --color=prompt:008,marker:008,pointer:008,spinner:018,info:008,pointer:018"

if [ -d $HOME/.terminfo ]; then
  export TERMINFO=$HOME/.terminfo/
fi

