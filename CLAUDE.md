# home-configuration

Dotfiles and Nix configuration for multiple machines.
Run `hostname -s` to detect which one you're on.

## Key paths

- `setup.sh` - symlinks dotfiles into `$HOME`, sets up home-manager, etc.
- `dotfiles/home-manager/` - Nix flakes for different machines
- `dotfiles/claude/` - Claude Code settings, skills, hooks
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
