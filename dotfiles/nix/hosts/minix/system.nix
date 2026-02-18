{ pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "minix";
  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "systemd-resolved";
  networking.networkmanager.unmanaged = [ "interface-name:vm-*" ];
  networking.firewall.enable = false;

  # MicroVM bridge network
  systemd.network.enable = true;
  systemd.network.wait-online.enable = false;
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

  services.resolved.enable = true;
  services.resolved.settings.Resolve.DNSStubListener = "no";
  services.resolved.settings.Resolve.FallbackDNS = [
    "1.1.1.2"
    "1.0.0.2"
  ];

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
      ];
    }
  ];

  users.users.szymon = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
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
  nix.gc.options = "--delete-older-than 14d";

  environment.systemPackages = with pkgs; [
    vim
    git
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

  services.blocky = {
    enable = true;
    settings = {
      ports = {
        dns = 53;
        http = 10002;
      };

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
        denylists = {
          ads = [
            "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.txt"
            "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/tif.txt"
            "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/fake.txt"
            "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/popupads.txt"
            "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/gambling.txt"
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
        type = "csv";
        target = "/var/lib/blocky";
        logRetentionDays = 7;
      };

      prometheus.enable = true;
    };
  };

  virtualisation.podman.enable = true;

  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      mqtt-explorer = {
        image = "ghcr.io/thomasnordquist/mqtt-explorer:latest";
        environment = {
          PORT = "10000";
          MQTT_EXPLORER_SKIP_AUTH = "true";
        };
        extraOptions = [ "--network=host" ];
      };

      blocky-ui = {
        image = "ghcr.io/gabeduartem/blocky-ui:latest";
        environment = {
          TZ = "Europe/Warsaw";
          PORT = "10001";
          BLOCKY_API_URL = "http://localhost:10002";
          QUERY_LOG_TYPE = "csv";
          QUERY_LOG_TARGET = "/logs";
        };
        volumes = [ "/var/lib/blocky:/logs:ro" ];
        extraOptions = [ "--network=host" ];
      };
    };
  };

  system.stateVersion = "25.11";
}
