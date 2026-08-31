{ config, pkgs, ... }:
{
  imports = [
    ../../modules/home/common.nix
    ../../modules/home/boot-notify.nix
  ];

  home.homeDirectory = "/home/szymon";

  sops.defaultSopsFile = ../../secrets/shared.yaml;
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

  services.ollama.enable = true;

  home.packages = [ pkgs.maestral ];

  # setup.sh links the account, until then the daemon runs with sync idle
  systemd.user.services.maestral = {
    Unit.Description = "Maestral daemon";

    Service = {
      Type = "notify";
      NotifyAccess = "exec";
      ExecStart = "${pkgs.maestral}/bin/maestral start -f";
      ExecStop = "${pkgs.maestral}/bin/maestral stop";
      WatchdogSec = "30s";
    };

    Install.WantedBy = [ "default.target" ];
  };
}
