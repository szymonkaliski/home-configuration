{ config, ... }:
{
  imports = [ ../../common.nix ];

  home.homeDirectory = "/home/szymon";

  sops.defaultSopsFile = ../../secrets/shared.yaml;
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

  services.ollama.enable = true;
}
