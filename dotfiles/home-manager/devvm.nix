{ pkgs, ... }: {
  home.username = "szymon";
  home.homeDirectory = "/home/szymon";
  home.stateVersion = "23.11";

  home.packages = [
    pkgs.bat
    pkgs.difftastic
    pkgs.fd
    pkgs.fzf
    pkgs.grc
    pkgs.killall
    pkgs.lefthook
    pkgs.lsof
    pkgs.neovim
    pkgs.nil
    pkgs.nixfmt
    pkgs.nnn
    pkgs.nodejs_20
    pkgs.ripgrep
    pkgs.tree
    pkgs.watchexec
  ];

  programs.home-manager.enable = true;

  programs.nix-index-database.comma.enable = true;
}
