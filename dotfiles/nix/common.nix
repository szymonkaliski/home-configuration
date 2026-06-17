{
  config,
  pkgs,
  repoRoot,
  ...
}:
let
  dotfileDir = "${repoRoot}/dotfiles";
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  home.username = "szymon";
  home.stateVersion = "25.11";

  home.packages = [
    pkgs.age
    pkgs.bat
    pkgs.difftastic
    pkgs.fd
    pkgs.ffmpeg_7
    pkgs.fzf
    pkgs.gh
    pkgs.go
    pkgs.grc
    pkgs.home-manager
    pkgs.htop
    pkgs.imagemagick
    pkgs.jq
    pkgs.live-server
    pkgs.mosquitto
    pkgs.neovim
    pkgs.nil
    pkgs.nixfmt
    pkgs.nnn
    pkgs.nodejs_22
    pkgs.parallel
    pkgs.ripgrep
    pkgs.rsync
    pkgs.sops
    pkgs.timg
    pkgs.tmux
    pkgs.tree
    pkgs.vale
    pkgs.watchexec
    pkgs.wget
    pkgs.xmlstarlet
    (pkgs.yt-dlp.override { javascriptSupport = false; })
  ];

  programs.nix-index-database.comma.enable = true;
  programs.nix-index.enableZshIntegration = false;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # GitHub PAT so fetches use api.github.com (avoids the unauth rate limit +
  # routes around github.com/archive 5xx). Written into the user nix.conf
  # directly rather than via nix.extraOptions so it stays out of home-manager's
  # nix.package/Determinate-Nix machinery. !include tolerates the secret being
  # absent so nix never breaks if sops hasn't populated it yet.
  sops.secrets.nix_access_tokens = {
    sopsFile = ./secrets/shared.yaml;
  };

  xdg.configFile."nix/nix.conf".text = ''
    !include ${config.sops.secrets.nix_access_tokens.path}
  '';

  home.file = {
    ".hushlogin".text = "";
    ".dircolors".source = link "${dotfileDir}/dircolors";
    ".gitconfig".source = link "${dotfileDir}/gitconfig";
    ".gitignore_global".source = link "${dotfileDir}/gitignore_global";
    ".ignore".source = link "${dotfileDir}/ignore";
    ".tmux.conf".source = link "${dotfileDir}/tmux.conf";
    ".vale.ini".source = link "${dotfileDir}/vale.ini";
    ".vim".source = link "${dotfileDir}/vim";
    ".vimrc".source = link "${dotfileDir}/vimrc";
    ".zprofile".source = link "${dotfileDir}/zprofile";
    ".zsh".source = link "${dotfileDir}/zsh";
    ".zshrc".source = link "${dotfileDir}/zshrc";
    ".bin".source = link "${repoRoot}/scripts";
    ".claude/CLAUDE.md".source = link "${dotfileDir}/claude/CLAUDE.md";
    ".claude/settings.json".source = link "${dotfileDir}/claude/settings.json";
    ".claude/pre-read-hook.sh".source = link "${dotfileDir}/claude/pre-read-hook.sh";
    ".claude/notify.js".source = link "${dotfileDir}/claude/notify.js";
    ".claude/statusline-command.sh".source = link "${dotfileDir}/claude/statusline-command.sh";
    ".claude/skills".source = link "${dotfileDir}/claude/skills";
  };

  xdg.configFile = {
    "nvim".source = link "${dotfileDir}/vim";
    "opencode/opencode.json".source = link "${dotfileDir}/opencode/opencode.json";
    "opencode/plugins".source = link "${dotfileDir}/opencode/plugins";
    "opencode/skills".source = link "${dotfileDir}/opencode/skills";
  };
}
