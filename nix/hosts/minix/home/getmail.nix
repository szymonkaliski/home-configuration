{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (import ../lib.nix { inherit pkgs lib; }) waitForInternet mkTimer;

  # 6.19.12 crashes selecting any mailbox whose name needs IMAP quoting, which
  # "[Gmail]/All Mail" does: select_quoted feeds imaplib's _quote output, bytes
  # under python 3.13, to a codec that wants str, and dies with
  #   TypeError: sequence item 0: expected str instance, int found
  # Fixed upstream in v6.20.01 by getmail6/getmail6@809b0f3.
  fixedVersion = "6.20.01";
  getmail6 =
    lib.warnIf (lib.versionAtLeast pkgs.getmail6.version fixedVersion)
      "nixpkgs getmail6 is ${pkgs.getmail6.version} >= ${fixedVersion}: drop the pin in home/getmail.nix"
      (
        pkgs.getmail6.overrideAttrs (_: {
          version = fixedVersion;
          src = pkgs.fetchFromGitHub {
            owner = "getmail6";
            repo = "getmail6";
            tag = "v${fixedVersion}";
            hash = "sha256-U5/vOpVVuPc1ITn0SCr7bnDFUwSBqFr51dUsyiMbORM=";
          };
        })
      );

  maildir = "${config.home.homeDirectory}/Mail/gmail";
  # holds getmailrc plus the oldmail-* state file listing retrieved uids
  getmaildir = "${config.home.homeDirectory}/.config/getmail";
in
{
  # app password generated at https://myaccount.google.com/apppasswords
  sops.secrets.getmail_mail_address = { };
  sops.secrets.getmail_app_password = { };

  home.packages = [ getmail6 ];

  sops.templates."getmailrc" = {
    path = "${getmaildir}/getmailrc";
    content = ''
      [retriever]
      type = SimpleIMAPSSLRetriever
      server = imap.gmail.com
      port = 993
      username = ${config.sops.placeholder.getmail_mail_address}
      password = ${config.sops.placeholder.getmail_app_password}
      mailboxes = ("[Gmail]/All Mail",)

      [destination]
      type = Maildir
      path = ${maildir}/

      [options]
      # consults the oldmail state file, so a run fetches only the messages
      # missing from it
      read_all = false
      delete = false
      # archive the message exactly as gmail served it
      delivered_to = false
      received = false
      # gmail caps imap downloads at 2500 MB/day and suspends the account on
      # overrun, this records progress per message, so the next run picks up
      # where the suspension cut off
      to_oldmail_on_each_mail = true
    '';
  };

  systemd.user.services.getmail = {
    Unit = {
      Description = "Gmail archive fetch";
      After = [
        "network-online.target"
        "sops-nix.service"
      ];
      Wants = [
        "network-online.target"
        "sops-nix.service"
      ];
      OnFailure = [ "notify-failure@%N.service" ];
    };

    Service = {
      Type = "oneshot";
      TimeoutStartSec = "6h";
      ExecStartPre = [
        "${waitForInternet}"
        "${pkgs.coreutils}/bin/mkdir -p ${maildir}/cur ${maildir}/new ${maildir}/tmp"
      ];
      ExecStart = "${getmail6}/bin/getmail --getmaildir ${getmaildir}";
    };
  };

  systemd.user.timers.getmail = mkTimer {
    description = "Gmail archive fetch";
    onCalendar = "*-*-* 03:00:00";
  };
}
