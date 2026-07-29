{
  lib,
  pkgs,
  modulesPath,
  ...
}:
let
  keys = import ../../keys.nix;
in
{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
  ];

  hardware.raspberry-pi.firmware.uboot.enable = true;

  # repopulate the firmware partition on every switch, so u-boot and the GPU
  # blobs track the flake instead of staying frozen at whatever was flashed
  hardware.raspberry-pi.firmware.enable = true;
  fileSystems."/boot/firmware".options = lib.mkForce [ "nofail" ];

  # sd-image.nix sets hardware.enableAllHardware, which drags in ZFS, which we
  # do not use
  boot.supportedFilesystems.zfs = lib.mkForce false;

  # nixos-hardware's rpi-5 profile defaults to the vendor tree at 6.18.34, which
  # nothing built against 26.05, so it would compile a kernel on the Pi; mainline
  # 6.18.40 carries RP1 support and comes prebuilt from the cache
  boot.kernelPackages = pkgs.linuxPackages;

  # create plain .img for flashing
  sdImage.compressImage = false;

  nixpkgs.hostPlatform = "aarch64-linux";

  networking.hostName = "berry";
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.enable = true;

  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig.DHCP = "ipv4";
  };

  systemd.network.wait-online.anyInterface = true;

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
  nix.gc.automatic = true;
  nix.gc.dates = "weekly";
  nix.gc.options = "--delete-older-than 30d";

  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  system.stateVersion = "26.05";
}
