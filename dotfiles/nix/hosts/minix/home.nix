{ pkgs, ... }:
let
  neolink = pkgs.callPackage ../../pkgs/neolink.nix { };
  smartbox2mqtt = pkgs.callPackage ../../pkgs/smartbox2mqtt.nix { };
  lgtv2mqtt2 = pkgs.callPackage ../../pkgs/lgtv2mqtt2.nix { };
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
      StartLimitBurst = 5;
      StartLimitIntervalSec = 300;
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
      StartLimitBurst = 5;
      StartLimitIntervalSec = 300;
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
      StartLimitBurst = 5;
      StartLimitIntervalSec = 300;
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

  systemd.user.services.friday-homebridge = {
    Unit = {
      Description = "Homebridge";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      ConditionPathIsDirectory = "%h/Projects/friday-homebridge";
      StartLimitBurst = 5;
      StartLimitIntervalSec = 300;
    };

    Service = {
      ExecStart = "${pkgs.nix}/bin/nix develop %h/Projects/friday-homebridge --command npm start";
      WorkingDirectory = "%h/Projects/friday-homebridge";
      Restart = "on-failure";
      RestartSec = 10;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.friday-ruler = {
    Unit = {
      Description = "Friday Ruler";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      ConditionPathIsDirectory = "%h/Projects/friday-ruler";
      StartLimitBurst = 5;
      StartLimitIntervalSec = 300;
    };

    Service = {
      ExecStart = "${pkgs.nix}/bin/nix develop %h/Projects/friday-ruler --command npm start";
      WorkingDirectory = "%h/Projects/friday-ruler";
      Restart = "on-failure";
      RestartSec = 10;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

}
