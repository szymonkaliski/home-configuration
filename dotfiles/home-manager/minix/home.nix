{ pkgs, ... }:
let
  neolink = pkgs.callPackage ./neolink.nix { };
in
{
  imports = [ ../common.nix ];

  home.homeDirectory = "/home/szymon";

  home.packages = [
    neolink
    pkgs.lm_sensors
  ];

  services.dropbox.enable = true;
}
