{ config, pkgs, ... }:
let
  ports = import ../ports.nix;
  mqtt = import ../mqtt.nix;
  dataDir = "${config.xdg.dataHome}/ps5-mqtt";

  options = pkgs.writeText "ps5-mqtt-options.json" (
    builtins.toJSON {
      mqtt = {
        inherit (mqtt) host port;
        user = mqtt.username;
        pass = mqtt.password;
      };
      frontendPort = ports.ps5Mqtt;
      credentialsStoragePath = "/config/credentials.json";
      include_ps4_devices = false;
      # in rest mode the PS5 answers only unicast discovery
      static_devices = [
        {
          id = "00E4210E32C7";
          name = "PS5-567";
          type = "PS5";
          address = {
            address = "192.168.1.3";
            port = 9302;
          };
          systemVersion = "14100003";
          transitioning = false;
        }
      ];
    }
  );
in
{
  services.podman.enable = true;

  # playactor credentials from the web UI pairing
  systemd.user.tmpfiles.rules = [ "d ${dataDir} 0700 - - -" ];

  services.podman.containers.ps5-mqtt = {
    # pinned: 1.7.0 broke standby and discovery
    image = "ghcr.io/funkeyflo/ps5-mqtt:1.7.3";
    environment = {
      CONFIG_PATH = "/options.json";
      # errors are only logged through the debug namespaces
      # webserver:playactor echoes the pairing credentials
      DEBUG = "@ha:ps5:*,-@ha:ps5:webserver:playactor";
    };
    volumes = [
      "${dataDir}:/config"
      "${options}:/options.json:ro"
    ];
    # discovery broadcasts on the LAN
    network = "host";
    # playactor runs through a shell, timed-out calls orphan it to PID 1
    # the node entrypoint never reaps orphans, podman-init does
    extraConfig.Container.RunInit = true;
  };
}
