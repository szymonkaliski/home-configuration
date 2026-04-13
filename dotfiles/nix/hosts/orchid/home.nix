{
  config,
  pkgs,
  repoRoot,
  ...
}:
let
  dotfileDir = "${repoRoot}/dotfiles";
  link = config.lib.file.mkOutOfStoreSymlink;

  tnotify = pkgs.buildGoModule rec {
    pname = "tnotify";
    version = "0.1.6";
    src = pkgs.fetchFromGitHub {
      owner = "soloterm";
      repo = "tnotify";
      rev = "v${version}";
      hash = "sha256-6KvszN9mmLrReUqheROk1tiX6ou4m3T4HwfxA4kM/i0=";
    };
    vendorHash = "sha256-7K17JaXFsjf163g5PXCb5ng2gYdotnZ2IDKk8KFjNj0=";
    doCheck = false;
  };
in
{
  imports = [ ../../common.nix ];

  home.homeDirectory = "/Users/szymon";

  targets.darwin.copyApps.enable = false;
  targets.darwin.linkApps.enable = true;

  home.packages = [
    tnotify
    pkgs.coreutils
    pkgs.darwin.trash
    pkgs.git
    pkgs.unixtools.watch
  ];

  home.file.".hammerspoon".source = link "${dotfileDir}/hammerspoon";

  xdg.configFile."ghostty".source = link "${dotfileDir}/ghostty";

  sops.defaultSopsFile = ../../secrets/shared.yaml;
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

  home.file."Library/Preferences/timav-nodejs/config.json".source =
    link "${dotfileDir}/timav/config.json";

  sops.secrets.timav_google_client_id = {
    sopsFile = ../../secrets/shared.yaml;
  };
  sops.secrets.timav_google_client_secret = {
    sopsFile = ../../secrets/shared.yaml;
  };
  sops.secrets.timav_google_project_id = {
    sopsFile = ../../secrets/shared.yaml;
  };

  sops.templates."timav-credentials.json" = {
    path = "${config.home.homeDirectory}/Library/Preferences/timav-nodejs/credentials.json";
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
