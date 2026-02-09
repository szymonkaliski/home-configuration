{
  hostName,
  ipAddress,
  tapId,
  mac,
  vsockCid,
}:

{
  config,
  lib,
  pkgs,
  ...
}:

{
  networking.hostName = hostName;
  system.stateVersion = "25.11";

  nix.settings.download-buffer-size = 536870912;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  environment.systemPackages = with pkgs; [
    claude-code
    git
    gh
    difftastic
    ripgrep
    curl
    jq
    tmux
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
    script = ''
      mkdir -p /home/szymon
      cp -rT /mnt/host/claude /home/szymon/.claude
      cp /mnt/host/claude.json /home/szymon/.claude.json
      cp -rT /mnt/host/ssh /home/szymon/.ssh
      cp /mnt/host/gitconfig /home/szymon/.gitconfig
      cp /mnt/host/gitignore_global /home/szymon/.gitignore_global
      echo 'cd /workspace 2>/dev/null' > /home/szymon/.bash_profile
      chown -R szymon:users /home/szymon
    '';
    serviceConfig.Type = "oneshot";
  };

  services.tailscale.enable = true;
  systemd.services.tailscale-autoconnect = {
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
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
    serviceConfig.Type = "simple";
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
  networking.nameservers = [
    "1.1.1.2"
    "1.0.0.2"
  ];
  networking.firewall.enable = false;

  fileSystems."/home" = {
    device = "/mnt/data/home";
    options = [ "bind" ];
    depends = [ "/mnt/data" ];
  };

  systemd.settings.Manager.DefaultTimeoutStopSec = "5s";

  zramSwap.enable = true;
  zramSwap.memoryPercent = 200;
  programs.direnv.enable = true;

  microvm = {
    hypervisor = "cloud-hypervisor";
    vcpu = 4;
    mem = 2048;
    vsock.cid = vsockCid;
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
