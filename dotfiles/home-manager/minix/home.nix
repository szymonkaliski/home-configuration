{ pkgs, ... }:
let
  neolink = pkgs.callPackage ./neolink.nix { };
in
{
  imports = [ ../common.nix ];

  home.homeDirectory = "/home/szymon";

  nixpkgs.config.allowUnfree = true;

  home.packages = [ neolink ];

  services.dropbox.enable = true;
}
