{ pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "minix";
  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "systemd-resolved";
  networking.networkmanager.unmanaged = [ "interface-name:vm-*" ];
  networking.firewall.enable = false;

  # MicroVM bridge network
  systemd.network.enable = true;
  systemd.network.wait-online.enable = false;
  systemd.network.netdevs."20-vm-bridge".netdevConfig = {
    Kind = "bridge";
    Name = "vm-bridge";
  };

  systemd.network.networks."20-vm-bridge" = {
    matchConfig.Name = "vm-bridge";
    addresses = [ { Address = "10.100.0.254/24"; } ];
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
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "server";
  services.resolved.enable = true;
  services.resolved.settings.Resolve.FallbackDNS = [
    "1.1.1.2"
    "1.0.0.2"
  ];

  security.sudo.extraRules = [
    {
      users = [ "szymon" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/systemctl start microvm@*";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl stop microvm@*";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  users.users.szymon = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  nixpkgs.config.allowUnfree = true;

  zramSwap.enable = true;

  nix.settings.download-buffer-size = 536870912;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.gc.automatic = true;
  nix.gc.dates = "weekly";
  nix.gc.options = "--delete-older-than 14d";

  environment.systemPackages = with pkgs; [
    vim
    git
  ];

  services.caddy = {
    enable = true;
    virtualHosts.":80".extraConfig = ''
      handle_path /mqtt/* {
        reverse_proxy localhost:10000
      }
      handle /socket.io/* {
        reverse_proxy localhost:10000
      }
    '';
  };

  system.stateVersion = "25.11";
}
