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
    rev = "321b5ff816b9fbc5aac73e2e007c81d238c01542";
    hash = "sha256-e0VLBQGb/Ka8Pl8wvNVAD99zesqg3BxHlUo4RGPlw1k=";
  };
in
rustPlatform.buildRustPackage {
  pname = "neolink";
  version = "0-unstable-2026-06-24";

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
