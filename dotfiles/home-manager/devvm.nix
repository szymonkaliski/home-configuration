{ config, pkgs, ... }: {
  home.username = "szymon";
  home.homeDirectory = "/home/szymon";
  home.stateVersion = "23.11";

  home.packages = [
    pkgs.bat
    pkgs.difftastic
    pkgs.fd
    pkgs.fzf
    pkgs.killall
    pkgs.lefthook
    pkgs.nnn
    pkgs.ripgrep
    pkgs.tree
    pkgs.watchexec
  ];

  programs.home-manager.enable = true;

  programs.nix-index-database.comma.enable = true;
}
