{ config, pkgs, ... }:
{
  sops.secrets.restic_password.owner = "szymon";
  sops.secrets.rclone_nas_config.owner = "szymon";

  services.restic.backups.nas = {
    initialize = true;
    repository = "rclone:nas:/NAS/Backup/Minix";
    rcloneConfigFile = config.sops.secrets.rclone_nas_config.path;
    passwordFile = config.sops.secrets.restic_password.path;

    paths = [
      "${config.users.users.szymon.home}"
      "/var/lib/zigbee2mqtt"
    ];

    exclude = [
      "**/.direnv"
      "**/node_modules"
      "**/result"
      "${config.users.users.szymon.home}/.cache"
      "${config.users.users.szymon.home}/.cargo"
      "${config.users.users.szymon.home}/.config/sops/age"
      "${config.users.users.szymon.home}/.dropbox"
      "${config.users.users.szymon.home}/.dropbox-dist"
      "${config.users.users.szymon.home}/.nix-defexpr"
      "${config.users.users.szymon.home}/.nix-profile"
      "${config.users.users.szymon.home}/.npm"
      "${config.users.users.szymon.home}/Dropbox"
      "${config.users.users.szymon.home}/MicroVMs/*/data/home/*/.cache"
      "${config.users.users.szymon.home}/MicroVMs/*/data/home/*/.npm"
    ];

    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };

    extraBackupArgs = [ "--verbose" ];

    checkOpts = [ "--read-data-subset=5%" ];

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
      "--keep-yearly 2"
    ];
  };

  systemd.services."notify-failure@" = {
    description = "Failure notification for %i";
    path = [
      pkgs.bash
      pkgs.coreutils
      pkgs.curl
    ];
    serviceConfig = {
      Type = "oneshot";
      Environment = "PUSHOVERRC=${config.sops.templates."pushoverrc".path}";
      ExecStart = ''${config.users.users.szymon.home}/.bin/notify-pushover "Failed: %i"'';
    };
  };

  systemd.services.restic-backups-nas.unitConfig.OnFailure = [ "notify-failure@%N.service" ];
}
