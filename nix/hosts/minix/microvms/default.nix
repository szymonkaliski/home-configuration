{
  pkgs,
  lib,
  ...
}:

let
  net = import ../net.nix;
  microvmBase = import ./base.nix;

  mkVm =
    # single digit only for mac address formatting
    index:
    assert lib.assertMsg (index >= 1 && index <= 9) "vm index must be 1..9";
    {
      name = "vm-${toString index}";
      value = {
        autostart = false;
        restartIfChanged = false;
        config = {
          imports = [
            (microvmBase {
              hostName = "vm-${toString index}";
              ipAddress = "${net.subnet}.${toString index}";
              tapId = "vm-tap${toString index}";
              mac = "02:00:00:00:00:0${toString index}";
            })
          ];
        };
      };
    };
in
{
  microvm.vms = builtins.listToAttrs (
    map mkVm [
      1
      2
      3
      4
    ]
  );

  # the virtiofsd processes exit as soon as their client disconnects, but the
  # supervisord wrapping them takes ~4s to reap its notify child after
  # SIGTERM; escalate to SIGKILL quickly so stop->start cycles stay fast
  systemd.services."microvm-virtiofsd@" = {
    serviceConfig.TimeoutStopSec = "2s";
    requires = [ "microvm-workspace@%i.service" ];
    after = [ "microvm-workspace@%i.service" ];
  };

  # private workspace: an overlay of the source directory, mounted at
  # ~/MicroVMs/vm-N/workspace before virtiofsd resolves the share. virtiofsd
  # opens the shared directory once at startup, and it runs with PrivateTmp,
  # so a mount from its own ExecStartPre would stay inside its mount
  # namespace, invisible to the host. bin/microvm writes the `source` symlink
  # for a private instance; without it the unit does nothing and the VM
  # shares the `workspace` symlink target in place
  systemd.services."microvm-workspace@" = {
    description = "Private workspace overlay for MicroVM '%i'";
    partOf = [ "microvm@%i.service" ];
    # microvm-virtiofsd@ Requires= this unit, so a switch that restarted it
    # would take the running VM down with it; the store paths in ExecStart
    # change on every nixpkgs bump
    restartIfChanged = false;
    before = [ "microvm-virtiofsd@%i.service" ];
    path = [
      pkgs.util-linux
      pkgs.coreutils
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.writeShellScript "microvm-workspace-mount" ''
        set -eu
        cd /home/szymon/MicroVMs/$1
        [ -L source ] || exit 0
        # a symlink here would make mount(2) overlay the project itself
        if [ -L workspace ] || [ ! -d workspace ]; then
          echo "workspace must be a directory for a private instance" >&2
          exit 1
        fi
        mountpoint -q workspace && exit 0
        # redirect_dir: directory renames inside the instance succeed instead
        # of failing with EXDEV
        mount -t overlay overlay \
          -o "lowerdir=$(readlink -f source),upperdir=$PWD/overlay/upper,workdir=$PWD/overlay/work,redirect_dir=on" \
          workspace
      ''} %i";
      ExecStop = "${pkgs.writeShellScript "microvm-workspace-umount" ''
        cd /home/szymon/MicroVMs/$1 || exit 0
        mountpoint -q workspace || exit 0
        umount workspace || umount -l workspace
      ''} %i";
    };
  };

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
