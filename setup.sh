#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")"

DOTFILE_DIR="$(pwd)/dotfiles"
HOSTNAME="$(hostname -s)"

function gitWrapped() {
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

if [[ $HOSTNAME == "nixos" ]]; then
  read -p "$(tput setaf 3)Hostname is 'nixos' (fresh install?). Set up as minix?$(tput sgr0) (y/n) " RESP
  if [ "$RESP" != "y" ]; then
    echo "Aborting."
    exit 0
  fi
fi

if command -v nix &> /dev/null; then
  read -p "$(tput setaf 3)Do you want to set up home-manager?$(tput sgr0) (y/n) " RESP

  if [ "$RESP" == "y" ]; then
    ln -sni $DOTFILE_DIR/nix ~/.config/home-manager
    pushd ~/.config/home-manager

    if [[ $HOSTNAME == "orchid" ]]; then
      nix run home-manager -- switch --flake .#szymon@orchid
    elif [[ $HOSTNAME == "minix" || $HOSTNAME == "nixos" ]]; then
      if [ -f /etc/nixos/hardware-configuration.nix ]; then
        cp /etc/nixos/hardware-configuration.nix $DOTFILE_DIR/nix/hosts/minix/hardware-configuration.nix
        gitWrapped add $DOTFILE_DIR/nix/hosts/minix/hardware-configuration.nix
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

  gitWrapped clone https://github.com/mafredri/z -b zsh-flock
  gitWrapped clone https://github.com/chriskempson/base16-shell
  gitWrapped clone https://github.com/hlissner/zsh-autopair
  gitWrapped clone https://github.com/romkatv/gitstatus
  gitWrapped clone https://github.com/zdharma-continuum/fast-syntax-highlighting
  gitWrapped clone https://github.com/romkatv/zsh-defer

  popd > /dev/null
fi

if command -v npm &> /dev/null; then
  askBeforeRunning ./scripts/npm-install-global-packages
fi

if [[ $HOSTNAME == "orchid" ]]; then
  askBeforeRunning ./launchctls/reinstall-launchctls.sh
  askBeforeRunning ./terminfos/generate-terminfos.sh
  askBeforeRunning ./scripts/setup-osx
  askBeforeRunning ./scripts/npm-link-global-packages

  # determinate nix encrypts the /nix volume if the boot disk has FileVault on,
  # which causes a password prompt at every boot, /nix store is public anyway
  # so we can decrypt it
  if [[ "$(diskutil info 'Nix Store' 2>/dev/null | awk -F': +' '/FileVault:/{print $2}')" == "Yes" ]]; then
    read -p "$(tput setaf 3)Decrypt the Nix Store volume?$(tput sgr0) (y/n) " RESP
    if [ "$RESP" == "y" ]; then
      security find-generic-password -s "Nix Store" -w /Library/Keychains/System.keychain | sudo diskutil apfs decryptVolume "Nix Store" -stdinpassphrase
    fi
  fi
fi

echo
echo "Done! Restart your machine to make sure everything is loaded correctly."

