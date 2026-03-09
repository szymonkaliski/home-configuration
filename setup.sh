#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")"

DOTFILE_DIR="$(pwd)/dotfiles"
HOSTNAME="$(hostname -s)"

if [[ $HOSTNAME == "nixos" ]]; then
  read -p "$(tput setaf 3)Hostname is 'nixos' (fresh install?). Set up as minix?$(tput sgr0) (y/n) " RESP
  if [ "$RESP" != "y" ]; then
    echo "Aborting."
    exit 0
  fi
fi

function gitwrapped() {
  if command -v git &> /dev/null; then
    git "$@"
  elif command -v nix &> /dev/null; then
    nix --extra-experimental-features "nix-command flakes" run nixpkgs#git -- "$@"
  else
    echo "Error: git is not installed and nix is not available as fallback"
    exit 1
  fi
}

function askBeforeRunning() {
  SCRIPT=$1

  read -p "$(tput setaf 3)Do you want to execute $SCRIPT?$(tput sgr0) (y/n) " RESP
  if [ "$RESP" == "y" ]; then
    ./$SCRIPT
  fi
}

if [[ $HOSTNAME == "orchid" ]]; then
  askBeforeRunning ./launchctls/reinstall-launchctls.sh
  askBeforeRunning ./terminfos/generate-terminfos.sh
  askBeforeRunning ./scripts/setup-osx
fi

if command -v nix &> /dev/null; then
  read -p "$(tput setaf 3)Do you want to set up home-manager?$(tput sgr0) (y/n) " RESP

  if [ "$RESP" == "y" ]; then
    ln -sni $DOTFILE_DIR/nix ~/.config/home-manager
    pushd ~/.config/home-manager

    if [[ $HOSTNAME == "orchid" ]]; then
      home-manager switch --flake .#szymon@orchid
    elif [[ $HOSTNAME == "minix" || $HOSTNAME == "nixos" ]]; then
      if [ -f /etc/nixos/hardware-configuration.nix ]; then
        cp /etc/nixos/hardware-configuration.nix $DOTFILE_DIR/nix/hosts/minix/hardware-configuration.nix
        gitwrapped add $DOTFILE_DIR/nix/hosts/minix/hardware-configuration.nix
        echo "Copied hardware-configuration.nix from /etc/nixos/"
      fi
      sudo nixos-rebuild switch --flake .#minix
    else
      echo
      echo "No home-manager configuration found for this machine!"
    fi

    popd
  fi
fi

if [ -d ~/.vim/ ]; then
  curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  echo
  echo "On first (n)vim open execute :PlugInstall"
fi

if [ -d ~/.zsh/ ]; then
  mkdir -p ~/.zsh/plugins/
  pushd ~/.zsh/plugins/ > /dev/null

  gitwrapped clone https://github.com/mafredri/z -b zsh-flock
  gitwrapped clone https://github.com/chriskempson/base16-shell
  gitwrapped clone https://github.com/hlissner/zsh-autopair
  gitwrapped clone https://github.com/romkatv/gitstatus
  gitwrapped clone https://github.com/zdharma-continuum/fast-syntax-highlighting
  gitwrapped clone https://github.com/romkatv/zsh-defer

  popd > /dev/null
fi

if command -v npm &> /dev/null; then
  askBeforeRunning ./scripts/npm-install-global-packages
  askBeforeRunning ./scripts/npm-link-global-packages
fi

echo
echo "Done! Restart your machine to make sure everything is loaded correctly."

