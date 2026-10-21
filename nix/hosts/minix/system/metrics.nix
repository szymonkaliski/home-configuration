{ pkgs, ... }:
let
  mqtt = import ../mqtt.nix;
  ports = import ../ports.nix;
  dns = import ../dns.nix;
  # neolink only publishes status/pir on transitions; sample the broker's
  # retained state periodically to get dense 0/1 series that
  # integrate()/state-timeline can use (reads retained messages only, so
  # battery cameras are never woken)
  cameraStateSample = pkgs.writeShellScript "camera-state-sample" ''
    ${pkgs.mosquitto}/bin/mosquitto_sub \
      -h ${mqtt.host} -p ${toString mqtt.port} \
      -u ${mqtt.username} -P ${mqtt.password} \
      --retained-only -W 2 \
      -t 'neolink/+/status' -t 'neolink/+/status/pir' \
      -t 'friday/vaillant/fault_status' -t 'friday/vaillant/system_status' \
      -v 2>/dev/null |
      ${pkgs.gawk}/bin/awk '{
        split($1, t, "/");
        if (t[1] == "neolink" && t[4] == "pir")
          printf "camera_pir,device=%s value=%d\n", t[2], ($2 == "on") ? 1 : 0
        else if (t[1] == "neolink")
          printf "camera_state,device=%s value=%d\n", t[2], ($2 == "connected") ? 1 : 0
        else if ($1 == "friday/vaillant/fault_status")
          printf "vaillant_state,metric=fault_status value=%d\n", ($2 == "ok" || $2 == "0") ? 0 : 1
        else if ($1 == "friday/vaillant/system_status")
          printf "vaillant_state,metric=system_status value=%d\n", ($2 == "heating" || $2 == "1") ? 1 : ($2 == "cooling" || $2 == "2") ? 2 : ($2 == "hot_water" || $2 == "3") ? 3 : 0
      }'
    exit 0
  '';
  # ookla's own cli; the license notice goes to stderr on every run since the
  # telegraf user has no writable home to remember the acceptance in.
  # bandwidth is bytes/s, the panels want Mbit/s; packetLoss is absent when
  # not measured and reported as -1 (the panel filters `>= 0`).
  # pinned to Plus Poznań (60356, fallback Play Poznań 23677) so auto-pick does
  # not rotate onto regional servers that cap below 1 Gbps
  internetSpeedSample = pkgs.writeShellScript "internet-speed-sample" ''
    (${pkgs.ookla-speedtest}/bin/speedtest --accept-license --accept-gdpr -s 60356 --format=json 2>/dev/null ||
      ${pkgs.ookla-speedtest}/bin/speedtest --accept-license --accept-gdpr -s 23677 --format=json 2>/dev/null) |
      ${pkgs.jq}/bin/jq -r '"internet_speed download=\(.download.bandwidth * 8 / 1e6),upload=\(.upload.bandwidth * 8 / 1e6),latency=\(.ping.latency),jitter=\(.ping.jitter),packet_loss=\(.packetLoss // -1)"'
  '';
in
{
  services.victoriametrics = {
    enable = true;
    listenAddress = "127.0.0.1:${toString ports.victoriametrics}";
    retentionPeriod = "5y";
    prometheusConfig = {
      global.scrape_interval = "30s";
      scrape_configs = [
        {
          job_name = "victoriametrics";
          static_configs = [ { targets = [ "127.0.0.1:${toString ports.victoriametrics}" ]; } ];
        }
        {
          job_name = "blocky";
          static_configs = [ { targets = [ "127.0.0.1:${toString ports.blockyApi}" ]; } ];
        }
        {
          job_name = "node";
          static_configs = [ { targets = [ "127.0.0.1:${toString ports.nodeExporter}" ]; } ];
        }
        {
          job_name = "smartctl";
          static_configs = [ { targets = [ "127.0.0.1:${toString ports.smartctl}" ]; } ];
        }
      ];
    };
  };

  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = ports.nodeExporter;
  };

  services.prometheus.exporters.smartctl = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = ports.smartctl;
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
          urls = [ "http://127.0.0.1:${toString ports.victoriametrics}" ];
          database = "telegraf";
          skip_database_creation = true;
        }
      ];
      processors.enum = [
        {
          namepass = [
            "camera_status"
            "vaillant_state"
          ];
          mapping = [
            {
              fields = [ "value" ];
              value_mappings = {
                connected = 1;
                disconnected = 0;
                ok = 0;
                fault = 1;
                standby = 0;
                heating = 1;
                cooling = 2;
                hot_water = 3;
              };
            }
          ];
        }
      ];
      inputs.exec = [
        {
          commands = [ "${cameraStateSample}" ];
          data_format = "influx";
        }
        # heavy probe (~0.4 GB down + ~0.4 GB up per run); own interval, not
        # the 30s agent default
        {
          commands = [ "${internetSpeedSample}" ];
          data_format = "influx";
          interval = "60m";
          timeout = "120s";
        }
      ];
      # the lan gateway plus the resolvers blocky depends on
      inputs.ping = [
        {
          urls = [ "192.168.1.1" ] ++ dns.quad9.ips ++ dns.cloudflare.ips;
          method = "native";
          count = 5;
          ping_interval = "0.2s";
          deadline = "5s";
          ipv4 = true;
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
              "friday/vaillant/outdoor_temperature"
              "friday/vaillant/room_temperature"
              "friday/vaillant/room_humidity"
              "friday/vaillant/electricity_heating"
              "friday/vaillant/gas_heating"
              "friday/vaillant/electricity_hot_water"
              "friday/vaillant/gas_hot_water"
            ];
            topic_parsing = [
              {
                topic = "friday/+/+";
                tags = "_/device/metric";
              }
            ];
          }
          {
            name_override = "vaillant_state";
            data_format = "value";
            data_type = "string";
            topics = [
              "friday/vaillant/fault_status"
              "friday/vaillant/system_status"
            ];
            topic_parsing = [
              {
                topic = "friday/vaillant/+";
                tags = "_/_/metric";
              }
            ];
          }
          {
            name_override = "heater";
            data_format = "value";
            data_type = "float";
            topics = [
              "friday/hjm/heater_1/current_temperature"
              "friday/hjm/heater_1/energy"
              "friday/hjm/heater_2/current_temperature"
              "friday/hjm/heater_2/energy"
            ];
            topic_parsing = [
              {
                topic = "friday/hjm/+/+";
                tags = "_/_/device/metric";
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
