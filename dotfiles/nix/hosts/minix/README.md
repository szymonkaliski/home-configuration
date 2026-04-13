# MINIX

## First-time setup

1. Install NixOS
2. Reboot into the fresh install
3. Clone this repo:
   ```bash
   mkdir -p ~/Projects
   nix --extra-experimental-features "nix-command flakes" run nixpkgs#git -- clone https://github.com/szymonkaliski/home-configuration.git ~/Projects/home-configuration
   ```
4. Run `./setup.sh` - it copies `hardware-configuration.nix` from `/etc/nixos/`, git-tracks it, and runs `nixos-rebuild switch`. The first rebuild will fail until secrets are in place (next step).
5. Set up SOPS secrets (see [Secrets](#secrets) below)
6. Re-run the rebuild: `sudo nixos-rebuild switch --flake .#minix`

## Updating

```bash
update-all
```

Home-manager only:

```bash
home-manager switch --flake .#szymon@minix
```

Full NixOS rebuild:

```bash
sudo nixos-rebuild switch --flake .#minix
```

Regenerate hardware config (only if hardware changes):

```bash
nixos-generate-config --show-hardware-config > minix/hardware-configuration.nix
```

## Secrets

All credentials are encrypted with [sops-nix](https://github.com/Mic92/sops-nix) using age keys.

Encrypted blobs live in `dotfiles/nix/secrets/*.yaml` and are committed to the repo.
The age private key is per-machine and stays at `~/.config/sops/age/keys.txt`.

### First-time setup

1. Use [age](https://github.com/FiloSottile/age) via nix-shell, generate the machine key:
   ```bash
   mkdir -p ~/.config/sops/age
   nix shell nixpkgs#age -c age-keygen -o ~/.config/sops/age/keys.txt
   nix shell nixpkgs#age -c age-keygen -y ~/.config/sops/age/keys.txt
   # this prints the public key: age1...
   ```
2. Add the new pubkey to `dotfiles/nix/.sops.yaml` under `keys:` and reference it from the appropriate `creation_rules` `key_groups`.
3. Re-encrypt the existing yamls so the new machine can decrypt them:
   ```bash
   cd dotfiles/nix
   nix shell nixpkgs#sops -c sops updatekeys secrets/minix.yaml
   nix shell nixpkgs#sops -c sops updatekeys secrets/shared.yaml
   ```

### Recovery age key

A recovery age key is in the recipient list of every `dotfiles/nix/secrets/*.yaml`.
Its private half is in the password manager.

To restore from recovery key:

1. Set up the new machine per "First-time setup" through step 4.
2. Get the machine-key story going so sops has _something_ to encrypt to:
   ```bash
   mkdir -p ~/.config/sops/age
   nix shell nixpkgs#age -c age-keygen -o ~/.config/sops/age/keys.txt
   ```
3. Copy the recovery private key from your password manager into a temp file:
   ```bash
   $EDITOR /tmp/recovery-key.txt # paste AGE-SECRET-KEY-1...
   ```
4. Decrypt the existing secrets with the recovery key:
   ```bash
   cd ~/Projects/home-configuration/dotfiles/nix
   SOPS_AGE_KEY_FILE=/tmp/recovery-key.txt nix shell nixpkgs#sops -c sops -d secrets/minix.yaml > /tmp/minix-plain.yaml
   ```
5. Update `.sops.yaml` to replace the old pubkey with the new one (printed by `age-keygen -y ~/.config/sops/age/keys.txt`).
6. Re-encrypt and discard plaintext + recovery key from disk:
   ```bash
   SOPS_AGE_KEY_FILE=/tmp/recovery-key.txt nix shell nixpkgs#sops -c sops -e /tmp/minix-plain.yaml > secrets/minix.yaml
   rm /tmp/minix-plain.yaml /tmp/recovery-key.txt
   ```
7. Continue with First-time setup step 6 (rebuild). The new machine key now owns the secrets going forward; the recovery key is still in the recipient list as a backup.

## MicroVMs

Ephemeral NixOS VMs (pool of 4) for running coding agents and other potentially destructive things in isolation.

### First-time setup

1. Generate an SSH keypair:
   ```bash
   ssh-keygen -t ed25519
   ```
   Then replace the public key in `microvms/base.nix` under `users.users.szymon.openssh.authorizedKeys.keys` with the contents of `~/.ssh/id_ed25519.pub`, and rebuild:
   ```bash
   sudo nixos-rebuild switch --flake .#minix
   ```
2. Add to `~/.ssh/config`:
   ```
   Host vm-?
     User szymon
     StrictHostKeyChecking no
     UserKnownHostsFile /dev/null
     LogLevel ERROR
   ```

### Usage

Run `microvm help` for available commands.
