export PATH="/usr/local/bin:/usr/bin:/bin/:/usr/local/sbin:/usr/sbin:/sbin"

# nix stuff, bin/ with slash at the end so the path gets cleaned up - nix sets its own too
if [ -d $HOME/.nix-profile/bin ]; then
  export PATH="$HOME/.nix-profile/bin/:$PATH"
fi

# necessary for npm/node from home-manager
# add to `.npmrc`: `prefix = ~/.npm`
if [ -d $HOME/.npm/bin ]; then
  export PATH="$HOME/.npm/bin:$PATH"
fi

# scripts and stuff symlinked from dotfiles
if [ -d $HOME/.bin ]; then
  export PATH="$HOME/.bin:$PATH"
fi

# go
if [ -d $HOME/Documents/Projects/go ]; then
  export GOPATH="$HOME/Documents/Projects/go"
  export GOBIN="$GOPATH/bin"
  export PATH="$GOBIN:$PATH"
fi

# clean paths
typeset -gU path

