{ lib, microvm, ... }:

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
}
