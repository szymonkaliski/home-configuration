{
  config,
  pkgs,
  lib,
  ...
}:
let
  mqtt = import ../../mqtt.nix;
  ports = {
    blockyApi = 10000;
    blockyPostgresql = 10001;
    blockyUi = 10002;
    zigbee2mqtt = 10004;
    archivistUi = 10005;
    webTty = 10006;
    propertySearch = 10007;
    glances = 10003;
  };
  homepageRoot = import ./homepage {
    inherit pkgs lib;
    title = "minix";
    glancesPort = ports.glances;
    sections = [
      {
        label = "apps";
        items = [
          {
            name = "archivist";
            url = "http://minix:${toString ports.archivistUi}";
          }
          {
            name = "property search";
            url = "http://minix:${toString ports.propertySearch}";
          }
        ];
      }
      {
        label = "infra";
        items = [
          {
            name = "blocky";
            url = "http://minix:${toString ports.blockyUi}";
          }
          {
            name = "zigbee2mqtt";
            url = "http://minix:${toString ports.zigbee2mqtt}";
          }
          {
            name = "web tty";
            url = "https://minix.golden-minor.ts.net:${toString ports.webTty}";
          }
          {
            name = "glances";
            url = "http://minix:${toString ports.glances}";
          }
        ];
      }
      {
        label = "nas";
        items = [
          {
            name = "synology";
            url = "http://nas:5000";
          }
          {
            name = "plex";
            url = "http://nas:32400/web/index.html";
          }
        ];
      }
    ];
  };
  dns = {
    quad9 = "https://dns.quad9.net/dns-query";
    cloudflare = "https://security.cloudflare-dns.com/dns-query";
  };
in
{
  imports = [ ./claude-env.nix ];

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

  # tailscale with exit node
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "server";
  services.tailscale.authKeyFile = config.sops.secrets.tailscale_authkey.path;
  services.tailscale.extraUpFlags = [ "--advertise-exit-node" ];

  networking.nameservers = [ "127.0.0.1" ];

  # resolved needed: useNetworkd enables its stub listener on :53 (conflicts with blocky),
  # and without it tailscale clobbers /etc/resolv.conf via resolvconf (tailscale#9687)
  services.resolved.enable = true;
  services.resolved.extraConfig = "DNSStubListener=no";

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish.enable = true;
    publish.addresses = true;
    extraServiceFiles.smb = ''
      <?xml version="1.0" standalone='no'?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name>Minix</name>
        <service>
          <type>_smb._tcp</type>
          <port>445</port>
        </service>
        <service>
          <type>_device-info._tcp</type>
          <port>0</port>
          <txt-record>model=MacPro7,1@ECOLOR=226,226,224</txt-record>
        </service>
      </service-group>
    '';
  };

  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "server string" = "Minix";
        "server role" = "standalone";
        "netbios name" = "Minix";
        "fruit:aapl" = "yes";
        "fruit:model" = "MacPro7,1";
        "vfs objects" = "fruit streams_xattr";
      };
      homes = {
        browseable = "no";
        writable = "yes";
        "valid users" = "%S";
      };
    };
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
          command = "/run/current-system/sw/bin/systemctl start --no-block microvm@*";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl stop microvm@*";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl kill microvm@*";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl reset-failed microvm@*";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/rm -f /var/lib/microvms/vm-*/nix-store-overlay.img";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/rm -rf /home/szymon/MicroVMs/vm-*/data";
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
    extraGroups = [
      "wheel"
      "systemd-journal"
    ];
    shell = pkgs.zsh;
    linger = true;
  };

  programs.zsh.enable = true;

  nixpkgs.config.allowUnfree = true;

  zramSwap.enable = true;
  zramSwap.algorithm = "zstd";

  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 5;
  };

  nix.settings.download-buffer-size = 512 * 1024 * 1024; # 512 MiB
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
        port = mqtt.port;
        users.${mqtt.username} = {
          password = mqtt.password;
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
        server = "mqtt://${mqtt.host}:${toString mqtt.port}";
        user = mqtt.username;
        password = mqtt.password;
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
      };
    };
  };

  services.glances = {
    enable = true;
    port = ports.glances;
  };

  services.darkhttpd = {
    enable = true;
    port = 80;
    address = "::";
    rootDir = "${homepageRoot}";
  };

  sops.defaultSopsFile = ../../secrets/minix.yaml;
  sops.age.keyFile = "${config.users.users.szymon.home}/.config/sops/age/keys.txt";

  sops.secrets.restic_password = { };
  sops.secrets.rclone_nas_config = { };
  sops.secrets.samba_password = { };
  sops.secrets.tailscale_authkey = { };
  sops.secrets.pushover_token_vm = { };
  sops.secrets.pushover_user = {
    sopsFile = ../../secrets/shared.yaml;
  };
  sops.secrets.gemini_api_key_vm = { };

  system.activationScripts.samba-password = lib.stringAfter [ "setupSecrets" ] ''
    SMB_PASS=$(cat ${config.sops.secrets.samba_password.path})
    (echo "$SMB_PASS"; echo "$SMB_PASS") | ${pkgs.samba}/bin/smbpasswd -a -s szymon 2>/dev/null
  '';

  system.activationScripts.microvm-secrets = lib.stringAfter [ "setupSecrets" ] ''
    dir=${config.users.users.szymon.home}/MicroVMs/host
    mkdir -p "$dir"

    cp ${config.sops.secrets.tailscale_authkey.path} "$dir/ts-authkey"
    cp ${config.sops.secrets.gemini_api_key_vm.path} "$dir/gemini-api-key"

    printf 'PUSHOVER_TOKEN=%s\nPUSHOVER_USER=%s\n' \
      "$(cat ${config.sops.secrets.pushover_token_vm.path})" \
      "$(cat ${config.sops.secrets.pushover_user.path})" \
      > "$dir/pushoverrc"

    chown -R szymon:users "$dir"
    chmod 600 "$dir"/{ts-authkey,gemini-api-key,pushoverrc}
  '';

  services.restic.backups.nas = {
    initialize = true;
    repository = "rclone:nas:/NAS/Backup/Minix";
    rcloneConfigFile = config.sops.secrets.rclone_nas_config.path;
    passwordFile = config.sops.secrets.restic_password.path;

    paths = [
      "${config.users.users.szymon.home}"
      "/var/lib/zigbee2mqtt"
    ];

    exclude = [
      "**/.direnv"
      "**/node_modules"
      "**/result"
      "${config.users.users.szymon.home}/.cache"
      "${config.users.users.szymon.home}/.cargo"
      "${config.users.users.szymon.home}/.config/sops/age"
      "${config.users.users.szymon.home}/.dropbox"
      "${config.users.users.szymon.home}/.dropbox-dist"
      "${config.users.users.szymon.home}/.nix-defexpr"
      "${config.users.users.szymon.home}/.nix-profile"
      "${config.users.users.szymon.home}/.npm"
      "${config.users.users.szymon.home}/Dropbox"
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
