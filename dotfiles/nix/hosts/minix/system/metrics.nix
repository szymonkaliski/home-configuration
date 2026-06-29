{ ... }:
let
  mqtt = import ../../../mqtt.nix;
  ports = import ../ports.nix;
in
{
  # metrics trial: VictoriaMetrics store, Telegraf (MQTT push), Grafana (tailnet
  # only), plus node + smartctl exporters scraped alongside blocky. Everything
  # binds 127.0.0.1; Grafana is reached over `tailscale serve` like telegraphist.
  services.victoriametrics = {
    enable = true;
    listenAddress = "127.0.0.1:8428";
    retentionPeriod = "5y";
    prometheusConfig = {
      global.scrape_interval = "30s";
      scrape_configs = [
        {
          job_name = "victoriametrics";
          static_configs = [ { targets = [ "127.0.0.1:8428" ]; } ];
        }
        {
          job_name = "blocky";
          static_configs = [ { targets = [ "127.0.0.1:${toString ports.blockyApi}" ]; } ];
        }
        {
          job_name = "node";
          static_configs = [ { targets = [ "127.0.0.1:9100" ]; } ];
        }
        {
          job_name = "smartctl";
          static_configs = [ { targets = [ "127.0.0.1:9633" ]; } ];
        }
      ];
    };
  };

  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
    enabledCollectors = [ "systemd" ];
  };

  services.prometheus.exporters.smartctl = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9633;
  };

  services.telegraf = {
    enable = true;
    extraConfig = {
      agent = {
        interval = "30s";
        flush_interval = "30s";
        omit_hostname = true;
      };
      outputs.influxdb = [
        {
          urls = [ "http://127.0.0.1:8428" ];
          database = "telegraf";
          skip_database_creation = true;
        }
      ];
      processors.enum = [
        {
          namepass = [
            "heater_active"
            "camera_status"
          ];
          mapping = [
            {
              fields = [ "value" ];
              value_mappings = {
                ON = 1;
                OFF = 0;
                connected = 1;
                disconnected = 0;
              };
            }
          ];
        }
      ];
      inputs.mqtt_consumer =
        let
          broker = {
            servers = [ "tcp://${mqtt.host}:${toString mqtt.port}" ];
            username = mqtt.username;
            password = mqtt.password;
            tagexclude = [ "topic" ];
          };
        in
        map (c: broker // c) [
          {
            name_override = "env";
            data_format = "value";
            data_type = "float";
            topics = [
              "friday/sensor_living_room_temperature/temperature"
              "friday/sensor_living_room_temperature/humidity"
              "friday/sensor_living_room_temperature/battery"
              "friday/sensor_studio/temperature"
              "friday/sensor_studio/humidity"
              "friday/sensor_studio/pressure"
            ];
            topic_parsing = [
              {
                topic = "friday/+/+";
                tags = "_/device/metric";
              }
            ];
          }
          {
            name_override = "heater";
            data_format = "value";
            data_type = "float";
            topics = [
              "friday/hjm/heater_1/current_temperature"
              "friday/hjm/heater_1/temperature"
              "friday/hjm/heater_1/power"
              "friday/hjm/heater_2/current_temperature"
              "friday/hjm/heater_2/temperature"
              "friday/hjm/heater_2/power"
            ];
            topic_parsing = [
              {
                topic = "friday/hjm/+/+";
                tags = "_/_/device/metric";
              }
            ];
          }
          {
            name_override = "heater_active";
            data_format = "value";
            data_type = "string";
            topics = [
              "friday/hjm/heater_1/active"
              "friday/hjm/heater_2/active"
            ];
            topic_parsing = [
              {
                topic = "friday/hjm/+/+";
                tags = "_/_/device/_";
              }
            ];
          }
          {
            name_override = "camera_battery";
            data_format = "value";
            data_type = "float";
            topics = [ "neolink/+/status/battery_level" ];
            topic_parsing = [
              {
                topic = "neolink/+/status/+";
                tags = "_/device/_/_";
              }
            ];
          }
          {
            name_override = "camera_status";
            data_format = "value";
            data_type = "string";
            topics = [ "neolink/+/status" ];
            topic_parsing = [
              {
                topic = "neolink/+/status";
                tags = "_/device/_";
              }
            ];
          }
        ];
    };
  };
}
