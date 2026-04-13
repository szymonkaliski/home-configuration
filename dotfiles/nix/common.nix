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
    ".gemini/GEMINI.md".source = link "${dotfileDir}/gemini/GEMINI.md";
    ".gemini/settings.json".source = link "${dotfileDir}/gemini/settings.json";
    ".gemini/skills".source = link "${dotfileDir}/gemini/skills";
  };

  xdg.configFile = {
    "nvim".source = link "${dotfileDir}/vim";
    "timav-nodejs/config.json".source = link "${dotfileDir}/timav/config.json";
  };

  sops.secrets.timav_google_client_id = {
    sopsFile = ./secrets/shared.yaml;
  };
  sops.secrets.timav_google_client_secret = {
    sopsFile = ./secrets/shared.yaml;
  };
  sops.secrets.timav_google_project_id = {
    sopsFile = ./secrets/shared.yaml;
  };

  sops.templates."timav-credentials.json" = {
    path = "${config.home.homeDirectory}/.config/timav-nodejs/credentials.json";
    content = builtins.toJSON {
      installed = {
        client_id = config.sops.placeholder.timav_google_client_id;
        project_id = config.sops.placeholder.timav_google_project_id;
        auth_uri = "https://accounts.google.com/o/oauth2/auth";
        token_uri = "https://oauth2.googleapis.com/token";
        auth_provider_x509_cert_url = "https://www.googleapis.com/oauth2/v1/certs";
        client_secret = config.sops.placeholder.timav_google_client_secret;
        redirect_uris = [
          "urn:ietf:wg:oauth:2.0:oob"
          "http://localhost"
        ];
      };
    };
  };
}
