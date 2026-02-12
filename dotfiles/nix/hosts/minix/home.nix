{ pkgs, neolink, ... }:
let
  smartbox2mqtt = pkgs.buildNpmPackage {
    pname = "smartbox2mqtt";
    version = "1.5.0";

    src = pkgs.fetchFromGitHub {
      owner = "szymonkaliski";
      repo = "smartbox2mqtt";
      rev = "2a16c8281a531c3f49ca20ea77a2cc8cc7a84163";
      hash = "sha256-4uJYxlARLDHooFiHxVYLMghAYa5qSqqddFqgu1xc2Ow=";
    };

    npmDepsHash = "sha256-TJfRdzvA8PybTRx8zUN+IgW819kZrz8ac3/wgJTi5Us=";
    dontNpmBuild = true;
  };
in
{
  imports = [ ../../common.nix ];

  home.homeDirectory = "/home/szymon";

  home.packages = [
    neolink.packages.${pkgs.stdenv.hostPlatform.system}.default
    smartbox2mqtt
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
}
