{
  config,
  pkgs,
  ...
}:
let
  # timav reads XDG config on linux and Library/Preferences on macOS
  confDir =
    if pkgs.stdenv.isDarwin then "Library/Preferences/timav-nodejs" else ".config/timav-nodejs";
in
{
  sops.secrets = {
    timav_google_client_id.sopsFile = ../../secrets/shared.yaml;
    timav_google_client_secret.sopsFile = ../../secrets/shared.yaml;
    timav_google_project_id.sopsFile = ../../secrets/shared.yaml;
  };

  home.file."${confDir}/config.json".text = builtins.toJSON {
    calendar = "Tracking";
  };

  sops.templates."timav-credentials.json" = {
    path = "${config.home.homeDirectory}/${confDir}/credentials.json";
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
