#!/usr/bin/env bash

# brings a bare machine up to a working shell environment:
# age identity, home-manager symlink, system and home-manager switches

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

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
  read -rp "$(tput setaf 3)This machine reports '$(hostname -s)' but you asked for '$HOST'. Continue?$(tput sgr0) (y/N) " RESP

  if [ "$RESP" != "y" ] && [ "$RESP" != "Y" ]; then
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

function sshKeygenWrapped() {
  if command -v ssh-keygen &> /dev/null; then
    ssh-keygen "$@"
  elif command -v nix &> /dev/null; then
    nix --extra-experimental-features "nix-command flakes" shell nixpkgs#openssh --command ssh-keygen "$@"
  else
    echo "Error: ssh-keygen is not installed and nix is not available as fallback"
    exit 1
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
  read -rp "$(tput setaf 3)No age key on this host. Generate one?$(tput sgr0) (y/N) " RESP

  if [ "$RESP" == "y" ] || [ "$RESP" == "Y" ]; then
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

# the other hosts authorize this one by public key, so they need it in
# nix/keys.nix and a rebuild before they will accept a connection from here
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  read -rp "$(tput setaf 3)No ssh key on this host. Generate one?$(tput sgr0) (y/N) " RESP

  if [ "$RESP" == "y" ] || [ "$RESP" == "Y" ]; then
    sshKeygenWrapped -t ed25519 -C "szymon@$HOST" -f "$HOME/.ssh/id_ed25519" -N ""

    echo
    echo "ssh public key - add to nix/keys.nix as '$HOST', then rebuild the other hosts:"
    cat "$HOME/.ssh/id_ed25519.pub"
    echo
    echo "ssh host key - add to nix/keys.nix as '${HOST}Host' if another host pins it:"
    cat /etc/ssh/ssh_host_ed25519_key.pub
    echo
    read -rp "$(tput setaf 3)Press enter once that is pushed$(tput sgr0) " RESP

    gitWrapped pull
  fi
fi

if command -v nix &> /dev/null; then
  read -rp "$(tput setaf 3)Do you want to set up home-manager?$(tput sgr0) (y/N) " RESP

  if [ "$RESP" == "y" ] || [ "$RESP" == "Y" ]; then
    ln -sni "$(pwd)" ~/.config/home-manager
    pushd ~/.config/home-manager || exit

    if [[ $HOST == "orchid" ]]; then
      nix run home-manager -- switch --flake .#szymon@orchid
    elif [[ $HOST == "berry" ]]; then
      sudo nixos-rebuild switch --flake .#berry
      nix run home-manager -- switch --flake .#szymon@berry
    elif [[ $HOST == "minix" ]]; then
      if [ -f /etc/nixos/hardware-configuration.nix ]; then
        cp /etc/nixos/hardware-configuration.nix nix/hosts/minix/hardware-configuration.nix
        gitWrapped add nix/hosts/minix/hardware-configuration.nix
        echo "Copied hardware-configuration.nix from /etc/nixos/"
      fi

      sudo nixos-rebuild switch --flake .#minix
      nix run home-manager -- switch --flake .#szymon@minix
    fi

    popd || exit
  fi
fi

echo
echo "Bootstrap done!"
echo
echo "$(tput setaf 3)Start a new shell$(tput sgr0) so the freshly linked environment is loaded, then run:"
echo "  ./setup.sh $HOST"
