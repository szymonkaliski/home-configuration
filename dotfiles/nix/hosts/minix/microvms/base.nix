{
  hostName,
  ipAddress,
  tapId,
  mac,
  mem,
}:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  dotfileDir = ../../../../.;
in
{
  networking.hostName = hostName;
  system.stateVersion = "25.11";
  time.timeZone = "Europe/Warsaw";

  nix.settings.download-buffer-size = 536870912;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.gc.automatic = true;
  nix.gc.dates = "daily";
  nix.gc.options = "--delete-older-than 7d";

  environment.variables.EDITOR = "nvim";

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
  systemd.services.tailscale-autoconnect = {
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
  environment.shellAliases.claude = "claude --dangerously-skip-permissions";
  environment.extraInit = ''
    export PATH="/home/szymon/.npm/bin:$PATH"
  '';
  programs.bash.loginShellInit = ''
    cd /workspace 2>/dev/null
  '';

  fileSystems."/home" = {
    device = "/mnt/data/home";
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
    inherit mem;
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
