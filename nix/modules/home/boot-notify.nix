{ pkgs, ... }:
let
  inherit (import ./lib.nix { inherit pkgs; }) waitForInternet;

  bootNotify = pkgs.writeShellScript "boot-notify" ''
    booted=$(${pkgs.coreutils}/bin/readlink -f /run/booted-system)
    ver=$(${pkgs.coreutils}/bin/cat /run/booted-system/nixos-version 2>/dev/null || echo "?")
    gen=""
    for l in /nix/var/nix/profiles/system-*-link; do
      if [ "$(${pkgs.coreutils}/bin/readlink -f "$l")" = "$booted" ]; then
        gen=$(${pkgs.coreutils}/bin/basename "$l" | ${pkgs.gnugrep}/bin/grep -oE '[0-9]+')
        break
      fi
    done
    "$HOME/.bin/notify-pushover" "Booted $(${pkgs.coreutils}/bin/uname -n): ''${ver} | kernel $(${pkgs.coreutils}/bin/uname -r) | gen ''${gen:-?} | $(${pkgs.coreutils}/bin/date +%Y-%m-%dT%H:%M)"
  '';
in
{
  # the user manager only runs at boot on hosts with `users.users.<name>.linger`
  systemd.user.services.boot-notify = {
    Unit = {
      Description = "Boot notification";
      # sops-nix: notify-pushover reads ~/.pushoverrc, a sops template that
      # dangles until sops-nix.service has run
      After = [
        "default.target"
        "network-online.target"
        "sops-nix.service"
      ];
      Wants = [
        "network-online.target"
        "sops-nix.service"
      ];
      ConditionPathExists = "!/run/user/%U/boot-notify-done";
    };

    Service = {
      Type = "oneshot";
      TimeoutStartSec = "10min";
      ExecStartPre = "${waitForInternet}";
      ExecStart = "${bootNotify}";
      ExecStartPost = "${pkgs.coreutils}/bin/touch /run/user/%U/boot-notify-done";
      Environment = "PATH=${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.curl}/bin";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
