{ lib, microvm, ... }:

let
  microvmBase = import ./microvm-base.nix;

  mkVm = index: {
    name = "vm-${toString index}";
    value = {
      autostart = false;
      config = {
        imports = [
          microvm.nixosModules.microvm
          (microvmBase {
            hostName = "vm-${toString index}";
            ipAddress = "10.100.0.${toString index}";
            tapId = "vm-tap${toString index}";
            mac = "02:00:00:00:00:0${toString index}";
            vsockCid = index + 2;
          })
        ];
      };
    };
  };
in
{
  microvm.vms = builtins.listToAttrs (map mkVm (lib.range 1 8));
}
