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
  net = import ../net.nix;
  keys = import ../../../keys.nix;
in
{
  # see system.nix for context - same ELF/ld-linux issue inside microvms
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
    antigravity-cli
    chromium # for playwright MCP
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
    openssh.authorizedKeys.keys = [ keys.minix ];
  };
  security.sudo.wheelNeedsPassword = false;

  services.openssh.enable = true;
  # the VM regenerates host keys on every boot and rsa-4096 generation takes
  # seconds, delaying sshd; ed25519 is enough for an ephemeral VM
  services.openssh.hostKeys = [
    {
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];

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
      ${pkgs.bash}/bin/bash /mnt/host/setup.sh
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
      AUTH_KEY=$(cat /mnt/host/ts-authkey 2>/dev/null || true)
      if [ -n "$AUTH_KEY" ]; then
        # one transient failure here would leave the VM without tailscale for
        # its lifetime
        for i in $(seq 1 10); do
          ${pkgs.tailscale}/bin/tailscale up \
            --timeout=30s \
            --auth-key="$AUTH_KEY" \
            --hostname="${hostName}" \
            --accept-routes && exit 0
          echo "tailscale up failed, attempt $i" >&2
          sleep 15
        done
        exit 1
      fi
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  services.resolved.enable = true;
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-e" = {
    matchConfig.Name = "e*";
    addresses = [ { Address = "${ipAddress}/${toString net.prefixLength}"; } ];
    routes = [ { Gateway = net.gateway; } ];
  };
  networking.nameservers = [ net.gateway ];
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

  environment.etc."gitignore_global".source = ../../../../dotfiles/gitignore_global;

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
    # vsock.cid stays unset on purpose, accepting the eval warning about
    # systemd-notify: enabling it makes VM stand-up ~5s slower (measured
    # 2026-08: ready in 15-19s without, 20-24s with), and stand-up speed
    # matters more than notify-based readiness

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
