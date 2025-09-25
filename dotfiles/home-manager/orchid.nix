{ pkgs, ... }:
{
  home.username = "szymon";
  home.homeDirectory = "/Users/szymon";
  home.stateVersion = "23.11";

  # `ngrok` is not "free"
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  home.packages = [
    pkgs.bat
    pkgs.coreutils
    pkgs.darwin.trash
    pkgs.difftastic
    pkgs.fd
    pkgs.ffmpeg
    pkgs.fzf
    pkgs.gh
    pkgs.git
    pkgs.go
    pkgs.grc
    pkgs.htop
    pkgs.imagemagick # for `explode-video` script
    pkgs.lefthook
    pkgs.mosquitto
    pkgs.neovim
    pkgs.ngrok
    pkgs.nil
    pkgs.nixfmt
    pkgs.nnn
    pkgs.nodejs_22
    pkgs.parallel
    pkgs.ripgrep
    pkgs.rsync
    pkgs.terminal-notifier
    pkgs.tmux
    pkgs.tree
    pkgs.unixtools.watch
    pkgs.vale
    pkgs.watchexec
    pkgs.wget
    pkgs.xmlstarlet # for `add-ocr-to-image` script
  ];

  programs.nix-index-database.comma.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
