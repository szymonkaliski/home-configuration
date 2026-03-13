{ lib, pkgs, microvm, ... }:

let
  microvmBase = import ./base.nix;

  mkVm = index: {
    name = "vm-${toString index}";
    value = {
      autostart = false;
      restartIfChanged = false;
      config = {
        imports = [
          microvm.nixosModules.microvm
          (microvmBase {
            hostName = "vm-${toString index}";
            ipAddress = "10.100.0.${toString index}";
            tapId = "vm-tap${toString index}";
            mac = "02:00:00:00:00:0${toString index}";
            vsockCid = index + 2;
            mem = 2048;
          })
        ];
      };
    };
  };
in
{
  microvm.vms = builtins.listToAttrs (map mkVm (lib.range 1 4));

  systemd.services."microvm@" = {
    serviceConfig.TimeoutStartSec = "5min";
    serviceConfig.ExecStartPre = [
      "+${pkgs.writeShellScript "microvm-clean-stale-overlay" ''
        # After nixos-rebuild, the VM's toplevel (NixOS closure) changes but the
        # nix-store-overlay.img still has old store path registrations. This causes
        # initrd-find-nixos-closure to fail repeatedly until paths are re-registered
        # across multiple reboots. Detect the change and delete the overlay so
        # microvm-run recreates it fresh.
        cd /var/lib/microvms/$1 || exit 0
        current=$(readlink toplevel 2>/dev/null || true)
        previous=$(cat overlay-generation 2>/dev/null || true)
        if [ -n "$previous" ] && [ "$current" != "$previous" ] && [ -f nix-store-overlay.img ]; then
          rm -f nix-store-overlay.img
          echo "removed stale nix-store overlay (toplevel changed)"
        fi
        printf '%s' "$current" > overlay-generation
      ''} %i"
    ];
  };
}
