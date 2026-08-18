{
  config,
  pkgs,
  lib,
  ...
}:
let
  ports = import ../ports.nix;
in
{
  # secret_key fed via grafana's $__file{} provider so it stays out of the
  # world-readable nix store; owned by the grafana service user
  sops.secrets.grafana_secret_key.owner = "grafana";

  services.grafana =
    let
      ds = {
        type = "prometheus";
        uid = "victoriametrics";
      };
      # refIds are assigned sequentially (A, B, C, ...) in target order
      mkTargets = lib.imap0 (
        i: t:
        {
          datasource = ds;
          expr = t.expr;
          legendFormat = t.legend;
          refId = builtins.elemAt lib.upperChars i;
        }
        // lib.optionalAttrs (t ? instant) { inherit (t) instant; }
      );
      # timeseries; unit is the y-axis unit (e.g. "percent", "percentunit"), null for none
      tsPanel = unit: title: x: y: w: h: targets: {
        inherit title;
        type = "timeseries";
        datasource = ds;
        gridPos = {
          inherit
            x
            y
            w
            h
            ;
        };
        targets = mkTargets targets;
        fieldConfig = {
          defaults = {
            custom.spanNulls = true;
          }
          // lib.optionalAttrs (unit != null) { inherit unit; };
          overrides = [ ];
        };
        options = { };
      };
      # threshold steps from [ value color ] pairs
      mkSteps = map (s: {
        value = builtins.elemAt s 0;
        color = builtins.elemAt s 1;
      });
      # discrete on/off state over time (holds state between change-points)
      statePanel = title: x: y: w: h: targets: {
        inherit title;
        type = "state-timeline";
        datasource = ds;
        gridPos = {
          inherit
            x
            y
            w
            h
            ;
        };
        targets = mkTargets targets;
        fieldConfig = {
          defaults = {
            color.mode = "thresholds";
            thresholds = {
              mode = "absolute";
              steps = mkSteps [
                [
                  null
                  "red"
                ]
                [
                  1
                  "green"
                ]
              ];
            };
            mappings = [
              {
                type = "value";
                options = {
                  "0".text = "disconnected";
                  "1".text = "connected";
                };
              }
            ];
          };
          overrides = [ ];
        };
        options = {
          mergeValues = true;
          showValue = "never";
          rowHeight = 0.9;
          legend = {
            showLegend = true;
            displayMode = "list";
            placement = "bottom";
          };
        };
      };
      # horizontal bars of a single reduced value per series (max = null for auto)
      barPanel = unit: max: title: x: y: w: h: targets: {
        inherit title;
        type = "bargauge";
        datasource = ds;
        gridPos = {
          inherit
            x
            y
            w
            h
            ;
        };
        targets = mkTargets targets;
        fieldConfig = {
          defaults = {
            inherit unit;
            min = 0;
            color.mode = "continuous-GrYlRd";
          }
          // lib.optionalAttrs (max != null) { inherit max; };
          overrides = [ ];
        };
        options = {
          displayMode = "gradient";
          orientation = "horizontal";
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
        };
      };
      # single reduced value (stat); steps = threshold steps for coloring
      bigStat = unit: steps: title: x: y: w: h: targets: {
        inherit title;
        type = "stat";
        datasource = ds;
        gridPos = {
          inherit
            x
            y
            w
            h
            ;
        };
        targets = mkTargets targets;
        fieldConfig = {
          defaults = {
            inherit unit;
            thresholds = {
              mode = "absolute";
              inherit steps;
            };
          };
          overrides = [ ];
        };
        options = {
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
          colorMode = "value";
          graphMode = "none";
          textMode = "auto";
        };
      };
      alwaysGreen = mkSteps [
        [
          null
          "green"
        ]
      ];
      mkDashboard =
        {
          uid,
          title,
          tags,
          panels,
        }:
        {
          inherit
            uid
            title
            tags
            panels
            ;
          schemaVersion = 39;
          editable = true;
          time = {
            from = "now-7d";
            to = "now";
          };
          refresh = "1m";
        };
      dashboard = mkDashboard {
        uid = "friday-home";
        title = "Home";
        tags = [ "fav" ];
        panels = [
          (tsPanel null "Temperatures (°C)" 0 0 24 8 [
            {
              expr = ''env_value{metric="temperature",device="sensor_living_room_temperature"}'';
              legend = "living room";
            }
            {
              expr = ''heater_value{metric="current_temperature"}'';
              legend = "{{device}} current";
            }
          ])
          (tsPanel null "Humidity (%)" 0 8 12 8 [
            {
              expr = ''env_value{metric="humidity"}'';
              legend = "{{device}}";
            }
          ])
          (tsPanel null "Studio pressure (hPa)" 12 8 12 8 [
            {
              expr = ''env_value{metric="pressure"}'';
              legend = "pressure";
            }
          ])
          (tsPanel null "Heater: current vs setpoint (°C)" 0 16 12 8 [
            {
              expr = ''heater_value{metric="current_temperature"}'';
              legend = "{{device}} current";
            }
            {
              expr = ''heater_value{metric="temperature"}'';
              legend = "{{device}} setpoint";
            }
          ])
          (tsPanel null "Heater power drawn (W)" 12 16 12 8 [
            {
              expr = ''heater_value{metric="power"} * on(device) group_left() heater_active_value'';
              legend = "{{device}}";
            }
          ])
          (tsPanel "percent" "Batteries (%)" 0 24 12 8 [
            {
              expr = "camera_battery_value";
              legend = "{{device}}";
            }
            {
              expr = ''env_value{metric="battery"}'';
              legend = "{{device}}";
            }
          ])
          # camera_state is the dense 30s sampling of the retained status topic
          # (see metrics.nix); camera_status is the raw transition events
          (barPanel "h" null "Camera connected time, in range (h)" 12 24 12 8 [
            {
              expr = "integrate(camera_state_value[$__range]) / 3600";
              legend = "{{device}}";
              instant = true;
            }
          ])
          (statePanel "Camera connection" 0 32 24 6 [
            {
              expr = "camera_state_value";
              legend = "{{device}}";
            }
          ])
          (statePanel "Camera PIR" 0 38 24 6 [
            {
              expr = "camera_pir_value";
              legend = "{{device}}";
            }
          ])
        ];
      };
      blockyDashboard = mkDashboard {
        uid = "blocky-dns";
        title = "Blocky";
        tags = [ "fav" ];
        panels = [
          (tsPanel null "Queries/s" 0 0 12 8 [
            {
              expr = "sum(rate(blocky_query_total[5m]))";
              legend = "queries/s";
            }
          ])
          (tsPanel null "Responses by type (per s)" 12 0 12 8 [
            {
              expr = "sum by (response_type) (rate(blocky_response_total[5m]))";
              legend = "{{response_type}}";
            }
          ])
          (tsPanel "percentunit" "Blocked share" 0 8 12 8 [
            {
              expr = ''sum(rate(blocky_response_total{response_type="BLOCKED"}[5m])) / sum(rate(blocky_response_total[5m]))'';
              legend = "blocked";
            }
          ])
          (tsPanel null "Top clients (queries/s)" 12 8 12 8 [
            {
              # topk() picks top 5 per step (legend fills up with dozens of
              # clients); topk_avg picks 5 series across the whole range
              expr = "topk_avg(5, sum by (client) (rate(blocky_query_total[5m])))";
              legend = "{{client}}";
            }
          ])
          (tsPanel null "Cache entries" 0 16 12 8 [
            {
              expr = "blocky_cache_entries";
              legend = "entries";
            }
          ])
          (tsPanel "percentunit" "Cache hit ratio" 12 16 12 8 [
            {
              expr = "sum(rate(blocky_cache_hits_total[5m])) / (sum(rate(blocky_cache_hits_total[5m])) + sum(rate(blocky_cache_misses_total[5m])))";
              legend = "hit ratio";
            }
          ])
          (tsPanel null "Queries by type (per s)" 0 24 12 8 [
            {
              expr = "sum by (type) (rate(blocky_query_total[5m]))";
              legend = "{{type}}";
            }
          ])
          (tsPanel "s" "Query duration p95" 12 24 12 8 [
            {
              expr = "histogram_quantile(0.95, sum by (le) (rate(blocky_request_duration_seconds_bucket[5m])))";
              legend = "p95";
            }
          ])
          # blocklists refresh every 4h (blocky default); yellow after two
          # missed refreshes, red after a day
          (bigStat "dtdurations"
            (mkSteps [
              [
                null
                "green"
              ]
              [
                28800
                "yellow"
              ]
              [
                86400
                "red"
              ]
            ])
            "List refresh age"
            0
            32
            6
            6
            [
              {
                expr = "time() - blocky_last_list_group_refresh_timestamp_seconds";
                legend = "age";
                instant = true;
              }
            ]
          )
        ];
      };
      minixDashboard = mkDashboard {
        uid = "minix-host";
        title = "Minix";
        tags = [ "fav" ];
        panels = [
          (tsPanel "percent" "CPU busy (%)" 0 0 12 8 [
            {
              expr = ''100 * (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])))'';
              legend = "cpu";
            }
          ])
          (tsPanel null "Load average" 12 0 12 8 [
            {
              expr = "node_load1";
              legend = "1m";
            }
            {
              expr = "node_load5";
              legend = "5m";
            }
            {
              expr = "node_load15";
              legend = "15m";
            }
          ])
          (tsPanel "percent" "Memory used (%)" 0 8 12 8 [
            {
              expr = "100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)";
              legend = "used";
            }
            {
              expr = "100 * (1 - node_memory_SwapFree_bytes / node_memory_SwapTotal_bytes)";
              legend = "swap";
            }
          ])
          (tsPanel "celsius" "Temperatures" 12 8 12 8 [
            {
              # coretemp cores track together (show max); thermal_zone0 is pinned/flat
              expr = ''max(node_hwmon_temp_celsius{chip="platform_coretemp_0"})'';
              legend = "CPU max";
            }
            {
              # single composite reading instead of the three nvme hwmon sensors
              expr = ''smartctl_device_temperature{temperature_type="current"}'';
              legend = "SSD";
            }
          ])
          (tsPanel "Bps" "Disk I/O" 0 16 12 8 [
            {
              expr = "sum(rate(node_disk_read_bytes_total[5m]))";
              legend = "read";
            }
            {
              expr = "sum(rate(node_disk_written_bytes_total[5m]))";
              legend = "write";
            }
          ])
          (tsPanel "Bps" "Network" 12 16 12 8 [
            {
              # wlo1 (wifi) is down with no traffic; vm-bridge duplicates the
              # tap devices
              expr = ''rate(node_network_receive_bytes_total{device!~"lo|wlo1|vm-bridge"}[5m])'';
              legend = "{{device}} rx";
            }
            {
              expr = ''rate(node_network_transmit_bytes_total{device!~"lo|wlo1|vm-bridge"}[5m])'';
              legend = "{{device}} tx";
            }
          ])
          (barPanel "percent" 100 "Filesystem used (%)" 0 24 16 8 [
            {
              # /nix/store is a bind mount of the root partition
              expr = ''100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs|overlay",mountpoint!="/nix/store"} / node_filesystem_size_bytes{fstype!~"tmpfs|ramfs|overlay",mountpoint!="/nix/store"})'';
              legend = "{{mountpoint}}";
              instant = true;
            }
          ])
          (bigStat "dtdurations" alwaysGreen "Uptime" 16 24 8 8 [
            {
              expr = "time() - node_boot_time_seconds";
              legend = "uptime";
              instant = true;
            }
          ])
          (tsPanel "Mbits" "Internet speed" 0 32 12 8 [
            {
              expr = "max(internet_speed_download)";
              legend = "down";
            }
            {
              expr = "max(internet_speed_upload)";
              legend = "up";
            }
          ])
          (tsPanel "ms" "Ping (ms)" 12 32 12 8 [
            {
              expr = "ping_average_response_ms";
              legend = "{{url}}";
            }
          ])
          (tsPanel "percent" "Packet loss (%)" 0 40 12 8 [
            {
              expr = "ping_percent_packet_loss";
              legend = "{{url}}";
            }
            {
              # the speedtest reports -1 when loss wasn't measured
              expr = "max(internet_speed_packet_loss >= 0)";
              legend = "speedtest";
            }
          ])
          (bigStat "percent"
            (mkSteps [
              [
                null
                "green"
              ]
              [
                50
                "yellow"
              ]
              [
                80
                "red"
              ]
            ])
            "SSD wear"
            12
            40
            6
            4
            [
              {
                expr = "smartctl_device_percentage_used";
                legend = "wear";
                instant = true;
              }
            ]
          )
          (bigStat "percent"
            (mkSteps [
              [
                null
                "red"
              ]
              [
                50
                "green"
              ]
            ])
            "SSD spare"
            18
            40
            6
            4
            [
              {
                expr = "smartctl_device_available_spare";
                legend = "spare";
                instant = true;
              }
            ]
          )
          (bigStat "none"
            (mkSteps [
              [
                null
                "green"
              ]
              [
                1
                "red"
              ]
            ])
            "SSD media errors"
            12
            44
            6
            4
            [
              {
                expr = "smartctl_device_media_errors";
                legend = "errors";
                instant = true;
              }
            ]
          )
          (bigStat "dtdurations" alwaysGreen "SSD power-on" 18 44 6 4 [
            {
              expr = "smartctl_device_power_on_seconds";
              legend = "power-on";
              instant = true;
            }
          ])
        ];
      };
      # landing page: a single dashlist panel that lists all dashboards, set as
      # the default home dashboard below
      homeDashboard = {
        uid = "home";
        title = "Dashboards";
        schemaVersion = 39;
        editable = true;
        panels = [
          {
            title = "Dashboards";
            type = "dashlist";
            gridPos = {
              x = 0;
              y = 0;
              w = 24;
              h = 20;
            };
            options = {
              showStarred = false;
              showRecentlyViewed = false;
              showSearch = true;
              showHeadings = false;
              maxItems = 100;
              query = "";
              # curated "favorites" list: only dashboards tagged "fav" (anonymous
              # auth can't use real per-user stars)
              tags = [ "fav" ];
            };
          }
        ];
      };
      dashboardsDir = pkgs.symlinkJoin {
        name = "grafana-friday-dashboards";
        paths = [
          (pkgs.writeTextDir "home.json" (builtins.toJSON homeDashboard))
          (pkgs.writeTextDir "friday-home.json" (builtins.toJSON dashboard))
          (pkgs.writeTextDir "blocky.json" (builtins.toJSON blockyDashboard))
          (pkgs.writeTextDir "minix.json" (builtins.toJSON minixDashboard))
        ];
      };
    in
    {
      enable = true;
      settings = {
        server = {
          http_addr = "0.0.0.0";
          http_port = ports.grafana;
          domain = "minix";
          root_url = "http://minix:${toString ports.grafana}/";
        };
        users.allow_sign_up = false;
        # Grafana 13's dynamic dashboards (dashboardNewLayouts, default-on) render
        # an always-present right rail (Export / Outline / Dock) even in view mode;
        # there's no config to hide just the rail, so disable the toggle to fall
        # back to the classic edit experience (fine for these provisioned dashboards)
        feature_toggles.dashboardNewLayouts = false;
        # landing page = the dashlist "Dashboards" home dashboard, not Grafana's
        # default welcome screen
        dashboards.default_home_dashboard_path = "${dashboardsDir}/home.json";
        security.secret_key = "$__file{${config.sops.secrets.grafana_secret_key.path}}";
        "auth.anonymous" = {
          enabled = true;
          org_role = "Admin";
        };
      };
      provision = {
        enable = true;
        datasources.settings = {
          apiVersion = 1;
          datasources = [
            {
              name = "VictoriaMetrics";
              uid = "victoriametrics";
              type = "prometheus";
              access = "proxy";
              url = "http://127.0.0.1:${toString ports.victoriametrics}";
              isDefault = true;
            }
          ];
        };
        dashboards.settings = {
          apiVersion = 1;
          providers = [
            {
              name = "friday";
              type = "file";
              # let dashboards be edited + saved live in the UI (no rebuild per tweak)
              allowUiUpdates = true;
              options.path = dashboardsDir;
            }
          ];
        };
      };
    };
}
