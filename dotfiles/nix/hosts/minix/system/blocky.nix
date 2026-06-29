{ lib, ... }:
let
  ports = import ../ports.nix;
  dns = {
    quad9 = "https://dns.quad9.net/dns-query";
    cloudflare = "https://security.cloudflare-dns.com/dns-query";
  };
in
{
  services.postgresql = {
    enable = true;
    enableTCPIP = true;
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
      "postgresql.service"
    ];
    wants = [ "network-online.target" ];
    requires = [ "postgresql.service" ];
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
        dns.quad9
        dns.cloudflare
      ];

      bootstrapDns = [
        {
          upstream = dns.quad9;
          ips = [
            "9.9.9.9"
            "149.112.112.112"
          ];
        }
        {
          upstream = dns.cloudflare;
          ips = [
            "1.1.1.2"
            "1.0.0.2"
          ];
        }
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
        denylists = {
          ads = [
            "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/dyndns.txt"
            "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/fake.txt"
            "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/gambling.txt"
            "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/pro.txt"
            "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/tif.txt"
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
        target = "postgres://blocky@127.0.0.1:${toString ports.blockyPostgresql}/blocky?sslmode=disable";
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
          TZ = "Europe/Warsaw";
          PORT = toString ports.blockyUi;
          BLOCKY_API_URL = "http://localhost:${toString ports.blockyApi}";
          QUERY_LOG_TYPE = "postgresql";
          QUERY_LOG_TARGET = "postgres://blocky@127.0.0.1:${toString ports.blockyPostgresql}/blocky?sslmode=disable";
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
