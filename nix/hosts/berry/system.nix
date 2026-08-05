# kernel, firmware, device trees and bootloader come from nixos-raspberrypi

{
  config,
  pkgs,
  ...
}:
let
  keys = import ../../keys.nix;
in
{
  imports = [ ../../modules/nixos/common.nix ];

  # create plain .img for flashing
  sdImage.compressImage = false;

  # the base profile turns zfs on, which we don't use
  boot.supportedFilesystems.zfs = false;

  # exposes the 40-pin header's SPI0 (GPIO10 MOSI, GPIO11 SCLK, GPIO8 CE0) as
  # /dev/spidev0.{0,1}. without it the rp1 spi@50000 node stays disabled
  hardware.raspberry-pi.config.all.base-dt-params.spi = {
    enable = true;
    value = "on";
  };

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
    extraGroups = [
      "audio"
      "gpio"
      "spi"
      "video"
      "wheel"
    ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      keys.orchid
      keys.minix
    ];
  };

  # logging in with ssh key is the only access, so this is "safe"
  security.sudo.wheelNeedsPassword = false;

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

  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  system.stateVersion = "26.05";
}
