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
      mkTargets = map (
        t:
        {
          datasource = ds;
          expr = t.expr;
          legendFormat = t.legend;
          refId = t.refId;
        }
        // lib.optionalAttrs (t ? instant) { inherit (t) instant; }
      );
      tsPanel = title: x: y: w: h: targets: {
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
          };
          overrides = [ ];
        };
        options = { };
      };
      # timeseries with a unit on the y-axis (e.g. "percent", "percentunit")
      tsPanelUnit =
        unit: title: x: y: w: h: targets:
        (tsPanel title x y w h targets)
        // {
          fieldConfig = {
            defaults = {
              inherit unit;
              custom.spanNulls = true;
            };
            overrides = [ ];
          };
        };
      panel = tsPanel;
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
              steps = [
                {
                  value = null;
                  color = "red";
                }
                {
                  value = 1;
                  color = "green";
                }
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
      alwaysGreen = [
        {
          value = null;
          color = "green";
        }
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
          (panel "Temperatures (°C)" 0 0 24 8 [
            {
              expr = ''env_value{metric="temperature",device="sensor_living_room_temperature"}'';
              legend = "living room";
              refId = "A";
            }
            {
              expr = ''heater_value{metric="current_temperature"}'';
              legend = "{{device}} current";
              refId = "B";
            }
          ])
          (panel "Humidity (%)" 0 8 12 8 [
            {
              expr = ''env_value{metric="humidity"}'';
              legend = "{{device}}";
              refId = "A";
            }
          ])
          (panel "Studio pressure (hPa)" 12 8 12 8 [
            {
              expr = ''env_value{metric="pressure"}'';
              legend = "pressure";
              refId = "A";
            }
          ])
          (panel "Heater: current vs setpoint (°C)" 0 16 12 8 [
            {
              expr = ''heater_value{metric="current_temperature"}'';
              legend = "{{device}} current";
              refId = "A";
            }
            {
              expr = ''heater_value{metric="temperature"}'';
              legend = "{{device}} setpoint";
              refId = "B";
            }
          ])
          (panel "Heater power drawn (W)" 12 16 12 8 [
            {
              expr = ''heater_value{metric="power"} * on(device) group_left() heater_active_value'';
              legend = "{{device}}";
              refId = "A";
            }
          ])
          (tsPanelUnit "percent" "Batteries (%)" 0 24 12 8 [
            {
              expr = "camera_battery_value";
              legend = "{{device}}";
              refId = "A";
            }
            {
              expr = ''env_value{metric="battery"}'';
              legend = "{{device}}";
              refId = "B";
            }
          ])
          # camera_state is the dense 30s sampling of the retained status topic
          # (see metrics.nix); camera_status is the raw transition events
          (barPanel "h" null "Camera connected time, in range (h)" 12 24 12 8 [
            {
              expr = "integrate(camera_state_value[$__range]) / 3600";
              legend = "{{device}}";
              refId = "A";
              instant = true;
            }
          ])
          (statePanel "Camera connection" 0 32 24 6 [
            {
              expr = "camera_state_value";
              legend = "{{device}}";
              refId = "A";
            }
          ])
          (statePanel "Camera PIR" 0 38 24 6 [
            {
              expr = "camera_pir_value";
              legend = "{{device}}";
              refId = "A";
            }
          ])
        ];
      };
      blockyDashboard = mkDashboard {
        uid = "blocky-dns";
        title = "Blocky";
        tags = [ "fav" ];
        panels = [
          (panel "Queries/s" 0 0 12 8 [
            {
              expr = "sum(rate(blocky_query_total[5m]))";
              legend = "queries/s";
              refId = "A";
            }
          ])
          (panel "Responses by type (per s)" 12 0 12 8 [
            {
              expr = "sum by (response_type) (rate(blocky_response_total[5m]))";
              legend = "{{response_type}}";
              refId = "A";
            }
          ])
          (tsPanelUnit "percentunit" "Blocked share" 0 8 12 8 [
            {
              expr = ''sum(rate(blocky_response_total{response_type="BLOCKED"}[5m])) / sum(rate(blocky_response_total[5m]))'';
              legend = "blocked";
              refId = "A";
            }
          ])
          (panel "Top clients (queries/s)" 12 8 12 8 [
            {
              # topk() picks top 5 per step (legend fills up with dozens of
              # clients); topk_avg picks 5 series across the whole range
              expr = "topk_avg(5, sum by (client) (rate(blocky_query_total[5m])))";
              legend = "{{client}}";
              refId = "A";
            }
          ])
          (panel "Cache entries" 0 16 12 8 [
            {
              expr = "blocky_cache_entries";
              legend = "entries";
              refId = "A";
            }
          ])
          (tsPanelUnit "percentunit" "Cache hit ratio" 12 16 12 8 [
            {
              expr = "sum(rate(blocky_cache_hits_total[5m])) / (sum(rate(blocky_cache_hits_total[5m])) + sum(rate(blocky_cache_misses_total[5m])))";
              legend = "hit ratio";
              refId = "A";
            }
          ])
          (panel "Queries by type (per s)" 0 24 12 8 [
            {
              expr = "sum by (type) (rate(blocky_query_total[5m]))";
              legend = "{{type}}";
              refId = "A";
            }
          ])
          (tsPanelUnit "s" "Query duration p95" 12 24 12 8 [
            {
              expr = "histogram_quantile(0.95, sum by (le) (rate(blocky_request_duration_seconds_bucket[5m])))";
              legend = "p95";
              refId = "A";
            }
          ])
          # blocklists refresh every 4h (blocky default); yellow after two
          # missed refreshes, red after a day
          (bigStat "dtdurations"
            [
              {
                value = null;
                color = "green";
              }
              {
                value = 28800;
                color = "yellow";
              }
              {
                value = 86400;
                color = "red";
              }
            ]
            "List refresh age"
            0
            32
            6
            6
            [
              {
                expr = "time() - blocky_last_list_group_refresh_timestamp_seconds";
                legend = "age";
                refId = "A";
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
          (tsPanelUnit "percent" "CPU busy (%)" 0 0 12 8 [
            {
              expr = ''100 * (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])))'';
              legend = "cpu";
              refId = "A";
            }
          ])
          (panel "Load average" 12 0 12 8 [
            {
              expr = "node_load1";
              legend = "1m";
              refId = "A";
            }
            {
              expr = "node_load5";
              legend = "5m";
              refId = "B";
            }
            {
              expr = "node_load15";
              legend = "15m";
              refId = "C";
            }
          ])
          (tsPanelUnit "percent" "Memory used (%)" 0 8 12 8 [
            {
              expr = "100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)";
              legend = "used";
              refId = "A";
            }
            {
              expr = "100 * (1 - node_memory_SwapFree_bytes / node_memory_SwapTotal_bytes)";
              legend = "swap";
              refId = "B";
            }
          ])
          (tsPanelUnit "celsius" "Temperatures" 12 8 12 8 [
            {
              # coretemp cores track together (show max); thermal_zone0 is pinned/flat
              expr = ''max(node_hwmon_temp_celsius{chip="platform_coretemp_0"})'';
              legend = "CPU max";
              refId = "A";
            }
            {
              # single composite reading instead of the three nvme hwmon sensors
              expr = ''smartctl_device_temperature{temperature_type="current"}'';
              legend = "SSD";
              refId = "B";
            }
          ])
          (tsPanelUnit "Bps" "Disk I/O" 0 16 12 8 [
            {
              expr = "sum(rate(node_disk_read_bytes_total[5m]))";
              legend = "read";
              refId = "A";
            }
            {
              expr = "sum(rate(node_disk_written_bytes_total[5m]))";
              legend = "write";
              refId = "B";
            }
          ])
          (tsPanelUnit "Bps" "Network" 12 16 12 8 [
            {
              # wlo1 (wifi) is down with no traffic; vm-bridge duplicates the
              # tap devices
              expr = ''rate(node_network_receive_bytes_total{device!~"lo|wlo1|vm-bridge"}[5m])'';
              legend = "{{device}} rx";
              refId = "A";
            }
            {
              expr = ''rate(node_network_transmit_bytes_total{device!~"lo|wlo1|vm-bridge"}[5m])'';
              legend = "{{device}} tx";
              refId = "B";
            }
          ])
          (barPanel "percent" 100 "Filesystem used (%)" 0 24 16 8 [
            {
              # /nix/store is a bind mount of the root partition
              expr = ''100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs|overlay",mountpoint!="/nix/store"} / node_filesystem_size_bytes{fstype!~"tmpfs|ramfs|overlay",mountpoint!="/nix/store"})'';
              legend = "{{mountpoint}}";
              refId = "A";
              instant = true;
            }
          ])
          (bigStat "dtdurations" alwaysGreen "Uptime" 16 24 8 8 [
            {
              expr = "time() - node_boot_time_seconds";
              legend = "uptime";
              refId = "A";
              instant = true;
            }
          ])
          (tsPanelUnit "Mbits" "Internet speed" 0 32 12 8 [
            {
              expr = "max(internet_speed_download)";
              legend = "down";
              refId = "A";
            }
            {
              expr = "max(internet_speed_upload)";
              legend = "up";
              refId = "B";
            }
          ])
          (tsPanelUnit "ms" "Internet latency" 12 32 12 8 [
            {
              expr = "max(internet_speed_latency)";
              legend = "latency";
              refId = "A";
            }
            {
              expr = "max(internet_speed_jitter)";
              legend = "jitter";
              refId = "B";
            }
          ])
          (tsPanelUnit "percent" "Packet loss (%)" 0 40 12 8 [
            {
              # the exporter reports -1 when loss wasn't measured
              expr = "max(internet_speed_packet_loss >= 0)";
              legend = "packet loss";
              refId = "A";
            }
          ])
          (bigStat "percent"
            [
              {
                value = null;
                color = "green";
              }
              {
                value = 50;
                color = "yellow";
              }
              {
                value = 80;
                color = "red";
              }
            ]
            "SSD wear"
            12
            40
            6
            4
            [
              {
                expr = "smartctl_device_percentage_used";
                legend = "wear";
                refId = "A";
                instant = true;
              }
            ]
          )
          (bigStat "percent"
            [
              {
                value = null;
                color = "red";
              }
              {
                value = 50;
                color = "green";
              }
            ]
            "SSD spare"
            18
            40
            6
            4
            [
              {
                expr = "smartctl_device_available_spare";
                legend = "spare";
                refId = "A";
                instant = true;
              }
            ]
          )
          (bigStat "none"
            [
              {
                value = null;
                color = "green";
              }
              {
                value = 1;
                color = "red";
              }
            ]
            "SSD media errors"
            12
            44
            6
            4
            [
              {
                expr = "smartctl_device_media_errors";
                legend = "errors";
                refId = "A";
                instant = true;
              }
            ]
          )
          (bigStat "dtdurations" alwaysGreen "SSD power-on" 18 44 6 4 [
            {
              expr = "smartctl_device_power_on_seconds";
              legend = "power-on";
              refId = "A";
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
        analytics.reporting_enabled = false;
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
              url = "http://127.0.0.1:8428";
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
