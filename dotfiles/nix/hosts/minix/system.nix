{
  config,
  pkgs,
  lib,
  ...
}:
let
  mqtt = import ../../mqtt.nix;
  ports = import ./ports.nix;
  net = import ./net.nix;
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
            name = "telegraphist";
            url = "https://minix.golden-minor.ts.net:${toString ports.telegraphist}";
          }
          {
            name = "property search";
            url = "http://minix:${toString ports.propertySearch}";
          }
          {
            name = "neolink dashboard";
            url = "http://minix:${toString ports.neolinkDashboard}";
          }
          {
            name = "searxng";
            url = "http://minix:${toString ports.searx}";
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
            name = "glances";
            url = "http://minix:${toString ports.glances}";
          }
          {
            name = "grafana";
            url = "http://minix:${toString ports.grafana}";
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
  # sendmail-compatible: message arrives on stdin, recipient args are ignored.
  # pushover caps messages at 1024 chars. same pushover app as notify-pushover.
  smartdPushoverMailer = pkgs.writeShellScript "smartd-pushover-mailer" ''
    message=$(${pkgs.coreutils}/bin/head -c 1024)
    ${pkgs.curl}/bin/curl -fsS --retry 3 --max-time 30 \
      --form-string "token=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.pushover_token_user.path})" \
      --form-string "user=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.pushover_user.path})" \
      --form-string "title=smartd on minix" \
      --form-string "message=$message" \
      https://api.pushover.net/1/messages.json >/dev/null
  '';
in
{
  imports = [
    ./system/grafana.nix
    ./system/metrics.nix
    ./system/blocky.nix
    ./system/backup.nix
    ./system/file-sharing.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # panic=30 reboots 30s after a kernel panic; boot.panic_on_fail makes the
  # scripted initrd reboot instead of dropping to a rescue shell
  boot.kernelParams = [
    "panic=30"
    "boot.panic_on_fail"
  ];

  # iTCO_wdt (30s hw max): systemd resets the box if PID1 hangs after boot
  systemd.settings.Manager.RuntimeWatchdogSec = "20s";

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
    addresses = [ { Address = "${net.gateway}/${toString net.prefixLength}"; } ];
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
  services.resolved.settings.Resolve.DNSStubListener = "no";
  # avahi already provides mDNS; disable resolved's so they don't both respond
  services.resolved.settings.Resolve.MulticastDNS = "no";

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
  # /etc/zshrc otherwise runs a full `compinit` (~40-50ms security audit) before
  # our own; dotfiles/zsh/completion.zsh extends fpath and runs compinit itself,
  # so skip the redundant global one.
  programs.zsh.enableGlobalCompInit = false;

  # We set our own PROMPT (dotfiles/zsh/prompt.zsh) and load our own dircolors
  # (deferred, dotfiles/zsh/colors.zsh), so skip /etc/zshrc's `prompt suse` line
  # and its dircolors fork.
  programs.zsh.promptInit = "";
  programs.zsh.enableLsColors = false;

  # claude-code ships native ELF binaries (the launcher itself plus embedded
  # ugrep/bfs/rg dispatched via ARGV0); they hardcode /lib64/ld-linux-x86-64.so.2.
  # nix-ld's shim at that path makes them all run without per-binary wrappers.
  programs.nix-ld.enable = true;

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

  # zigbee2mqtt exits if the broker isn't up yet
  systemd.services.zigbee2mqtt = {
    after = [ "mosquitto.service" ];
    wants = [ "mosquitto.service" ];
  };

  services.glances = {
    enable = true;
    port = ports.glances;
  };

  services.smartd = {
    enable = true;
    notifications = {
      wall.enable = false;
      mail = {
        enable = true;
        mailer = smartdPushoverMailer;
      };
    };
  };

  # SearXNG metasearch, built-in HTTP server on the LAN.
  # secret_key comes via envsubst from the sops environment file so it stays
  # out of the world-readable nix store.
  services.searx = {
    enable = true;
    environmentFile = config.sops.templates."searx-environment".path;
    settings = {
      server = {
        bind_address = "0.0.0.0";
        port = ports.searx;
        secret_key = "$SEARXNG_SECRET";
      };
      search.autocomplete = "duckduckgo";
      ui.default_locale = "en";
    };
  };

  services.darkhttpd = {
    enable = true;
    port = 80;
    address = "::";
    rootDir = "${homepageRoot}";
  };

  sops.defaultSopsFile = ../../secrets/minix.yaml;
  sops.age.keyFile = "${config.users.users.szymon.home}/.config/sops/age/keys.txt";

  sops.secrets.tailscale_authkey = { };
  sops.secrets.pushover_token_vm = { };
  sops.secrets.pushover_token_user = { };
  sops.secrets.searx_secret_key = { };
  sops.secrets.pushover_user = {
    sopsFile = ../../secrets/shared.yaml;
  };

  sops.templates."searx-environment".content = ''
    SEARXNG_SECRET=${config.sops.placeholder.searx_secret_key}
  '';

  system.activationScripts.microvm-secrets = lib.stringAfter [ "setupSecrets" ] ''
    dir=${config.users.users.szymon.home}/MicroVMs/host
    mkdir -p "$dir"

    cp ${config.sops.secrets.tailscale_authkey.path} "$dir/ts-authkey"

    printf 'PUSHOVER_TOKEN=%s\nPUSHOVER_USER=%s\n' \
      "$(cat ${config.sops.secrets.pushover_token_vm.path})" \
      "$(cat ${config.sops.secrets.pushover_user.path})" \
      > "$dir/pushoverrc"

    chown -R szymon:users "$dir"
    chmod 600 "$dir"/{ts-authkey,pushoverrc}
  '';

  system.stateVersion = "25.11";
}
