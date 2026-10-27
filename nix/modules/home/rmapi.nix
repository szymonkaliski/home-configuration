{
  config,
  pkgs,
  ...
}:
let
  # rmapi reads XDG config on linux and Library/Application Support on macOS
  confDir = if pkgs.stdenv.isDarwin then "Library/Application Support/rmapi" else ".config/rmapi";
in
{
  home.packages = [ pkgs.rmapi ];

  sops.secrets.rmapi_device_token.sopsFile = ../../secrets/shared.yaml;

  # 0600 so rmapi can write the short-lived usertoken back through the symlink
  sops.templates."rmapi.conf" = {
    path = "${config.home.homeDirectory}/${confDir}/rmapi.conf";
    mode = "0600";
    content = ''
      devicetoken: ${config.sops.placeholder.rmapi_device_token}
    '';
  };
}
