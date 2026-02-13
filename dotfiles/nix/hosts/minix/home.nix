{ pkgs, ... }:
let
  neolink = pkgs.callPackage ../../pkgs/neolink.nix { };
  smartbox2mqtt = pkgs.callPackage ../../pkgs/smartbox2mqtt.nix { };
  lgtv2mqtt2 = pkgs.callPackage ../../pkgs/lgtv2mqtt2.nix { };
  mqtt-explorer = pkgs.callPackage ../../pkgs/mqtt-explorer.nix { };
in
{
  imports = [ ../../common.nix ];

  home.homeDirectory = "/home/szymon";

  home.packages = [
    neolink
    smartbox2mqtt
    lgtv2mqtt2
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
      ExecStart = "${neolink}/bin/neolink mqtt --config=%h/.config/neolink/config.toml";
      Restart = "on-failure";
      RestartSec = 10;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.smartbox2mqtt = {
    Unit = {
      Description = "Smartbox to MQTT bridge for heaters";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      ExecStart = "${smartbox2mqtt}/bin/smartbox2mqtt";
      Restart = "on-failure";
      RestartSec = 10;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.lgtv2mqtt2 = {
    Unit = {
      Description = "LG TV to MQTT bridge";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      ExecStart = "${lgtv2mqtt2}/bin/lgtv2mqtt2";
      Restart = "on-failure";
      RestartSec = 10;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.mqtt-explorer = {
    Unit = {
      Description = "MQTT Explorer Web UI";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      ExecStart = "${mqtt-explorer}/bin/mqtt-explorer";
      Environment = [
        "PORT=10000"
        "MQTT_EXPLORER_SKIP_AUTH=true"
      ];
      Restart = "on-failure";
      RestartSec = 10;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

}
