export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"

# nixos paths
if [ -d /run/current-system/sw/bin ]; then
  export PATH="/run/current-system/sw/bin:$PATH"
fi
if [ -d /run/wrappers/bin ]; then
  export PATH="/run/wrappers/bin:$PATH"
fi

# nix-daemon.sh (sourced from /etc/zshrc on macOS) prepends these two as well, but returns early in nested shells
for dir in /nix/var/nix/profiles/default/bin $HOME/.nix-profile/bin; do
  if [ -d $dir ]; then
    export PATH="$dir:$PATH"
  fi
done

if [ -d $HOME/.npm/bin ]; then
  export PATH="$HOME/.npm/bin:$PATH"
fi

# claude code's native installer drops its launcher here
if [ -d $HOME/.local/bin ]; then
  export PATH="$HOME/.local/bin:$PATH"
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
