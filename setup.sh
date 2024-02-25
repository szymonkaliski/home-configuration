#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")"

function askBeforeRunning() {
  SCRIPT=$1

  read -p "$(tput setaf 3)Do you want to execute $SCRIPT?$(tput sgr0) (y/n) " RESP
  if [ "$RESP" == "y" ]; then
    ./$SCRIPT
  fi
}

HAS_NIX=$(command -v nix &> /dev/null && echo true || echo false)
DOTFILE_DIR="$(pwd)/dotfiles"
HOSTNAME="$(hostname)"

ln -si $DOTFILE_DIR/dircolors ~/.dircolors
ln -si $DOTFILE_DIR/gitconfig ~/.gitconfig
ln -si $DOTFILE_DIR/gitignore_global ~/.gitignore_global
ln -si $DOTFILE_DIR/ignore ~/.ignore
ln -si $DOTFILE_DIR/tmux.conf ~/.tmux.conf
ln -si $DOTFILE_DIR/vale.ini ~/.vale.ini
ln -si $DOTFILE_DIR/vim ~/.vim
ln -si $DOTFILE_DIR/vimrc ~/.vimrc
ln -si $DOTFILE_DIR/zprofile ~/.zprofile
ln -si $DOTFILE_DIR/zsh ~/.zsh
ln -si $DOTFILE_DIR/zshrc ~/.zshrc

ln -si $(pwd)/scripts ~/.bin

if [[ $HOSTNAME == "Orchid" ]]; then
  ln -si $DOTFILE_DIR/hammerspoon ~/.hammerspoon
  ln -si $DOTFILE_DIR/ghostty ~/.config/ghostty

  askBeforeRunning ./launchctls/reinstall-launchctls.sh
  askBeforeRunning ./terminfos/generate-terminfos.sh
fi

if [ -d ~/.vim/ ]; then
  curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  echo
  echo "On first (n)vim open execute :PlugInstall"
fi

if [ -d ~/.zsh/ ]; then
  mkdir -p ~/.zsh/plugins/
  pushd ~/.zsh/plugins/ > /dev/null

  git clone https://github.com/mafredri/z -b zsh-flock
  git clone https://github.com/chriskempson/base16-shell
  git clone https://github.com/hlissner/zsh-autopair
  git clone https://github.com/romkatv/gitstatus
  git clone https://github.com/zdharma-continuum/fast-syntax-highlighting
  git clone https://github.com/romkatv/zsh-defer

  popd > /dev/null
fi

if $HAS_NIX; then
  read -p "$(tput setaf 3)Do you want to set up home-manager?$(tput sgr0) (y/n) " RESP

  if [ "$RESP" == "y" ]; then
    ln -si $DOTFILE_DIR/home-manager ~/.config/home-manager
    cd ~/.config/home-manager

    nix flake update

    if [[ $HOSTNAME == "Orchid" ]]; then
      home-manager switch --flake .#szymon@orchid
    else
      echo
      echo "No home-manager configuration found for this machine!"
    fi
  fi
fi

