# home-configuration

Dotfiles and Nix configuration for multiple machines.
Run `hostname -s` to detect which one you're on.

## Key paths

- `bootstrap.sh <orchid|minix|berry>` - bare machine bootstrap: age key, home-manager symlink, system/home-manager switches
- `setup.sh <orchid|minix|berry>` - run from a new shell after bootstrap: vendored skills, npm, service auth, macOS extras
- `dotfiles/` - dotfiles used on various machines
- `bin/` - shell scripts symlinked to `~/.bin`

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

## Building berry's SD card

berry's SD card image can be generated on minix:

```sh
ssh minix '~/.bin/build-berry-sd-image'
```

A freshly flashed card boots with password `berry` (`initialPassword` in `nix/hosts/berry/system.nix`), which `setup.sh` replaces.
First boot needs ethernet, since wifi reads a sops secret that stays undecryptable until this host's age key is added to `.sops.yaml` and the secrets are re-encrypted.
A reflashed card also has a new host key, so `keys.berryHost` needs updating before minix can ssh in again.
