{ pkgs, ... }:
let
  neolink = pkgs.callPackage ../../pkgs/neolink.nix { };
  smartbox2mqtt = pkgs.callPackage ../../pkgs/smartbox2mqtt.nix { };
  lgtv2mqtt2 = pkgs.callPackage ../../pkgs/lgtv2mqtt2.nix { };
  waitForMosquitto = pkgs.writeShellScript "wait-for-mosquitto" ''
    for i in {1..30}; do
      ${pkgs.mosquitto}/bin/mosquitto_pub \
        -h localhost -p 1883 \
        -u mqtt -P mqtt-secure \
        -t healthcheck/wait -m ping -q 0 \
        2>/dev/null && exit 0
      sleep 1
    done
    echo "mosquitto not ready"
    exit 1
  '';
in
{
  imports = [ ../../common.nix ];

  home.homeDirectory = "/home/szymon";

  home.packages = [
    neolink
    smartbox2mqtt
    lgtv2mqtt2
    pkgs.chromium
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
      # wait for possible restart, skip if service recovered
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
      ExecCondition = "${pkgs.bash}/bin/bash -c '! ${pkgs.systemd}/bin/systemctl --user is-active --quiet %i'";
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
    };

    Service = {
      ExecStartPre = waitForMosquitto;
      ExecStart = "${neolink}/bin/neolink mqtt --config=%h/.config/neolink/config.toml";
      Restart = "on-failure";
      RestartSec = 30;
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
    };

    Service = {
      ExecStartPre = waitForMosquitto;
      ExecStart = "${smartbox2mqtt}/bin/smartbox2mqtt";
      Restart = "on-failure";
      RestartSec = 30;
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
    };

    Service = {
      ExecStartPre = waitForMosquitto;
      ExecStart = "${lgtv2mqtt2}/bin/lgtv2mqtt2";
      Restart = "on-failure";
      RestartSec = 30;
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
    };

    Service = {
      ExecStartPre = [
        waitForMosquitto
        "${pkgs.nix}/bin/nix develop %h/Projects/friday-homebridge --command npm run pre-run"
      ];
      ExecStart = "${pkgs.nix}/bin/nix develop %h/Projects/friday-homebridge --command npx homebridge -I";
      WorkingDirectory = "%h/Projects/friday-homebridge";
      # homebridge exits 143 (SIGTERM) on clean stop
      SuccessExitStatus = "143";
      TimeoutStopSec = 10;
      Restart = "on-failure";
      RestartSec = 30;
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
      ConditionPathExists = "!/run/user/%U/boot-notify-done";
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '%h/.bin/notify-pushover \"Booted: $(date +%%Y-%%m-%%d\\ %%H:%%M)\"'";
      ExecStartPost = "${pkgs.coreutils}/bin/touch /run/user/%U/boot-notify-done";
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
    };

    Service = {
      ExecStartPre = [
        waitForMosquitto
        "${pkgs.nix}/bin/nix develop %h/Projects/friday-ruler --command npm run build"
      ];
      ExecStart = "${pkgs.nix}/bin/nix develop %h/Projects/friday-ruler --command node dist/main.js";
      WorkingDirectory = "%h/Projects/friday-ruler";
      TimeoutStopSec = 10;
      Restart = "on-failure";
      RestartSec = 30;
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
    };

    Service = {
      ExecStartPre = [
        waitForMosquitto
        "${pkgs.nix}/bin/nix develop %h/Projects/xiaomiclock2mqtt --command npm run build"
      ];
      ExecStart = "${pkgs.nix}/bin/nix develop %h/Projects/xiaomiclock2mqtt --command node dist/index.js";
      WorkingDirectory = "%h/Projects/xiaomiclock2mqtt";
      TimeoutStopSec = 10;
      Restart = "on-failure";
      RestartSec = 30;
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

  systemd.user.services.archivist-fetch = {
    Unit = {
      Description = "Archivist fetch";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      OnFailure = [ "notify-failure@%N.service" ];
      ConditionPathIsDirectory = "%h/Projects/archivist";
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.nix}/bin/nix develop %h/Projects/archivist --command npx tsx cli.ts fetch";
      WorkingDirectory = "%h/Projects/archivist/archivist-cli";
    };
  };

  systemd.user.timers.archivist-fetch = {
    Unit = {
      Description = "Archivist fetch timer";
    };

    Timer = {
      OnCalendar = "*-*-* 00/4:00:00";
      Persistent = true;
    };

    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  systemd.user.services.archivist-web-ui = {
    Unit = {
      Description = "Archivist web UI";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      OnFailure = [ "notify-failure@%N.service" ];
      ConditionPathIsDirectory = "%h/Projects/archivist";
    };

    Service = {
      ExecStartPre = "${pkgs.nix}/bin/nix develop %h/Projects/archivist --command npm run build";
      ExecStart = "${pkgs.nix}/bin/nix develop %h/Projects/archivist --command npx tsx server.ts";
      WorkingDirectory = "%h/Projects/archivist/archivist-web-ui";
      Environment = "PORT=10005";
      TimeoutStopSec = 10;
      Restart = "on-failure";
      RestartSec = 30;
    };

    Install = {
      WantedBy = [ "default.target" ];
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
      Environment = "PATH=/run/wrappers/bin:/run/current-system/sw/bin:%h/.nix-profile/bin:%h/.bin";
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
