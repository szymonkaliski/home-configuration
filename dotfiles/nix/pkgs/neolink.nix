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
    rev = "7a2380b98ce2ae8655b73d5368bb18d9fc5cb20c";
    hash = "sha256-Zzf6jnxtbpEjGRqeVvkgHrvh3qBS2qHm0eTnvcv+KYU=";
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
