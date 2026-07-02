{ pkgs, lib }:
let
  mqtt = import ../../mqtt.nix;

  waitForMosquitto = pkgs.writeShellScript "wait-for-mosquitto" ''
    for i in {1..30}; do
      ${pkgs.mosquitto}/bin/mosquitto_pub \
        -h ${mqtt.host} -p ${toString mqtt.port} \
        -u ${mqtt.username} -P ${mqtt.password} \
        -t healthcheck/wait -m ping -q 0 \
        2>/dev/null && exit 0
      sleep 1
    done
    echo "mosquitto not ready"
    exit 1
  '';

  # network-online.target is inert for user services, so poll tailscale for
  # real internet (it comes up last, so online implies dns/upstream are up)
  waitForInternet = pkgs.writeShellScript "wait-for-internet" ''
    for i in {1..150}; do
      online=$(${pkgs.tailscale}/bin/tailscale status --self --json 2>/dev/null | ${pkgs.jq}/bin/jq -r '.Self.Online // empty')
      [ "$online" = "true" ] && exit 0
      sleep 2
    done
    echo "internet not ready after 300s, proceeding anyway"
    exit 0
  '';
in
{
  inherit waitForMosquitto waitForInternet;

  # systemd user service that runs a project via `nix develop`. captures the
  # shared boilerplate (network-online + notify-failure + ConditionPathIsDirectory
  # + the nix develop ExecStart); the flags toggle the per-service bits.
  mkProjectService =
    {
      dir,
      description,
      command,
      build ? null,
      needsMqtt ? false,
      needsInternet ? false,
      extraUnits ? [ ], # extra After/Wants beyond network-online.target
      oneshot ? false,
      timeoutStart ? null,
      timeoutStop ? null,
      successExitStatus ? null,
      environment ? null,
      extraService ? { },
    }:
    let
      projectDir = "%h/Projects/${dir}";
      pre =
        lib.optional needsInternet waitForInternet
        ++ lib.optional needsMqtt waitForMosquitto
        ++ lib.optional (build != null) "${pkgs.nix}/bin/nix develop ${projectDir} --command ${build}";
      preAttr =
        if pre == [ ] then
          { }
        else if builtins.length pre == 1 then
          { ExecStartPre = builtins.head pre; }
        else
          { ExecStartPre = pre; };
    in
    {
      Unit = {
        Description = description;
        After = [ "network-online.target" ] ++ extraUnits;
        Wants = [ "network-online.target" ] ++ extraUnits;
        OnFailure = [ "notify-failure@%N.service" ];
        ConditionPathIsDirectory = projectDir;
      };

      Service = {
        ExecStart = "${pkgs.nix}/bin/nix develop ${projectDir} --command ${command}";
        WorkingDirectory = projectDir;
      }
      // preAttr
      // lib.optionalAttrs oneshot { Type = "oneshot"; }
      // lib.optionalAttrs (!oneshot) {
        Restart = "on-failure";
        RestartSec = 30;
      }
      // lib.optionalAttrs (timeoutStart != null) { TimeoutStartSec = timeoutStart; }
      // lib.optionalAttrs (timeoutStop != null) { TimeoutStopSec = timeoutStop; }
      // lib.optionalAttrs (successExitStatus != null) { SuccessExitStatus = successExitStatus; }
      // lib.optionalAttrs (environment != null) { Environment = environment; }
      // extraService;
    }
    // lib.optionalAttrs (!oneshot) { Install.WantedBy = [ "default.target" ]; };

  mkTimer =
    {
      description,
      onCalendar,
      persistent ? true,
    }:
    {
      Unit.Description = description;
      Timer = {
        OnCalendar = onCalendar;
        Persistent = persistent;
      };
      Install.WantedBy = [ "timers.target" ];
    };
}
