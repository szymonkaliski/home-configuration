{
  hostName,
  ipAddress,
  tapId,
  mac,
}:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  dotfileDir = ../../../../.;
  tailscaleAutoServe = pkgs.writeShellApplication {
    name = "tailscale-auto-serve";
    runtimeInputs = with pkgs; [
      tailscale
      bpftrace
      iproute2
      gawk
      gnugrep
      coreutils
    ];
    text = builtins.readFile ./tailscale-auto-serve.sh;
  };
in
{
  # see system.nix for context — same ELF/ld-linux issue inside microvms
  programs.nix-ld.enable = true;

  networking.hostName = hostName;
  system.stateVersion = "25.11";
  time.timeZone = "Europe/Warsaw";

  nix.settings.download-buffer-size = 512 * 1024 * 1024; # 512 MiB
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # GC disabled: overlayfs over host's read-only store means GC creates
  # whiteout entries that hide host paths, breaking lookups for libs still in
  # the host store. `gc.automatic = false` disables the timer; min-free/max-free
  # are left unset so nix-daemon doesn't auto-GC during builds when the 4GiB
  # overlay fills up (disk-full surfaces as a build failure instead,
  # recoverable via `microvm clean N`).
  nix.gc.automatic = false;

  environment.variables = {
    EDITOR = "nvim";
  };

  environment.systemPackages = with pkgs; [
    chromium # for playwright claude mcp
    curl
    git
    jq
    lsof
    neovim
    nodejs_22
    ripgrep
  ];

  users.users.szymon = {
    isNormalUser = true;
    group = "users";
    uid = 1000;
    shell = pkgs.bash;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJUJt+pQbfy7QwY8EieP5EmX1suXdt9bDECsokG6x/3L szymon@minix"
    ];
  };
  security.sudo.wheelNeedsPassword = false;

  services.openssh.enable = true;

  systemd.services.setup-user = {
    wantedBy = [ "multi-user.target" ];
    after = [
      "mnt-host.mount"
      "home.mount"
    ];
    requires = [
      "mnt-host.mount"
      "home.mount"
    ];
    conflicts = [ "shutdown.target" ];
    path = [ pkgs.nodejs_22 ];
    script = ''
      /bin/sh /mnt/host/setup.sh
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  services.tailscale.enable = true;

  systemd.services.tailscale-auto-connect = {
    wantedBy = [ "multi-user.target" ];
    after = [
      "tailscaled.service"
      "mnt-host.mount"
    ];
    wants = [ "tailscaled.service" ];
    requires = [ "mnt-host.mount" ];
    conflicts = [ "shutdown.target" ];
    script = ''
      for i in $(seq 1 100); do
        ${pkgs.tailscale}/bin/tailscale status &>/dev/null && break
        sleep 0.1
      done
      AUTH_KEY=$(cat /mnt/host/ts-authkey)
      if [ -n "$AUTH_KEY" ]; then
        ${pkgs.tailscale}/bin/tailscale up \
          --auth-key="$AUTH_KEY" \
          --hostname="${hostName}" \
          --accept-routes
      fi
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  systemd.services.tailscale-auto-serve = {
    description = "Auto-expose user-owned listening ports via tailscale serve";
    wantedBy = [ "multi-user.target" ];
    after = [ "tailscale-auto-connect.service" ];
    requires = [ "tailscale-auto-connect.service" ];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "5s";
      ExecStart = lib.getExe tailscaleAutoServe;
    };
  };

  # warm and renew the tailscale serve TLS cert proactively, tailscaled
  # otherwise provisions it only on the first inbound TLS handshake, so the
  # first hit after boot (or after a cert-issuance outage) fails; the timer
  # also retries a failed provision
  systemd.services.tailscale-cert-ensure = {
    description = "Proactively provision/renew the tailscale serve TLS cert";
    after = [ "tailscale-auto-connect.service" ];
    requires = [ "tailscale-auto-connect.service" ];
    path = [
      pkgs.tailscale
      pkgs.jq
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      name=$(tailscale status --json | jq -r '.Self.DNSName // empty')
      name=''${name%.}

      if [ -z "$name" ]; then
        echo "tailscale not ready" >&2
        exit 1
      fi

      # this is idempotent (real ACME work only when cert is missing or <30d valid)
      tailscale cert --min-validity 720h --cert-file=- --key-file=- "$name" >/dev/null
    '';
  };

  systemd.timers.tailscale-cert-ensure = {
    description = "Periodically ensure the tailscale serve TLS cert is valid";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "90s";
      OnUnitActiveSec = "10min";
    };
  };

  services.resolved.enable = true;
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-e" = {
    matchConfig.Name = "e*";
    addresses = [ { Address = "${ipAddress}/24"; } ];
    routes = [ { Gateway = "10.100.0.254"; } ];
  };
  networking.nameservers = [ "10.100.0.254" ];
  networking.firewall.enable = false;

  programs.git = {
    enable = true;
    config = {
      user = {
        name = "Szymon Kaliski";
        email = "hi@szymonkaliski.com";
      };
      core = {
        quotepath = false;
        pager = "less -x2";
        safecrlf = false;
        autocrlf = false;
        editor = "nvim";
        excludesfile = "/etc/gitignore_global";
      };
      diff.algorithm = "histogram";
      push = {
        default = "current";
        autoSetupRemote = true;
        followTags = true;
      };
      pull.ff = "only";
      rerere.enabled = true;
      init.defaultBranch = "main";
      fetch = {
        prune = true;
        pruneTags = true;
      };
      merge.conflictstyle = "zdiff3";
      status.showUntrackedFiles = "all";
      log.date = "iso";
    };
  };

  environment.etc."gitignore_global".source = "${dotfileDir}/gitignore_global";

  environment.variables.NPM_CONFIG_PREFIX = "/home/szymon/.npm";
  environment.extraInit = ''
    export PATH="/home/szymon/.bin:/home/szymon/.local/bin:/home/szymon/.npm/bin:$PATH"
  '';
  programs.bash.loginShellInit = ''
    cd /workspace 2>/dev/null
  '';

  fileSystems."/home" = {
    device = "/mnt/data/home";
    fsType = "none";
    options = [ "bind" ];
    depends = [ "/mnt/data" ];
  };

  systemd.settings.Manager.DefaultTimeoutStopSec = "5s";

  zramSwap.enable = true;
  zramSwap.memoryPercent = 200;
  zramSwap.algorithm = "zstd";
  programs.direnv = {
    enable = true;
    settings.whitelist.prefix = [ "/workspace" ];
  };

  microvm = {
    hypervisor = "cloud-hypervisor";
    vcpu = 4;
    mem = 4096;
    balloon = true;
    writableStoreOverlay = "/nix/.rw-store";

    volumes = [
      {
        image = "nix-store-overlay.img";
        mountPoint = config.microvm.writableStoreOverlay;
        size = 4096;
      }
    ];

    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
      {
        proto = "virtiofs";
        tag = "host";
        source = "/home/szymon/MicroVMs/host";
        mountPoint = "/mnt/host";
      }
      {
        proto = "virtiofs";
        tag = "data";
        source = "/home/szymon/MicroVMs/${hostName}/data";
        mountPoint = "/mnt/data";
      }
      {
        proto = "virtiofs";
        tag = "workspace";
        source = "/home/szymon/MicroVMs/${hostName}/workspace";
        mountPoint = "/workspace";
      }
    ];

    interfaces = [
      {
        type = "tap";
        id = tapId;
        mac = mac;
      }
    ];
  };
}
