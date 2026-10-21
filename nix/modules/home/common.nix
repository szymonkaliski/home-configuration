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

  # Determinate Nix 3.23 emits activity type 10113 (actStringly) in
  # internal-json logs. nix-output-monitor 2.2.0 fails on unknown activity and
  # result types (maralorn/nix-output-monitor#320, PR #321).
  lastVerifiedBrokenNom = "2.2.0";
  nh = pkgs.nh.override {
    nix-output-monitor =
      lib.warnIf (lib.versionOlder lastVerifiedBrokenNom pkgs.nix-output-monitor.version)
        "nix-output-monitor ${pkgs.nix-output-monitor.version} > ${lastVerifiedBrokenNom}: re-run the drop check in nom-unknown-activity-types.patch, then drop the patch or bump lastVerifiedBrokenNom in modules/home/common.nix"
        (
          pkgs.nix-output-monitor.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ../../pkgs/nom-unknown-activity-types.patch ];
          })
        );
  };
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
    nh
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

    opencode_config = {
      sopsFile = ../../secrets/shared.yaml;
      path = "${config.home.homeDirectory}/.config/opencode/opencode.jsonc";
    };

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
    ".claude/notify-lib.cjs".source = link "${dotfileDir}/agents/notify-lib.cjs";
    ".claude/statusline-command.sh".source = link "${dotfileDir}/claude/statusline-command.sh";
    ".gemini/config/AGENTS.md".source = link "${dotfileDir}/agents/AGENTS.md";
    ".gemini/config/mcp_config.json".source = link "${dotfileDir}/agy/mcp_config.json";
    ".gemini/config/hooks.json".source = link "${dotfileDir}/agy/hooks.json";
    ".gemini/config/notify.js".source = link "${dotfileDir}/agy/notify.js";
    ".gemini/config/notify-lib.cjs".source = link "${dotfileDir}/agents/notify-lib.cjs";
  }
  # skills linked one-by-one so the destination dirs stay real directories;
  # machine-local additions can then sit alongside without living in this repo
  // skillLinks ".claude/skills"
  // skillLinks ".config/opencode/skills"
  // skillLinks ".gemini/config/skills"
  // lib.optionalAttrs pkgs.stdenv.isDarwin {
    # copied into the store, not linked: it must stay readable while ~/Documents is blocked
    ".claude/tcc-heal.js" = {
      source = ../../../dotfiles/claude/tcc-heal.js;
      executable = true;
    };
  };

  xdg.configFile = {
    "nvim".source = link "${dotfileDir}/vim";
    "opencode/opencode.json".source = link "${dotfileDir}/opencode/opencode.json";
    "opencode/cli.json" = {
      source = link "${dotfileDir}/opencode/cli.json";
      force = true;
    };
    "opencode/service.json" = {
      source = link "${dotfileDir}/opencode/service.json";
      force = true;
    };
    "opencode/AGENTS.md".source = link "${dotfileDir}/agents/AGENTS.md";
    "opencode/plugins".source = link "${dotfileDir}/opencode/plugins";
    "opencode/notify-lib.cjs".source = link "${dotfileDir}/agents/notify-lib.cjs";
  };

  # OpenCode writes cli.json via temp-file rename, replacing the symlink with a
  # 0600 regular file; if a newer regular file is left behind, copy it into the
  # repo before removing it so linkGeneration restores the symlink.
  home.activation.syncOpencodeCliConfig =
    lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
      ''
        cliConfig="$HOME/.config/opencode/cli.json"
        repoCliConfig="${dotfileDir}/opencode/cli.json"
        if [[ -f "$cliConfig" && ! -L "$cliConfig" ]]; then
          if [[ "$cliConfig" -nt "$repoCliConfig" ]]; then
            run install -m 644 "$cliConfig" "$repoCliConfig"
          fi
          run rm "$cliConfig"
        fi
      '';
}
