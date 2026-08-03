{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  gst_all_1,
}:
rustPlatform.buildRustPackage {
  pname = "neolink";
  version = "0-unstable-2026-07-06";

  src = fetchFromGitHub {
    owner = "szymonkaliski";
    repo = "neolink";
    rev = "79a577c73c63228bf4d8477bfbf7f458f1fa7d74";
    hash = "sha256-DYPNH++Ohr0GQQqZNoQm25UoBbkrYdY+d9RhDKRo5Z4=";
  };

  cargoHash = "sha256-BMEBDX5oE3nxFDauXwT65VN3RkMmIXltU+duBi+BXsA=";

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

  env.NIX_CFLAGS_COMPILE = "-Wno-error=int-conversion";

  meta = {
    description = "MQTT/RTSP bridge for Reolink cameras";
    license = lib.licenses.agpl3Only;
    mainProgram = "neolink";
  };
}
