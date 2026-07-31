{
  config,
  pkgs,
  ...
}:
let
  keys = import ../../keys.nix;
in
{
  # kernel, firmware, device trees and bootloader come from nixos-raspberrypi

  # create plain .img for flashing
  sdImage.compressImage = false;

  # the base profile turns zfs on, which we don't use
  boot.supportedFilesystems.zfs = false;

  networking.hostName = "berry";
  networking.useDHCP = false;
  networking.useNetworkd = true;
  networking.firewall.enable = false;
  systemd.network.enable = true;

  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
      LinkLocalAddressing = "no";
    };
  };

  systemd.network.networks."10-wlan" = {
    matchConfig.Type = "wlan";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
      LinkLocalAddressing = "no";
    };
    # end0's DHCP routes carry the default metric of 1024
    dhcpV4Config.RouteMetric = 2048;
  };

  systemd.network.wait-online.anyInterface = true;

  # avahi already provides mDNS; disable resolved's so they don't both respond
  services.resolved.settings.Resolve.MulticastDNS = "no";

  # llmnr answers single-label names with link-local addresses, racing magicdns
  services.resolved.settings.Resolve.LLMNR = "no";

  sops.defaultSopsFile = ../../secrets/shared.yaml;
  sops.age.keyFile = "${config.users.users.szymon.home}/.config/sops/age/keys.txt";

  # binary format means `sops secrets/wireless-conf` edits it as a plain
  # wpa_supplicant network block; wpa_supplicant.service runs as this user.
  # the unit bind-mounts the file, so it only picks up edits on restart
  sops.secrets.wireless_conf = {
    format = "binary";
    sopsFile = ../../secrets/wireless-conf;
    owner = "wpa_supplicant";
    restartUnits = [ "wpa_supplicant.service" ];
  };

  sops.secrets.nix_builder_key = {
    format = "binary";
    sopsFile = ../../secrets/nix-builder-key;
  };

  networking.wireless = {
    enable = true;
    extraConfig = "country=PL";
    extraConfigFiles = [ config.sops.secrets.wireless_conf.path ];
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish.enable = true;
    publish.addresses = true;
  };

  services.tailscale.enable = true;

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  programs.mosh.enable = true;

  users.users.szymon = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      keys.orchid
      keys.minix
    ];
  };

  # logging in with ssh key is the only access, so this is "safe"
  security.sudo.wheelNeedsPassword = false;

  programs.zsh.enable = true;

  # /etc/zshrc otherwise runs a full `compinit` (~40-50ms security audit)
  # before our own; dotfiles/zsh/completion.zsh extends fpath and runs compinit
  # itself, so skip the redundant global one
  programs.zsh.enableGlobalCompInit = false;

  # we set our own PROMPT (dotfiles/zsh/prompt.zsh) and load our own dircolors
  # (deferred, dotfiles/zsh/colors.zsh), so skip /etc/zshrc's `prompt suse`
  # line and its dircolors fork
  programs.zsh.promptInit = "";
  programs.zsh.enableLsColors = false;

  # claude-code ships native binaries, they hardcode the glibc loader path
  programs.nix-ld.enable = true;

  time.timeZone = "Europe/Warsaw";

  nixpkgs.config.allowUnfree = true;

  zramSwap.enable = true;
  zramSwap.algorithm = "zstd";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.distributedBuilds = true;

  # nix offers every derivation to minix first and only builds here when it is
  # unreachable, so keep the pi's own parallelism low
  nix.settings.max-jobs = 1;

  # minix pulls dependencies from the caches itself instead of berry uploading
  nix.settings.builders-use-substitutes = true;

  nix.buildMachines = [
    {
      hostName = "minix";
      protocol = "ssh-ng";
      sshUser = "nix-ssh";
      sshKey = config.sops.secrets.nix_builder_key.path;
      systems = [ "aarch64-linux" ];
      maxJobs = 8;
      supportedFeatures = [
        "big-parallel"
        "kvm"
      ];
    }
  ];

  programs.ssh.knownHosts.minix.publicKey = keys.minixHost;

  nix.gc.automatic = true;
  nix.gc.dates = "weekly";
  nix.gc.options = "--delete-older-than 30d";

  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  system.stateVersion = "26.05";
}
