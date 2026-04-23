{
  pkgs,
  microvm,
  ...
}:

let
  microvmBase = import ./base.nix;

  # per-VM sizing to fit into 16GB of host memory
  sizes = {
    lg = 4096;
    sm = 2048;
  };
  vms = [
    { index = 1; size = "lg"; }
    { index = 2; size = "lg"; }
    { index = 3; size = "sm"; }
    { index = 4; size = "sm"; }
  ];

  mkVm = { index, size }: {
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
            mem = sizes.${size};
          })
        ];
      };
    };
  };
in
{
  microvm.vms = builtins.listToAttrs (map mkVm vms);

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
