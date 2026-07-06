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
    rev = "79a577c73c63228bf4d8477bfbf7f458f1fa7d74";
    hash = "sha256-DYPNH++Ohr0GQQqZNoQm25UoBbkrYdY+d9RhDKRo5Z4=";
  };
in
rustPlatform.buildRustPackage {
  pname = "neolink";
  version = "0-unstable-2026-07-06";

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
