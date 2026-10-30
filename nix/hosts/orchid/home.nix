{
  config,
  lib,
  pkgs,
  repoRoot,
  ...
}:
let
  dotfileDir = "${repoRoot}/dotfiles";
  link = config.lib.file.mkOutOfStoreSymlink;

  keys = import ../../keys.nix;
in
{
  imports = [
    ../../modules/home/common.nix
    ../../modules/home/rmapi.nix
    ../../modules/home/timav.nix
    ./apps
  ];

  home.homeDirectory = "/Users/szymon";

  # minix reaches orchid over ssh, and macOS sshd reads ~/.ssh/authorized_keys.
  # It must be a real 0600 file: a home.file symlink into /nix/store fails
  # sshd's StrictModes check on the group-writable store directory
  home.activation.authorizedKeys = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    f="$HOME/.ssh/authorized_keys"
    run mkdir -p "$HOME/.ssh"
    run chmod 700 "$HOME/.ssh"
    run touch "$f"
    run chmod 600 "$f"
    if ! grep -qxF "${keys.minix}" "$f"; then
      [ -s "$f" ] && [ -n "$(tail -c1 "$f")" ] && run sh -c "echo >> $f"
      run sh -c "echo ${keys.minix} >> $f"
    fi
  '';

  targets.darwin.copyApps.enable = false;
  targets.darwin.linkApps.enable = true;

  home.packages = [
    pkgs.coreutils
    pkgs.darwin.trash
    pkgs.git
    pkgs.mosh
    pkgs.ollama
    pkgs.socat
    pkgs.unixtools.watch
  ];

  # direct symlink so Hammerspoon has config at login before /nix is mounted
  home.activation.linkHammerspoon = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ln -sfn "${dotfileDir}/hammerspoon" "$HOME/.hammerspoon"
  '';

  # payload scripts stay live-editable in nix/hosts/orchid/launchd
  launchd.agents =
    let
      scriptsDir = "${repoRoot}/nix/hosts/orchid/launchd";
      logsDir = "${config.home.homeDirectory}/Library/Logs";
      launcher = "${config.home.homeDirectory}/Applications/Launcher.app/Contents/MacOS/launcher";

      mkAgent = name: extra: {
        enable = true;
        config = {
          Label = "com.szymonkaliski.${name}";
          ProgramArguments = [
            "/bin/bash"
            "${scriptsDir}/${name}.sh"
          ];
          StandardOutPath = "${logsDir}/com.szymonkaliski.${name}.log";
          StandardErrorPath = "${logsDir}/com.szymonkaliski.${name}.log";
        }
        // extra;
      };
    in
    {
      "com.szymonkaliski.alfred-infinite-clipboard-backup" = mkAgent "alfred-infinite-clipboard-backup" {
        RunAtLoad = true;
        StartCalendarInterval = {
          Hour = 3;
          Minute = 0;
        };
      };

      "com.szymonkaliski.dropbox-watchdog" = mkAgent "dropbox-watchdog" {
        RunAtLoad = true;
        StartInterval = 300;
      };

      # truncates the other agents' logs, deliberately logless itself
      "com.szymonkaliski.log-truncate" = {
        enable = true;
        config = {
          Label = "com.szymonkaliski.log-truncate";
          ProgramArguments = [
            "/bin/bash"
            "${scriptsDir}/log-truncate.sh"
          ];
          StartCalendarInterval = {
            Hour = 4;
            Minute = 0;
          };
        };
      };

      "com.szymonkaliski.muninn-autocommit" = mkAgent "muninn-autocommit" {
        WatchPaths = [ "${config.home.homeDirectory}/Library/CloudStorage/Dropbox/Wiki" ];
        OnDemand = true;
        RunAtLoad = true;
        ThrottleInterval = 3600;
      };

      "com.szymonkaliski.ollama-autostart" = mkAgent "ollama-autostart" {
        RunAtLoad = true;
        KeepAlive = true;
      };

      "com.szymonkaliski.orchestrator-server" = mkAgent "orchestrator-server" {
        KeepAlive = true;
        ProgramArguments = [
          launcher
          "/bin/bash"
          "${scriptsDir}/orchestrator-server.sh"
        ];
        RunAtLoad = true;
      };

      "com.szymonkaliski.tcc-heal" = mkAgent "tcc-heal" {
        RunAtLoad = true;
        KeepAlive = true;
      };

      "com.szymonkaliski.timav-cache" = mkAgent "timav-cache" {
        RunAtLoad = true;
        StartCalendarInterval = {
          Minute = 0;
        };
      };

      # keeps the default "home" tmux session alive inside Aqua (gui/501) so
      # login.keychain-db is unlocked and Launcher.app owns TCC attribution
      "com.szymonkaliski.tmux" = mkAgent "tmux" {
        AbandonProcessGroup = true;
        KeepAlive = true;
        ProgramArguments = [
          launcher
          "/bin/bash"
          "${scriptsDir}/tmux.sh"
        ];
        RunAtLoad = true;
      };
    };

  targets.darwin.defaults = {
    NSGlobalDomain = {
      # disable the "accents" menu on keyboard key held
      ApplePressAndHoldEnabled = false;
      # disable focus ring animation
      NSUseAnimatedFocusRing = false;
      # increase window resize speed
      NSWindowResizeTime = 0.001;
      # save to disk (not to iCloud) by default
      NSDocumentSaveNewDocumentsToCloud = false;
    };

    # disable Finder animations
    "com.apple.finder".DisableAllAnimations = true;

    "com.apple.dock" = {
      # set the icon size of Dock items
      tilesize = 48;
      # lock Dock size
      size-immutable = true;
      # remove the delay before the Dock auto-show/hide animation starts
      # (animation duration itself is unchanged)
      autohide-delay = 0.0;
    };

    "com.apple.screencapture" = {
      # save screenshots to Dropbox
      location = "${config.home.homeDirectory}/Library/CloudStorage/Dropbox/Screenshots";
      # name screenshots as Screenshot...
      name = "Screenshot";
    };
  };

  xdg.configFile."ghostty".source = link "${dotfileDir}/ghostty";

  sops.defaultSopsFile = ../../secrets/shared.yaml;
  sops.age.keyFile = "${config.home.homeDirectory}/Library/Application Support/sops/age/keys.txt";
}
