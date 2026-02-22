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
    pkgs.dnsutils
    pkgs.lm_sensors
    pkgs.trash-cli
  ];

  services.dropbox.enable = true;
  systemd.user.services.dropbox.Unit.OnFailure = [ "notify-failure@%N.service" ];

  systemd.user.services."notify-failure@" = {
    Unit.Description = "Failure notification for %i";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '%h/.bin/notify-pushover \"Failed: %i\"'";
      Environment = "PATH=${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.curl}/bin";
    };
  };

  systemd.user.services.neolink = {
    Unit = {
      Description = "Neolink MQTT bridge for Reolink cameras";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      OnFailure = [ "notify-failure@%N.service" ];
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
      OnFailure = [ "notify-failure@%N.service" ];
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
      OnFailure = [ "notify-failure@%N.service" ];
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
      OnFailure = [ "notify-failure@%N.service" ];
      ConditionPathIsDirectory = "%h/Projects/friday-homebridge";
      StartLimitBurst = 5;
      StartLimitIntervalSec = 300;
    };

    Service = {
      ExecStart = "${pkgs.nix}/bin/nix develop %h/Projects/friday-homebridge --command npm start";
      WorkingDirectory = "%h/Projects/friday-homebridge";
      # 143 = SIGTERM; normal when stopped/restarted by systemd
      SuccessExitStatus = "143";
      Restart = "on-failure";
      RestartSec = 10;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.boot-notify = {
    Unit = {
      Description = "Boot notification";
      After = [
        "default.target"
        "network-online.target"
      ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '%h/.bin/notify-pushover \"Booted: $(date +%%Y-%%m-%%d\\ %%H:%%M)\"'";
      Environment = "PATH=${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.curl}/bin";
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
      OnFailure = [ "notify-failure@%N.service" ];
      ConditionPathIsDirectory = "%h/Projects/friday-ruler";
      StartLimitBurst = 5;
      StartLimitIntervalSec = 300;
    };

    Service = {
      ExecStart = "${pkgs.nix}/bin/nix develop %h/Projects/friday-ruler --command npm start";
      WorkingDirectory = "%h/Projects/friday-ruler";
      # 143 = SIGTERM; normal when stopped/restarted by systemd
      SuccessExitStatus = "143";
      Restart = "on-failure";
      RestartSec = 10;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.xiaomiclock2mqtt = {
    Unit = {
      Description = "Xiaomi Clock BLE to MQTT Bridge";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      OnFailure = [ "notify-failure@%N.service" ];
      ConditionPathIsDirectory = "%h/Projects/xiaomiclock2mqtt";
      StartLimitBurst = 5;
      StartLimitIntervalSec = 300;
    };

    Service = {
      ExecStart = "${pkgs.nix}/bin/nix develop %h/Projects/xiaomiclock2mqtt --command npm start";
      WorkingDirectory = "%h/Projects/xiaomiclock2mqtt";
      SuccessExitStatus = "143";
      Restart = "on-failure";
      RestartSec = 10;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.timav-cache = {
    Unit = {
      Description = "Timav cache update";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      OnFailure = [ "notify-failure@%N.service" ];
      ConditionPathIsDirectory = "%h/Projects/timav";
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.nix}/bin/nix develop %h/Projects/timav --command ./cli.js cache";
      WorkingDirectory = "%h/Projects/timav";
      Environment = "DEBUG=*";
    };
  };

  systemd.user.timers.timav-cache = {
    Unit = {
      Description = "Timav cache update timer";
    };

    Timer = {
      OnCalendar = "hourly";
      Persistent = true;
    };

    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  systemd.user.services.szymonkaliski-com-publish = {
    Unit = {
      Description = "Publish szymonkaliski.com";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      OnFailure = [ "notify-failure@%N.service" ];
      ConditionPathIsDirectory = "%h/Projects/szymonkaliski-com";
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.nix}/bin/nix develop %h/Projects/szymonkaliski-com --command bash -c './scripts/update-notes.sh && ./scripts/publish.sh'";
      WorkingDirectory = "%h/Projects/szymonkaliski-com";
      Environment = [
        "WIKI_PATH=%h/Dropbox/Wiki"
        "PATH=${
          pkgs.lib.makeBinPath [
            pkgs.ripgrep
            pkgs.rsync
            pkgs.git
            pkgs.openssh
            pkgs.coreutils
            pkgs.bash
            pkgs.nix
          ]
        }:%h/.bin"
      ];
    };
  };

  systemd.user.timers.szymonkaliski-com-publish = {
    Unit = {
      Description = "Weekly publish of szymonkaliski.com";
    };

    Timer = {
      OnCalendar = "Mon *-*-* 01:00:00";
      Persistent = true;
    };

    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  systemd.user.services.healthcheck = {
    Unit = {
      Description = "System healthcheck";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash %h/.bin/healthcheck";
      Environment = "PATH=${
        pkgs.lib.makeBinPath [
          pkgs.bash
          pkgs.coreutils
          pkgs.curl
          pkgs.dnsutils
          pkgs.jq
          pkgs.mosquitto
          pkgs.systemd
          pkgs.hostname
        ]
      }:%h/.bin";
    };
  };

  systemd.user.timers.healthcheck = {
    Unit = {
      Description = "Daily system healthcheck";
    };

    Timer = {
      OnCalendar = "*-*-* 08:00:00";
      Persistent = true;
    };

    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

}
