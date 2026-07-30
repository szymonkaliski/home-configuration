{
  config,
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

  # rp1_pci needs mainline's dtb, not the firmware's vendor one, or it probes
  # -EINVAL and there is no ethernet, USB or GPIO
  # config.txt dtoverlay/dtparam lines stop applying
  boot.loader.generic-extlinux-compatible.useGenerationDeviceTree = true;

  # mainline's dtb has no thermal sensor, and GET_THROTTLED fails on a Pi 5 so
  # raspberrypi-hwmon never registers; describing the AVS block is enough
  # no trip points: calibration is unverified and a critical one would power the
  # board off on a bogus reading
  hardware.deviceTree.overlays = [
    {
      name = "bcm2712-avs-thermal";
      dtsText = ''
        /dts-v1/;
        /plugin/;

        / {
          compatible = "raspberrypi,5-model-b", "brcm,bcm2712";

          fragment@0 {
            target-path = "/soc@107c000000";
            __overlay__ {
              avs-monitor@7d542000 {
                compatible = "brcm,bcm2711-avs-monitor", "syscon", "simple-mfd";
                reg = <0x7d542000 0xf00>;
                status = "okay";

                avs_thermal: thermal {
                  compatible = "brcm,bcm2711-thermal";
                  #thermal-sensor-cells = <0>;
                };
              };
            };
          };

          fragment@1 {
            target-path = "/";
            __overlay__ {
              thermal-zones {
                cpu-thermal {
                  polling-delay-passive = <1000>;
                  polling-delay = <1000>;
                  coefficients = <(-550) 450000>;
                  thermal-sensors = <&avs_thermal>;
                };
              };
            };
          };
        };
      '';
    }
  ];

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
