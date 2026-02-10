{ pkgs, neolink, ... }:
{
  imports = [ ../../common.nix ];

  home.homeDirectory = "/home/szymon";

  home.packages = [
    neolink.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.lm_sensors
  ];

  services.dropbox.enable = true;
}
