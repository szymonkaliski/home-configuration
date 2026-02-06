{ ... }:
{
  imports = [ ../common.nix ];

  home.homeDirectory = "/home/szymon";

  nixpkgs.config.allowUnfree = true;

  services.dropbox.enable = true;
}
