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
    rev = "a588238ec6076a98d31375269419670939c37daa";
    hash = "sha256-l1vtqLi4OF7WFG5SSm0VkOCipJf8dJrGrCiVmF+FViA=";
  };
in
rustPlatform.buildRustPackage {
  pname = "neolink";
  version = "0-unstable-2026-06-29";

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
