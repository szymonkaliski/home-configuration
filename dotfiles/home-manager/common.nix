{ pkgs, ... }:
{
  home.username = "szymon";
  home.stateVersion = "25.11";

  home.packages = [
    pkgs.difftastic
    pkgs.fd
    pkgs.ffmpeg
    pkgs.fzf
    pkgs.gh
    pkgs.go
    pkgs.grc
    pkgs.htop
    pkgs.lm_sensors
    pkgs.imagemagick
    pkgs.jq
    pkgs.mosquitto
    pkgs.neovim
    pkgs.nil
    pkgs.nixfmt
    pkgs.nnn
    pkgs.nodejs_22
    pkgs.parallel
    pkgs.ripgrep
    pkgs.rsync
    pkgs.tmux
    pkgs.tree
    pkgs.vale
    pkgs.watchexec
    pkgs.wget
    pkgs.xmlstarlet
    pkgs.yt-dlp
  ];

  programs.nix-index-database.comma.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
