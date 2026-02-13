{
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage {
  pname = "smartbox2mqtt";
  version = "1.5.0";

  src = fetchFromGitHub {
    owner = "szymonkaliski";
    repo = "smartbox2mqtt";
    rev = "2a16c8281a531c3f49ca20ea77a2cc8cc7a84163";
    hash = "sha256-4uJYxlARLDHooFiHxVYLMghAYa5qSqqddFqgu1xc2Ow=";
  };

  npmDepsHash = "sha256-TJfRdzvA8PybTRx8zUN+IgW819kZrz8ac3/wgJTi5Us=";
  dontNpmBuild = true;
}
