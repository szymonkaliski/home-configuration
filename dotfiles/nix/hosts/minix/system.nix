{ pkgs, lib, ... }:
let
  ports = {
    blockyApi = 10000;
    blockyPostgresql = 10001;
    blockyUi = 10002;
    mqttExplorer = 10003;
    zigbee2mqtt = 10004;
    archivistUi = 10005;
  };
in
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "minix";
  networking.useNetworkd = true;
  networking.useDHCP = false;
  networking.firewall.enable = false;

  systemd.network.enable = true;
  # anyInterface: don't block boot waiting for vm-bridge
  systemd.network.wait-online.anyInterface = true;

  # static IP for main interface, DHCP as fallback
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "enp1s0";
    addresses = [ { Address = "192.168.1.2/24"; } ];
    routes = [ { Gateway = "192.168.1.1"; } ];
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    dhcpV4Config = {
      UseRoutes = false;
      UseDNS = false;
      RouteMetric = 2048;
    };
  };

  # MicroVM bridge network
  systemd.network.netdevs."20-vm-bridge".netdevConfig = {
    Kind = "bridge";
    Name = "vm-bridge";
  };

  systemd.network.networks."20-vm-bridge" = {
    matchConfig.Name = "vm-bridge";
    addresses = [ { Address = "10.100.0.254/24"; } ];
    networkConfig.ConfigureWithoutCarrier = true;
  };

  systemd.network.networks."21-vm-tap" = {
    matchConfig.Name = "vm-tap*";
    networkConfig.Bridge = "vm-bridge";
  };

  networking.nat = {
    enable = true;
    enableIPv6 = false;
    internalInterfaces = [ "vm-bridge" ];
    externalInterface = "enp1s0";
  };
  networking.nftables.enable = true;

  time.timeZone = "Europe/Warsaw";

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.openssh.enable = true;
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "server";
  networking.nameservers = [ "127.0.0.1" ];

  # resolved needed: useNetworkd enables its stub listener on :53 (conflicts with blocky),
  # and without it tailscale clobbers /etc/resolv.conf via resolvconf (tailscale#9687)
  services.resolved.enable = true;
  services.resolved.settings.Resolve.DNSStubListener = "no";

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish.enable = true;
    publish.addresses = true;
  };

  security.sudo.extraRules = [
    {
      users = [ "szymon" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/systemctl start microvm@*";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl stop microvm@*";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/restic snapshots *";
          options = [
            "NOPASSWD"
            "SETENV"
          ];
        }
      ];
    }
  ];

  users.users.szymon = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    linger = true;
  };

  programs.zsh.enable = true;

  nixpkgs.config.allowUnfree = true;

  zramSwap.enable = true;

  nix.settings.download-buffer-size = 536870912;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.gc.automatic = true;
  nix.gc.dates = "weekly";
  nix.gc.options = "--delete-older-than 30d";

  environment.systemPackages = with pkgs; [
    vim
    git
    restic
    rclone
  ];

  services.mosquitto = {
    enable = true;
    listeners = [
      {
        port = 1883;
        users.mqtt = {
          password = "mqtt-secure";
          acl = [ "readwrite #" ];
        };
        settings.allow_anonymous = false;
      }
    ];
  };

  services.zigbee2mqtt = {
    enable = true;
    settings = {
      permit_join = false;
      mqtt = {
        server = "mqtt://localhost:1883";
        user = "mqtt";
        password = "mqtt-secure";
      };
      serial.port = "/dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_6013b3a3df21ec1194b221c32c86906c-if00-port0";
      serial.adapter = "zstack";
      frontend.port = ports.zigbee2mqtt;
      device_options.retain = true;
    };
  };

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

      upstreams.groups.default = [
        "https://security.cloudflare-dns.com/dns-query"
      ];

      bootstrapDns = {
        upstream = "https://security.cloudflare-dns.com/dns-query";
        ips = [
          "1.1.1.2"
          "1.0.0.2"
        ];
      };

      blocking = {
        loading = {
          strategy = "fast";
          downloads = {
            attempts = 5;
            cooldown = "10s";
          };
        };
        denylists = {
          ads = [
            "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/dyndns.txt"
            "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/fake.txt"
            "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/gambling.txt"
            "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.txt"
            "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/tif.txt"
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
        logRetentionDays = 7;
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
      };

      mqtt-explorer = {
        image = "ghcr.io/thomasnordquist/mqtt-explorer:latest";
        environment = {
          PORT = toString ports.mqttExplorer;
          MQTT_EXPLORER_SKIP_AUTH = "true";
        };
        extraOptions = [ "--network=host" ];
      };
    };
  };

  systemd.services.homepage-dashboard.serviceConfig = {
    AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
    CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
    PrivateUsers = lib.mkForce false;
  };

  services.homepage-dashboard = {
    enable = true;
    listenPort = 80;
    allowedHosts = "minix,minix:80,localhost,localhost:80,127.0.0.1,127.0.0.1:80";
    settings = {
      title = "minix";
      theme = "dark";
      color = "zinc";
      headerStyle = "clean";
      useEqualHeights = true;
      hideVersion = true;
    };
    customCSS = ''
      #footer { display: none; }
    '';
    services = [
      {
        Services = [
          {
            "Blocky UI" = {
              href = "http://minix:${toString ports.blockyUi}";
              description = "DNS ad-blocking dashboard";
            };
          }
          {
            "MQTT Explorer" = {
              href = "http://minix:${toString ports.mqttExplorer}";
              description = "MQTT broker inspector";
            };
          }
          {
            "Zigbee2MQTT" = {
              href = "http://minix:${toString ports.zigbee2mqtt}";
              description = "Zigbee device management";
            };
          }
          {
            "Archivist" = {
              href = "http://minix:${toString ports.archivistUi}";
              description = "Media archiver";
            };
          }
        ];
      }
    ];
  };

  services.restic.backups.nas = {
    initialize = true;
    repository = "rclone:nas:/NAS/Backup/Minix";
    rcloneConfigFile = "/etc/rclone-nas.conf";
    passwordFile = "/etc/restic-password";

    paths = [
      "/home/szymon"
      "/var/lib/zigbee2mqtt"
    ];

    exclude = [
      "**/.direnv"
      "**/node_modules"
      "**/result"
      "/home/szymon/.cache"
      "/home/szymon/.cargo"
      "/home/szymon/.dropbox"
      "/home/szymon/.dropbox-dist"
      "/home/szymon/.nix-defexpr"
      "/home/szymon/.nix-profile"
      "/home/szymon/.npm"
      "/home/szymon/Dropbox"
    ];

    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };

    extraBackupArgs = [ "--verbose" ];

    checkOpts = [ "--read-data-subset=5%" ];

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
      "--keep-yearly 2"
    ];
  };

  system.stateVersion = "25.11";
}
