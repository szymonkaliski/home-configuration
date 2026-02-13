{
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage {
  pname = "lgtv2mqtt2";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "szymonkaliski";
    repo = "lgtv2mqtt2";
    rev = "945e3e8566a35b2ede80bf4e1df2e03fb39e099a";
    hash = "sha256-wuMnlHBTcfqsDfriErRwxIAsF0G+684/vWkGVqBzr6A=";
  };

  npmDepsHash = "sha256-bX0hcMUqPhqR5j6yNFdHom6TkSmMk4QXMdITaum6J+o=";
  dontNpmBuild = true;
}
