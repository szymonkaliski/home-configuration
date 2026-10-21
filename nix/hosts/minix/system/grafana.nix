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
        // lib.optionalAttrs (t ? interval) { inherit (t) interval; }
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
      # discrete state over time (holds state between change-points); states is
      # an attrset of value -> { text, color }
      customStatePanel = states: title: x: y: w: h: targets: {
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
            custom.spanNulls = true;
            mappings = [
              {
                type = "value";
                options = lib.listToAttrs (
                  lib.imap0 (i: k: {
                    name = k;
                    value = states.${k} // {
                      index = i;
                    };
                  }) (builtins.attrNames states)
                );
              }
            ];
          };
          overrides = [ ];
        };
        options = {
          mergeValues = true;
          showValue = "auto";
          rowHeight = 0.9;
          legend = {
            showLegend = true;
            displayMode = "list";
            placement = "bottom";
          };
        };
      };
      statePanel = customStatePanel {
        "0" = {
          text = "disconnected";
          color = "red";
        };
        "1" = {
          text = "connected";
          color = "green";
        };
      };
      pirStatePanel = customStatePanel {
        "0" = {
          text = "idle";
          color = "semi-dark-blue";
        };
        "1" = {
          text = "motion";
          color = "orange";
        };
      };
      # per-calendar-month stacked bar chart over the last 12 months; each
      # target is a monotonic cumulative counter, sampled as daily increases
      # (`increase(m[1d] offset -1d)` at 1d step so each UTC day holds its own
      # 00:00->24:00 increase) and summed by YYYY-MM
      monthlyBarPanel = unit: title: x: y: w: h: series: {
        inherit title;
        type = "barchart";
        datasource = ds;
        timeFrom = "400d";
        hideTimeOverride = true;
        gridPos = {
          inherit
            x
            y
            w
            h
            ;
        };
        targets = lib.imap0 (i: s: {
          datasource = ds;
          expr = "increase(${s.metric}[1d] offset -1d)";
          legendFormat = s.legend;
          interval = "1d";
          refId = builtins.elemAt lib.upperChars i;
        }) series;
        transformations = [
          {
            id = "joinByField";
            options = {
              byField = "Time";
              mode = "outer";
            };
          }
          {
            id = "convertFieldType";
            options = {
              conversions = [
                {
                  targetField = "Time";
                  destinationType = "string";
                  dateFormat = "YYYY-MM";
                  timezone = "utc";
                }
              ];
            };
          }
          {
            id = "groupBy";
            options = {
              fields = {
                Time = {
                  operation = "groupby";
                  aggregations = [ ];
                };
              }
              // lib.listToAttrs (
                map (s: {
                  name = s.legend;
                  value = {
                    operation = "aggregate";
                    aggregations = [ "sum" ];
                  };
                }) series
              );
            };
          }
          {
            id = "renameByRegex";
            options = {
              regex = "^(.*) \\(sum\\)$";
              renamePattern = "$1";
            };
          }
          {
            id = "limit";
            options = {
              limitField = -12;
            };
          }
        ];
        fieldConfig = {
          defaults = {
            inherit unit;
          };
          overrides = [ ];
        };
        options = {
          xField = "Time";
          stacking = "normal";
          showValue = "auto";
          xTickLabelRotation = -45;
          legend = {
            showLegend = true;
            displayMode = "list";
            placement = "bottom";
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
          graphTooltip = 1;
          preload = true;
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
          (tsPanel "celsius" "Temperatures (°C)" 0 0 24 8 [
            {
              expr = ''env_value{metric="temperature"}'';
              legend = "{{device}}";
            }
            {
              expr = ''env_value{device="vaillant",metric="room_temperature"}'';
              legend = "{{device}}_{{metric}}";
            }
            {
              expr = ''heater_value{metric="current_temperature"}'';
              legend = "{{device}} current";
            }
            {
              expr = ''env_value{device="vaillant",metric="outdoor_temperature"}'';
              legend = "{{device}}_{{metric}}";
            }
          ])
          (tsPanel "percent" "Humidity (%)" 0 8 12 8 [
            {
              expr = ''env_value{metric="humidity"}'';
              legend = "{{device}}";
            }
            {
              expr = ''env_value{device="vaillant",metric="room_humidity"}'';
              legend = "{{device}}_{{metric}}";
            }
          ])
          (tsPanel "pressurehpa" "Studio pressure (hPa)" 12 8 12 8 [
            {
              expr = ''env_value{metric="pressure"}'';
              legend = "pressure";
            }
          ])
          (customStatePanel
            {
              "0" = {
                text = "standby";
                color = "semi-dark-blue";
              };
              "1" = {
                text = "heating";
                color = "orange";
              };
              "2" = {
                text = "cooling";
                color = "light-blue";
              };
              "3" = {
                text = "hot water";
                color = "yellow";
              };
            }
            "Boiler status"
            0
            16
            12
            5
            [
              {
                expr = ''vaillant_state_value{metric="system_status"}'';
                legend = "status";
              }
            ]
          )
          (customStatePanel
            {
              "0" = {
                text = "ok";
                color = "green";
              };
              "1" = {
                text = "fault";
                color = "red";
              };
            }
            "Boiler fault"
            12
            16
            12
            5
            [
              {
                expr = ''vaillant_state_value{metric="fault_status"}'';
                legend = "fault";
              }
            ]
          )
          (monthlyBarPanel "kwatth" "Heater electricity per month (kWh)" 0 21 8 8 [
            {
              metric = ''heater_value{device="heater_1",metric="energy"}'';
              legend = "heater_1";
            }
            {
              metric = ''heater_value{device="heater_2",metric="energy"}'';
              legend = "heater_2";
            }
          ])
          (monthlyBarPanel "kwatth" "Boiler electricity per month (kWh)" 8 21 8 8 [
            {
              metric = ''env_value{device="vaillant",metric="electricity_heating"}'';
              legend = "heating";
            }
            {
              metric = ''env_value{device="vaillant",metric="electricity_hot_water"}'';
              legend = "hot water";
            }
          ])
          (monthlyBarPanel "kwatth" "Boiler gas per month (kWh)" 16 21 8 8 [
            {
              metric = ''env_value{device="vaillant",metric="gas_heating"}'';
              legend = "heating";
            }
            {
              metric = ''env_value{device="vaillant",metric="gas_hot_water"}'';
              legend = "hot water";
            }
          ])
          (tsPanel "percent" "Batteries (%)" 0 29 24 8 [
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
          (statePanel "Camera connection" 0 37 24 6 [
            {
              expr = "camera_state_value";
              legend = "{{device}}";
            }
          ])
          (pirStatePanel "Camera PIR" 0 43 24 6 [
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
              expr = ''sum by (response_type) (rate(blocky_response_total{response_type!="RESOLVED"}[5m]))'';
              legend = "{{response_type}}";
            }
            {
              expr = ''sum by (reason) (rate(blocky_response_total{response_type="RESOLVED"}[5m]))'';
              legend = "{{reason}}";
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
          (bigStat "short"
            (mkSteps [
              [
                null
                "red"
              ]
              [
                1
                "green"
              ]
            ])
            "Denylist entries"
            6
            32
            6
            6
            [
              {
                expr = "sum(blocky_denylist_cache_entries)";
                legend = "entries";
                instant = true;
              }
            ]
          )
          (bigStat "short" alwaysGreen "Prefetch cache" 12 32 6 6 [
            {
              expr = "blocky_prefetch_domain_name_cache_entries";
              legend = "domains";
              instant = true;
            }
          ])
          (bigStat "none"
            (mkSteps [
              [
                null
                "green"
              ]
              [
                1
                "yellow"
              ]
              [
                10
                "red"
              ]
            ])
            "Errors (in range)"
            18
            32
            6
            6
            [
              {
                expr = "round(sum(increase(blocky_error_total[$__range])) + sum(increase(blocky_failed_downloads_total[$__range])))";
                legend = "errors";
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
          (tsPanel "percent" "Memory used (%)" 12 0 12 8 [
            {
              expr = "100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)";
              legend = "used";
            }
            {
              expr = "100 * (1 - node_memory_SwapFree_bytes / node_memory_SwapTotal_bytes)";
              legend = "swap";
            }
          ])
          (tsPanel "celsius" "Temperatures" 0 8 8 8 [
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
          (tsPanel "Bps" "Disk I/O" 8 8 8 8 [
            {
              expr = "sum(rate(node_disk_read_bytes_total[5m]))";
              legend = "read";
            }
            {
              expr = "sum(rate(node_disk_written_bytes_total[5m]))";
              legend = "write";
            }
          ])
          (tsPanel "Bps" "Network" 16 8 8 8 [
            {
              # wlo1 (wifi) is down with no traffic; vm-bridge duplicates the
              # tap devices
              expr = ''rate(node_network_receive_bytes_total{device!~"lo|wlo1|vm-bridge|vm-tap.*"}[5m])'';
              legend = "{{device}} rx";
            }
            {
              expr = ''rate(node_network_transmit_bytes_total{device!~"lo|wlo1|vm-bridge|vm-tap.*"}[5m])'';
              legend = "{{device}} tx";
            }
            {
              expr = ''sum(rate(node_network_receive_bytes_total{device=~"vm-tap.*"}[5m]))'';
              legend = "microvms rx";
            }
            {
              expr = ''sum(rate(node_network_transmit_bytes_total{device=~"vm-tap.*"}[5m]))'';
              legend = "microvms tx";
            }
          ])
          (tsPanel "Mbits" "Internet speed" 0 16 8 8 [
            {
              expr = "max(internet_speed_download)";
              legend = "down";
              interval = "1h";
            }
            {
              expr = "max(internet_speed_upload)";
              legend = "up";
              interval = "1h";
            }
          ])
          (tsPanel "ms" "Ping (ms)" 8 16 8 8 [
            {
              expr = "ping_average_response_ms";
              legend = "{{url}}";
            }
          ])
          (tsPanel "percent" "Packet loss (%)" 16 16 8 8 [
            {
              expr = "ping_percent_packet_loss";
              legend = "{{url}}";
            }
            {
              # the speedtest reports -1 when loss wasn't measured
              expr = "max(internet_speed_packet_loss >= 0)";
              legend = "speedtest";
              interval = "1h";
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
