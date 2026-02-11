{ pkgs, neolink, ... }:
{
  imports = [ ../../common.nix ];

  home.homeDirectory = "/home/szymon";

  home.packages = [
    neolink.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.lm_sensors
    pkgs.trash-cli
  ];

  services.dropbox.enable = true;
}
