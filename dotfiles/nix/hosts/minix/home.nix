{ pkgs, neolink, ... }:
{
  imports = [ ../../common.nix ];

  home.homeDirectory = "/home/szymon";

  home.packages = [
    neolink.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.lm_sensors
    pkgs.trash-cli
  ];

  services.dropbox.enable = true;

  systemd.user.services.neolink = {
    Unit = {
      Description = "Neolink MQTT bridge for Reolink cameras";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      ExecStart = "${
        neolink.packages.${pkgs.stdenv.hostPlatform.system}.default
      }/bin/neolink mqtt --config=%h/.config/neolink/config.toml";
      Restart = "on-failure";
      RestartSec = 10;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
