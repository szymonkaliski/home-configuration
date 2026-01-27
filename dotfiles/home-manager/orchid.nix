{ pkgs, ... }:
let
  tnotify = pkgs.buildGoModule rec {
    pname = "tnotify";
    version = "0.1.6";
    src = pkgs.fetchFromGitHub {
      owner = "soloterm";
      repo = "tnotify";
      rev = "v${version}";
      hash = "sha256-6KvszN9mmLrReUqheROk1tiX6ou4m3T4HwfxA4kM/i0=";
    };
    vendorHash = "sha256-7K17JaXFsjf163g5PXCb5ng2gYdotnZ2IDKk8KFjNj0=";
    doCheck = false;
  };
in
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
    tnotify

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
    pkgs.tmux
    pkgs.tree
    pkgs.unixtools.watch
    pkgs.vale
    pkgs.watchexec
    pkgs.wget
    pkgs.xmlstarlet # for `add-ocr-to-image` script
    pkgs.yt-dlp
  ];

  programs.nix-index-database.comma.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
