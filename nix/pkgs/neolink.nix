{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  gst_all_1,
}:
let
  # gstbaseparse dereferences frame->buffer after a subclass finishes a
  # zero-size frame; h264parse does that for an alignment=au access unit that
  # ends without a start code, which segfaults neolink. Unfixed upstream as of
  # 1.26.11, and still present on main. The patch header carries the full
  # analysis, the crash signature, and the check for when it can be dropped.
  gst = gst_all_1.overrideScope (
    final: prev: {
      gstreamer = prev.gstreamer.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./gstreamer-baseparse-null-frame-buffer.patch ];
      });
    }
  );

  gstPackages = [
    gst.gstreamer
    gst.gst-plugins-base
    gst.gst-plugins-good
    gst.gst-plugins-bad
    gst.gst-rtsp-server
  ];
in
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

  buildInputs = [ openssl ] ++ gstPackages;

  env.NIX_CFLAGS_COMPILE = "-Wno-error=int-conversion";

  passthru = { inherit gstPackages; };

  meta = {
    description = "MQTT/RTSP bridge for Reolink cameras";
    license = lib.licenses.agpl3Only;
    mainProgram = "neolink";
  };
}
