# berry

## Building berry's SD card

berry's SD card image can be generated on minix:

```sh
ssh minix '~/.bin/build-berry-sd-image'
```

A freshly flashed card boots with password `berry` (`initialPassword` in `nix/hosts/berry/system.nix`), which `setup.sh` replaces.
First boot needs ethernet, since wifi reads a sops secret that stays undecryptable until this host's age key is added to `.sops.yaml` and the secrets are re-encrypted.
A reflashed card also has a new host key, so `keys.berryHost` needs updating before minix can ssh in again.
