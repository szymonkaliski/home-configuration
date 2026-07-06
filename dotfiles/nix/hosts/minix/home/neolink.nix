{
  config,
  pkgs,
  lib,
  ...
}:
let
  mqtt = import ../../../mqtt.nix;
  ports = import ../ports.nix;
  inherit (import ../lib.nix { inherit pkgs lib; }) waitForMosquitto mkProjectService;

  neolink = pkgs.callPackage ../../../pkgs/neolink.nix { };
  # GStreamer plugin search path for neolink's RTSP pipelines (without it every stream 400s).
  # makeSearchPathOutput "out": gstreamer's core plugins live in its "out", not the default "bin".
  gstPluginPath = pkgs.lib.makeSearchPathOutput "out" "lib/gstreamer-1.0" [
    pkgs.gst_all_1.gstreamer
    pkgs.gst_all_1.gst-plugins-base
    pkgs.gst_all_1.gst-plugins-good
    pkgs.gst_all_1.gst-plugins-bad
    pkgs.gst_all_1.gst-rtsp-server
  ];

  # battery     - physically a battery camera
  # autoConnect - shown + streamed by default on the dashboard
  neolinkCameras = [
    {
      name = "cam_1";
      battery = true;
      autoConnect = false;
    }
    {
      name = "cam_2";
      battery = true;
      autoConnect = false;
    }
    {
      name = "hallway_1";
      battery = true;
      autoConnect = false;
    }
    {
      name = "hallway_2";
      battery = true;
      autoConnect = false;
    }
    {
      name = "basement";
      battery = false;
      autoConnect = true;
    }
    {
      name = "gym";
      battery = true;
      autoConnect = true;
    }
    {
      name = "garden";
      battery = true;
      autoConnect = true;
    }
    {
      name = "studio";
      battery = false;
      autoConnect = true;
    }
  ];

  renderCamera = c: ''
    [[cameras]]
    name = "${c.name}"
    username = "${config.sops.placeholder."neolink_${c.name}_username"}"
    password = "${config.sops.placeholder."neolink_${c.name}_password"}"
    uid = "${config.sops.placeholder."neolink_${c.name}_uid"}"

    # drop the cam connection when nothing is watching, so battery cams can sleep
    idle_disconnect = true
    # don't push a placeholder splash when cam is not up
    use_splash = false
    # discover through reolink remote servers, "local" is not always reliable
    discovery = "remote"

    [cameras.mqtt]
    # motion holds a live connection that keeps the camera awake
    enable_motion = ${lib.boolToString (!c.battery)}
    # preview snapshots go stale and aren't worth the mqtt traffic
    enable_preview = false
    # battery level reports are queried ~6h
    enable_battery = ${lib.boolToString c.battery}
    battery_update = 21600000
  '';

  neolinkSecrets = builtins.listToAttrs (
    lib.concatMap (
      c:
      map (k: lib.nameValuePair "neolink_${c.name}_${k}" { }) [
        "username"
        "password"
        "uid"
      ]
    ) neolinkCameras
  );

in
{
  home.packages = [ neolink ];

  sops.secrets = neolinkSecrets;

  sops.templates."neolink-config" = {
    path = "${config.home.homeDirectory}/.config/neolink/config.toml";
    content = ''
      bind = "0.0.0.0"

      [mqtt]
      broker_addr = "${mqtt.host}"
      port = ${toString mqtt.port}
      credentials = ["${mqtt.username}", "${mqtt.password}"]

    ''
    + lib.concatMapStringsSep "\n" renderCamera neolinkCameras;
  };

  xdg.configFile."neolink-dashboard/config.json".text = builtins.toJSON {
    mqtt = {
      host = mqtt.host;
      port = mqtt.port;
      username = mqtt.username;
      password = mqtt.password;
    };
    cams = map (c: {
      name = c.name;
      power = if c.battery then "battery" else "wired";
      autoConnect = c.autoConnect;
    }) neolinkCameras;
  };

  systemd.user.services.neolink = {
    Unit = {
      Description = "Neolink MQTT bridge for Reolink cameras";
      After = [
        "network-online.target"
        "sops-nix.service"
      ];
      Wants = [
        "network-online.target"
        "sops-nix.service"
      ];
      OnFailure = [ "notify-failure@%N.service" ];
    };

    Service = {
      Environment = [ "GST_PLUGIN_SYSTEM_PATH_1_0=${gstPluginPath}" ];
      CPUQuota = "100%";
      ExecStartPre = waitForMosquitto;
      ExecStart = "${neolink}/bin/neolink mqtt-rtsp --config=%h/.config/neolink/config.toml";
      Restart = "on-failure";
      RestartSec = 30;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.neolink-dashboard = mkProjectService {
    dir = "neolink-dashboard";
    description = "Neolink camera dashboard";
    extraUnits = [ "neolink.service" ];
    build = "npm run build";
    command = "node dist/server/server.js";
    environment = "PORT=${toString ports.neolinkDashboard}";
    successExitStatus = "143";
    timeoutStop = 10;
  };
}
