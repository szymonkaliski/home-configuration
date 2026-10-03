{ config, pkgs, ... }:
let
  ports = import ../ports.nix;
  mqtt = import ../mqtt.nix;
  dataDir = "${config.xdg.dataHome}/ps5-mqtt";

  # in rest mode the PS5 answers only unicast discovery
  # quadlet strips double quotes from Environment= values, podman reads env files verbatim
  staticDevicesEnv = pkgs.writeText "ps5-mqtt-static-devices.env" ''
    STATIC_DEVICES=${
      builtins.toJSON [
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
      ]
    }
  '';
in
{
  services.podman.enable = true;

  # playactor credentials from the web UI pairing
  systemd.user.tmpfiles.rules = [ "d ${dataDir} 0700 - - -" ];

  services.podman.containers.ps5-mqtt = {
    # pinned: 1.7.0 broke standby and discovery
    image = "ghcr.io/funkeyflo/ps5-mqtt:1.7.3";
    environment = {
      MQTT_HOST = mqtt.host;
      MQTT_PORT = toString mqtt.port;
      MQTT_USERNAME = mqtt.username;
      MQTT_PASSWORD = mqtt.password;
      FRONTEND_PORT = toString ports.ps5Mqtt;
      CREDENTIAL_STORAGE_PATH = "/config/credentials.json";
      INCLUDE_PS4_DEVICES = "false";
      # errors are only logged through the debug namespaces
      # webserver:playactor echoes the pairing credentials
      DEBUG = "@ha:ps5:*,-@ha:ps5:webserver:playactor";
    };
    environmentFile = [ "${staticDevicesEnv}" ];
    volumes = [ "${dataDir}:/config" ];
    # discovery broadcasts on the LAN
    network = "host";
  };
}
