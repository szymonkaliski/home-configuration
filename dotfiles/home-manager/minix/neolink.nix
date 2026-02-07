{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  gst_all_1,
  openssl,
}:

rustPlatform.buildRustPackage {
  pname = "neolink";
  version = "0-unstable-2025-01-06";

  src = fetchFromGitHub {
    owner = "QuantumEntangledAndy";
    repo = "neolink";
    rev = "6e05e7844b5b50f89787d30bffcbbd3471bfcfde";
    hash = "sha256-/byGj3Gz+dcriPwyAN54Nppl/UQK2WMD8bYh74wy2t8=";
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

  meta = {
    description = "An RTSP bridge to Reolink IP cameras";
    homepage = "https://github.com/QuantumEntangledAndy/neolink";
    license = lib.licenses.agpl3Plus;
    mainProgram = "neolink";
  };
}
