{ pkgs }:
{
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
}
