{
  config,
  pkgs,
  lib,
  ...
}:
let
  mqtt = import ./mqtt.nix;
  ports = import ./ports.nix;
  net = import ./net.nix;
  keys = import ../../keys.nix;
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
  # pushover caps messages at 1024 chars
  smartdPushoverMailer = pkgs.writeShellScript "smartd-pushover-mailer" ''
    export PATH=${
      lib.makeBinPath [
        pkgs.bash
        pkgs.coreutils
        pkgs.curl
      ]
    }:$PATH
    message=$(head -c 1024)
    PUSHOVERRC=${config.sops.templates."pushoverrc".path} \
      exec ${config.users.users.szymon.home}/.bin/notify-pushover "$message"
  '';
in
{
  imports = [
    ../../modules/nixos/common.nix
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
  # initrd (systemd stage-1's panic-on-fail unit) crash the kernel on failure
  # instead of waiting in the emergency shell
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
      LinkLocalAddressing = "no";
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

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.openssh.enable = true;

  programs.ssh.knownHosts.berry.publicKey = keys.berryHost;

  programs.mosh.enable = true;

  # tailscale with exit node
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "server";
  services.tailscale.extraUpFlags = [ "--advertise-exit-node" ];

  networking.nameservers = [ "127.0.0.1" ];

  # resolved needed: useNetworkd enables its stub listener on :53 (conflicts with blocky),
  # and without it tailscale clobbers /etc/resolv.conf via resolvconf (tailscale#9687)
  services.resolved.enable = true;
  services.resolved.settings.Resolve.DNSStubListener = "no";

  # microvm lifecycle is granted via polkit below; the cleanup rm's need root.
  # a root-owned script with internal validation, because sudoers matches
  # arguments as one concatenated string - a path glob like MicroVMs/vm-*/data
  # would also match "vm-1 /any/path/data"
  security.sudo.extraRules = [
    {
      users = [ "szymon" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/microvm-clean";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # start/stop/kill/reset-failed the microvm guest and its virtiofsd sidecar without sudo
  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" && subject.user == "szymon") {
        var unit = action.lookup("unit");

        if (unit && /^microvm(-virtiofsd)?@vm-[0-9]+\.service$/.test(unit)) {
          return polkit.Result.YES;
        }
      }
    });
  '';

  users.users.szymon = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "systemd-journal"
    ];
    shell = pkgs.zsh;
    linger = true;
    openssh.authorizedKeys.keys = [
      keys.orchid
      keys.berry
    ];
  };

  # berry offloads its builds here; the module confines the nix-ssh user to
  # `nix-daemon --stdio` via sshd, and trusted lets berry push unsigned paths
  nix.sshServe = {
    enable = true;
    protocol = "ssh-ng";
    trusted = true;
    keys = [ keys.berryBuilder ];
  };

  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 5;
  };

  # qemu user for aarch64 emulation, for Raspberry Pi builds
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  nix.settings.download-buffer-size = 512 * 1024 * 1024; # 512 MiB

  # berry's sd image is built here, and its vendor kernel only exists prebuilt
  # in this cache; without it the kernel would compile under qemu emulation
  nix.settings.substituters = [ "https://nixos-raspberrypi.cachix.org" ];
  nix.settings.trusted-public-keys = [
    "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
  ];
  environment.systemPackages = with pkgs; [
    vim
    git
    restic
    rclone
    (pkgs.writeShellScriptBin "microvm-clean" ''
      set -eu
      op="''${1:-}"
      vm="''${2:-}"
      case "$vm" in
        [1-9]) ;;
        *) echo "usage: microvm-clean <overlay|data> <1-9>" >&2; exit 1 ;;
      esac
      case "$op" in
        overlay) exec ${pkgs.coreutils}/bin/rm -f "/var/lib/microvms/vm-$vm/nix-store-overlay.img" ;;
        data) exec ${pkgs.coreutils}/bin/rm -rf "/home/szymon/MicroVMs/vm-$vm/data" ;;
        *) echo "usage: microvm-clean <overlay|data> <1-9>" >&2; exit 1 ;;
      esac
    '')
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

  sops.secrets.tailscale_authkey_vm_ephemeral = { };
  sops.secrets.pushover_token_vm = { };
  sops.secrets.pushover_token_user = {
    sopsFile = ../../secrets/shared.yaml;
  };
  sops.secrets.searx_secret_key = { };
  sops.secrets.pushover_user = {
    sopsFile = ../../secrets/shared.yaml;
  };

  sops.templates."searx-environment".content = ''
    SEARXNG_SECRET=${config.sops.placeholder.searx_secret_key}
  '';

  # credentials for bin/notify-pushover when run from system units;
  # user units read the home-manager template at ~/.pushoverrc
  sops.templates."pushoverrc".content = ''
    PUSHOVER_TOKEN=${config.sops.placeholder.pushover_token_user}
    PUSHOVER_USER=${config.sops.placeholder.pushover_user}
  '';

  system.activationScripts.microvm-secrets = lib.stringAfter [ "setupSecrets" ] ''
    dir=${config.users.users.szymon.home}/MicroVMs/host
    mkdir -p "$dir"

    cp ${config.sops.secrets.tailscale_authkey_vm_ephemeral.path} "$dir/ts-authkey"

    printf 'PUSHOVER_TOKEN=%s\nPUSHOVER_USER=%s\n' \
      "$(cat ${config.sops.secrets.pushover_token_vm.path})" \
      "$(cat ${config.sops.secrets.pushover_user.path})" \
      > "$dir/pushoverrc"

    chown -R szymon:users "$dir"
    chmod 600 "$dir"/{ts-authkey,pushoverrc}
  '';

  system.stateVersion = "25.11";
}
