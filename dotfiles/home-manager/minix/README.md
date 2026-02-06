# MINIX

## First-time setup

1. Install NixOS
2. Reboot into the fresh install
3. Clone this repo:
   ```bash
   mkdir -p ~/Projects
   nix --extra-experimental-features "nix-command flakes" run nixpkgs#git -- clone https://github.com/szymonkaliski/home-configuration.git ~/Projects/home-configuration
   ```
4. Run `./setup.sh` - it will copy `hardware-configuration.nix` from `/etc/nixos/`, git-track it, and run `nixos-rebuild switch`
5. Restart: `sudo reboot`
6. Set up Tailscale: `sudo tailscale up --advertise-exit-node`

`/etc/nixos/` is not used after initial setup - the flake in this repo is the single source of truth.

## Updating

```bash
update-all
```

To only rebuild home-manager (without updating plugins, npm, etc.):

```bash
nix run home-manager -- switch --flake .#szymon@minix
```

To rebuild the full NixOS system (needed for changes to `system.nix`):

```bash
sudo nixos-rebuild switch --flake .#minix
```

## `hardware-configuration.nix`

This rarely needs updating - only regenerate if the hardware changes (new disk, new partition layout):

```bash
nixos-generate-config --show-hardware-config > minix/hardware-configuration.nix
```
