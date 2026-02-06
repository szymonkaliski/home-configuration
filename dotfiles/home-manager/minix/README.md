# MINIX

## First-time setup

1. Install NixOS
2. Reboot into the fresh install
3. Clone this repo:
   ```bash
   mkdir -p ~/Projects
   nix --extra-experimental-features "nix-command flakes" run nixpkgs#git -- clone https://github.com/szymonkaliski/home-configuration.git ~/Projects/home-configuration
   ```
4. Run `./setup.sh` - it will copy `hardware-configuration.nix` from `/etc/nixos/` and run `nixos-rebuild switch`
5. Set up Tailscale: `sudo tailscale up`
6. From your Mac, copy your SSH key: `ssh-copy-id szymon@minix`

`/etc/nixos/` is not used after initial setup - the flake in this repo is the single source of truth.

## Updating

```bash
sudo nixos-rebuild switch --flake .#minix
```

## `hardware-configuration.nix`

This rarely needs updating - only regenerate if the hardware changes (new disk, new partition layout):

```bash
nixos-generate-config --show-hardware-config > minix/hardware-configuration.nix
```
