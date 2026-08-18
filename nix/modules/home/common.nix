{
  config,
  options,
  lib,
  pkgs,
  repoRoot,
  ...
}:
let
  dotfileDir = "${repoRoot}/dotfiles";
  link = config.lib.file.mkOutOfStoreSymlink;

  # flake eval only sees git-tracked files - `git add` newly created skills
  skillNames = builtins.attrNames (builtins.readDir ../../../dotfiles/agents/skills);
  skillLinks =
    dest:
    builtins.listToAttrs (
      map (name: {
        name = "${dest}/${name}";
        value.source = link "${dotfileDir}/agents/skills/${name}";
      }) skillNames
    );
in
{
  home.username = "szymon";
  home.stateVersion = "25.11";

  home.packages = [
    pkgs.age
    pkgs.antigravity-cli
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

  # the system-level gc runs as root and only expires root's profiles;
  # home-manager generations live in ~/.local/state/nix/profiles
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # home-manager's darwin agent passes `nix.gc.options` as one argv element,
  # which nix-collect-garbage rejects as an unrecognised flag
  launchd.agents.nix-gc.config.ProgramArguments =
    let
      upstreamArgs = lib.concatLists (
        lib.filter lib.isList (
          map (def: (def.nix-gc or { }).config.ProgramArguments or [ ]) options.launchd.agents.definitions
        )
      );
      upstreamSplitsOptions = !(lib.any (lib.hasInfix " ") upstreamArgs);
    in
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
      lib.warnIf upstreamSplitsOptions
        "home-manager's nix-gc launchd agent splits nix.gc.options now; drop the ProgramArguments override in modules/home/common.nix"
        (lib.mkForce (lib.concatMap (lib.splitString " ") upstreamArgs))
    );

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  xdg.configFile."nix/nix.conf".text = ''
    !include ${config.sops.secrets.nix_access_tokens.path}
  '';

  sops.secrets = {
    # GitHub PAT so fetches use api.github.com
    nix_access_tokens.sopsFile = ../../secrets/shared.yaml;

    # binary format means `sops secrets/ssh-config` edits it as ordinary ssh
    # config instead of YAML
    ssh_config = {
      format = "binary";
      sopsFile = ../../secrets/ssh-config;
      path = "${config.home.homeDirectory}/.ssh/config";
      mode = "0600";
    };

    gemini_api_key_opencode.sopsFile = ../../secrets/shared.yaml;
    pushover_user.sopsFile = ../../secrets/shared.yaml;
  }
  // (
    # orchid has its own pushover app token
    if pkgs.stdenv.isDarwin then
      { pushover_token_orchid.sopsFile = ../../secrets/orchid.yaml; }
    else
      { pushover_token_user.sopsFile = ../../secrets/shared.yaml; }
  );

  sops.templates."pushoverrc" = {
    path = "${config.home.homeDirectory}/.pushoverrc";
    content = ''
      PUSHOVER_TOKEN=${
        config.sops.placeholder.${
          if pkgs.stdenv.isDarwin then "pushover_token_orchid" else "pushover_token_user"
        }
      }
      PUSHOVER_USER=${config.sops.placeholder.pushover_user}
    '';
  };

  sops.templates."gemini-api-key" = {
    path = "${config.home.homeDirectory}/.config/opencode/gemini_api_key";
    content = config.sops.placeholder.gemini_api_key_opencode;
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
    ".bin".source = link "${repoRoot}/bin";
    ".claude/CLAUDE.md".source = link "${dotfileDir}/agents/AGENTS.md";
    ".claude/settings.json".source = link "${dotfileDir}/claude/settings.json";
    ".claude/notify.js".source = link "${dotfileDir}/claude/notify.js";
    ".claude/statusline-command.sh".source = link "${dotfileDir}/claude/statusline-command.sh";
    ".gemini/config/AGENTS.md".source = link "${dotfileDir}/agents/AGENTS.md";
  }
  # skills linked one-by-one so the destination dirs stay real directories;
  # machine-local additions can then sit alongside without living in this repo
  // skillLinks ".claude/skills"
  // skillLinks ".config/opencode/skills"
  // skillLinks ".gemini/config/skills";

  xdg.configFile = {
    "nvim".source = link "${dotfileDir}/vim";
    "opencode/opencode.json".source = link "${dotfileDir}/opencode/opencode.json";
    "opencode/tui.json".source = link "${dotfileDir}/opencode/tui.json";
    "opencode/AGENTS.md".source = link "${dotfileDir}/agents/AGENTS.md";
    "opencode/plugins".source = link "${dotfileDir}/opencode/plugins";
  };
}
