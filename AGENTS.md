# home-configuration

Dotfiles and Nix configuration for multiple machines.
Run `hostname -s` to detect which one you're on.

## Key paths

- `bootstrap.sh <orchid|minix|berry>` - bare machine bootstrap: age key, home-manager symlink, system/home-manager switches
- `setup.sh <orchid|minix|berry>` - run from a new shell after bootstrap: vendored skills, npm, service auth, macOS extras
- `dotfiles/agents/` - AGENTS.md and skills shared by claude and agy (`~/.claude/CLAUDE.md` and `~/.gemini/config/AGENTS.md` link here), linked per skill by `nix/modules/home/common.nix` - a new skill needs `git add` and `home-manager switch`
- `bin/` - shell scripts symlinked to `~/.bin`
- `nix/hosts/<host>/README.md` - per-host setup (minix first install, berry SD card)

## Nix overrides

When adding an override that is only needed until upstream catches up (package pulled from unstable, vendored patch, version pin), wrap it in `lib.warnIf` with a condition that tests whether it is still needed, so evaluation itself warns when it can be dropped.

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

Raspberry Pi - system and home-manager:

```sh
sudo nixos-rebuild switch --flake ~/.config/home-manager#berry
home-manager switch --flake ~/.config/home-manager#szymon@berry
```
