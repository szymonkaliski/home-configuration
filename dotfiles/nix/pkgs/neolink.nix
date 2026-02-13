{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  gst_all_1,
}:
let
  src = fetchFromGitHub {
    owner = "szymonkaliski";
    repo = "neolink";
    rev = "7fa59e6f059b8023e22fcac093a3375517a1e6aa";
    hash = "sha256-FrhUabhhJwVCwld+YaHWZ6231cDwc1wgoZEAQDj0ciI=";
  };
in
rustPlatform.buildRustPackage {
  pname = "neolink";
  version = "0-unstable-2026-02-10";

  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    openssl
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-rtsp-server
  ];

  NIX_CFLAGS_COMPILE = "-Wno-error=int-conversion";
}
