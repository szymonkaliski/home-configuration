#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

DOTFILE_DIR="$(pwd)/dotfiles"

HOST="${1:-}"

case "$HOST" in
  orchid | minix | berry) ;;
  *)
    echo "Usage: ${BASH_SOURCE[0]##*/} <orchid|minix|berry>"
    exit 1
    ;;
esac

# safety check if we do have a hostname and it differs from requested one
if [ "$HOST" != "$(hostname -s)" ]; then
  read -rp "$(tput setaf 3)This machine reports '$(hostname -s)' but you asked for '$HOST'. Continue?$(tput sgr0) (y/n) " RESP

  if [ "$RESP" != "y" ]; then
    echo "Aborting."
    exit 0
  fi
fi

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

function ageKeygenWrapped() {
  if command -v age-keygen &> /dev/null; then
    age-keygen "$@"
  elif command -v nix &> /dev/null; then
    nix --extra-experimental-features "nix-command flakes" shell nixpkgs#age --command age-keygen "$@"
  else
    echo "Error: age is not installed and nix is not available as fallback"
    exit 1
  fi
}

function askBeforeRunning() {
  SCRIPT=$1

  read -rp "$(tput setaf 3)Do you want to execute $SCRIPT?$(tput sgr0) (y/n) " RESP
  if [ "$RESP" == "y" ]; then
    "./$SCRIPT"
  fi
}

# every host decrypts secrets/shared.yaml, so a new one needs its own age
# identity in .sops.yaml and the file re-encrypted from a host that can already
# read it - re-encrypting requires decrypting first
if [[ "$(uname)" == "Darwin" ]]; then
  AGE_KEY_FILE="$HOME/Library/Application Support/sops/age/keys.txt"
else
  AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
fi

if [ ! -f "$AGE_KEY_FILE" ]; then
  read -rp "$(tput setaf 3)No age key on this host. Generate one?$(tput sgr0) (y/n) " RESP

  if [ "$RESP" == "y" ]; then
    mkdir -p "$(dirname "$AGE_KEY_FILE")"
    ageKeygenWrapped -o "$AGE_KEY_FILE"

    echo
    echo "age public key - add to .sops.yaml, then 'sops updatekeys' every secrets file:"
    ageKeygenWrapped -y "$AGE_KEY_FILE"
    echo
    read -rp "$(tput setaf 3)Press enter once that is pushed$(tput sgr0) " RESP

    gitWrapped pull
  fi
fi

if command -v nix &> /dev/null; then
  read -rp "$(tput setaf 3)Do you want to set up home-manager?$(tput sgr0) (y/n) " RESP

  if [ "$RESP" == "y" ]; then
    ln -sni "$DOTFILE_DIR/nix" ~/.config/home-manager
    pushd ~/.config/home-manager || exit

    if [[ $HOST == "orchid" ]]; then
      nix run home-manager -- switch --flake .#szymon@orchid
    elif [[ $HOST == "berry" ]]; then
      sudo nixos-rebuild switch --flake .#berry
      nix run home-manager -- switch --flake .#szymon@berry
    elif [[ $HOST == "minix" ]]; then
      if [ -f /etc/nixos/hardware-configuration.nix ]; then
        cp /etc/nixos/hardware-configuration.nix "$DOTFILE_DIR/nix/hosts/minix/hardware-configuration.nix"
        gitWrapped add "$DOTFILE_DIR/nix/hosts/minix/hardware-configuration.nix"
        echo "Copied hardware-configuration.nix from /etc/nixos/"
      fi

      sudo nixos-rebuild switch --flake .#minix
      nix run home-manager -- switch --flake .#szymon@minix
    fi

    popd || exit
  fi
fi

if [ -d ~/.vim/ ]; then
  curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  echo
  echo "On first (n)vim open execute :PlugInstall"
fi

if [ -d ~/.zsh/ ]; then
  mkdir -p ~/.zsh/plugins/
  pushd ~/.zsh/plugins/ > /dev/null || exit

  gitWrapped clone https://github.com/mafredri/z -b zsh-flock
  gitWrapped clone https://github.com/chriskempson/base16-shell
  gitWrapped clone https://github.com/hlissner/zsh-autopair
  gitWrapped clone https://github.com/romkatv/gitstatus
  gitWrapped clone https://github.com/zdharma-continuum/fast-syntax-highlighting
  gitWrapped clone https://github.com/romkatv/zsh-defer

  popd > /dev/null || exit
fi

mkdir -p "$DOTFILE_DIR/agents/skills-vendor"
pushd "$DOTFILE_DIR/agents/skills-vendor" > /dev/null || exit

gitWrapped clone https://github.com/mattpocock/skills mattpocock-skills

popd > /dev/null || exit

if command -v npm &> /dev/null; then
  askBeforeRunning ./scripts/npm-sync
fi

if [[ $HOST == "orchid" ]]; then
  askBeforeRunning ./launchctls/reinstall-launchctls.sh
  askBeforeRunning ./terminfos/generate-terminfos.sh
  askBeforeRunning ./scripts/setup-osx

  # determinate nix encrypts the /nix volume if the boot disk has FileVault on,
  # which causes a password prompt at every boot, /nix store is public anyway
  # so we can decrypt it
  if [[ "$(diskutil info 'Nix Store' 2>/dev/null | awk -F': +' '/FileVault:/{print $2}')" == "Yes" ]]; then
    read -rp "$(tput setaf 3)Decrypt the Nix Store volume?$(tput sgr0) (y/n) " RESP
    if [ "$RESP" == "y" ]; then
      security find-generic-password -s "Nix Store" -w /Library/Keychains/System.keychain | sudo diskutil apfs decryptVolume "Nix Store" -stdinpassphrase
    fi
  fi
fi

echo
echo "Done! Restart your machine to make sure everything is loaded correctly."
