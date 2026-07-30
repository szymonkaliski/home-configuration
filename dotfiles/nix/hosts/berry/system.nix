{
  config,
  pkgs,
  ...
}:
let
  keys = import ../../keys.nix;
in
{
  # kernel, firmware, device trees and bootloader all come from
  # nixos-raspberrypi's vendor stack, wired up in flake.nix

  # create plain .img for flashing
  sdImage.compressImage = false;

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

  sops.defaultSopsFile = ../../secrets/shared.yaml;
  sops.age.keyFile = "${config.users.users.szymon.home}/.config/sops/age/keys.txt";
  sops.secrets.tailscale_authkey = { };

  # the key must be reusable, minix consumes it too
  services.tailscale.enable = true;
  services.tailscale.authKeyFile = config.sops.secrets.tailscale_authkey.path;

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
