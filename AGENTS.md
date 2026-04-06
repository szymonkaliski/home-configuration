# home-configuration

Dotfiles and Nix configuration for multiple machines.
Run `hostname -s` to detect which one you're on.

## Key paths

- `setup.sh` - bootstrap setup for Nix, home-manager, etc.
- `dotfiles/` - dotfiles used on various machines
- `scripts/` - shell scripts symlinked to `~/.bin`

## Rebuild commands

NixOS - rebuilds system:

```sh
sudo nixos-rebuild switch --flake ~/.config/home-manager#minix
```

NixOS - home-manager:

```sh
home-manager switch --flake ~/.config/home-manager#szymon@minix
```

macOS - home-manager:

```sh
home-manager switch --flake ~/.config/home-manager#szymon@orchid
```

