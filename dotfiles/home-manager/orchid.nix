{ config, pkgs, ... }: {
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
    pkgs.lefthook
    pkgs.llm
    pkgs.mosquitto
    pkgs.neovim
    pkgs.ngrok
    pkgs.nnn
    pkgs.nodejs_20
    pkgs.parallel
    pkgs.python312Packages.pynvim # dependency for `vim-ai`
    pkgs.ripgrep
    pkgs.rsync
    pkgs.tmux
    pkgs.tree
    pkgs.vale
    pkgs.watchexec
    pkgs.wget
    pkgs.xmlstarlet
  ];

  programs.home-manager.enable = true;

  programs.nix-index-database.comma.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
