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
    rev = "6ec4ebc13108661fdddb1655e0d28dd224e0d932";
    hash = "sha256-/PyKqHYzyloaHFUBWYQaYCdoCO+Jc2C0hHpTBQ2GQ7k=";
  };

  npmDepsHash = "sha256-TJfRdzvA8PybTRx8zUN+IgW819kZrz8ac3/wgJTi5Us=";
  dontNpmBuild = true;
}
