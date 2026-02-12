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

  lgtv2mqtt2 = pkgs.buildNpmPackage {
    pname = "lgtv2mqtt2";
    version = "1.3.0";

    src = pkgs.fetchFromGitHub {
      owner = "szymonkaliski";
      repo = "lgtv2mqtt2";
      rev = "945e3e8566a35b2ede80bf4e1df2e03fb39e099a";
      hash = "sha256-wuMnlHBTcfqsDfriErRwxIAsF0G+684/vWkGVqBzr6A=";
    };

    npmDepsHash = "sha256-bX0hcMUqPhqR5j6yNFdHom6TkSmMk4QXMdITaum6J+o=";
    dontNpmBuild = true;
  };
in
{
  imports = [ ../../common.nix ];

  home.homeDirectory = "/home/szymon";

  home.packages = [
    neolink.packages.${pkgs.stdenv.hostPlatform.system}.default
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
}
