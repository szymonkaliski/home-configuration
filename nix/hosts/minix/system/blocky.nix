{ config, lib, ... }:
let
  ports = import ../ports.nix;
  dns = import ../dns.nix;
  queryLogTarget = "postgres://blocky@127.0.0.1:${toString ports.blockyPostgresql}/blocky?sslmode=disable";
in
{
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "blocky" ];
    ensureUsers = [
      {
        name = "blocky";
        ensureDBOwnership = true;
      }
    ];
    authentication = lib.mkAfter ''
      host blocky blocky 127.0.0.1/32 trust
    '';
    settings.port = ports.blockyPostgresql;
  };

  systemd.services.blocky = {
    after = [
      "network-online.target"
      "postgresql.target"
    ];
    wants = [
      "network-online.target"
      "postgresql.target"
    ];
    serviceConfig = {
      Restart = lib.mkForce "always"; # upstream sets on-failure, whole network depends on blocky
      RestartSec = "2s";
    };
  };

  services.blocky = {
    enable = true;
    settings = {
      ports = {
        dns = 53;
        http = ports.blockyApi;
      };

      connectIPVersion = "v4";

      # IPv4-only network; drop AAAA so clients don't try unreachable v6 via
      # tailscale's ULA and fail with ENETUNREACH
      filtering.queryTypes = [ "AAAA" ];

      upstreams.groups.default = [
        dns.quad9.upstream
        dns.cloudflare.upstream
      ];

      bootstrapDns = [
        dns.quad9
        dns.cloudflare
      ];

      blocking = {
        loading = {
          strategy = "fast";
          downloads = {
            attempts = 5;
            cooldown = "10s";
            timeout = "60s";
          };
        };
        # hagezi's github account is locked and all its repos return 404
        # this gitlab repo is the maintainer's own mirror
        denylists = {
          ads = [
            "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/wildcard/dyndns.txt"
            "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/wildcard/fake.txt"
            "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/wildcard/gambling.txt"
            "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/wildcard/pro.txt"
            "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/wildcard/tif.txt"
          ];
        };
        clientGroupsBlock.default = [ "ads" ];
        blockType = "zeroIp";
      };

      caching = {
        prefetching = true;
        minTime = "5m";
      };

      queryLog = {
        type = "postgresql";
        target = queryLogTarget;
        logRetentionDays = 30;
      };

      prometheus.enable = true;
    };
  };

  virtualisation.podman.enable = true;

  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      blocky-ui = {
        image = "ghcr.io/gabeduartem/blocky-ui:latest";
        environment = {
          TZ = config.time.timeZone;
          PORT = toString ports.blockyUi;
          BLOCKY_API_URL = "http://localhost:${toString ports.blockyApi}";
          QUERY_LOG_TYPE = "postgresql";
          QUERY_LOG_TARGET = queryLogTarget;
        };
        extraOptions = [ "--network=host" ];
        labels."io.containers.autoupdate" = "registry";
      };
    };
  };

  # re-pulls :latest for io.containers.autoupdate-labeled containers and
  # restarts their units, rolling back on failure
  systemd.timers.podman-auto-update.wantedBy = [ "timers.target" ];
}
