{ buildGoModule, fetchFromGitHub }:
buildGoModule rec {
  pname = "tnotify";
  version = "0.1.6";

  src = fetchFromGitHub {
    owner = "soloterm";
    repo = "tnotify";
    rev = "v${version}";
    hash = "sha256-6KvszN9mmLrReUqheROk1tiX6ou4m3T4HwfxA4kM/i0=";
  };

  vendorHash = "sha256-7K17JaXFsjf163g5PXCb5ng2gYdotnZ2IDKk8KFjNj0=";
  doCheck = false;

  meta.mainProgram = "tnotify";
}
