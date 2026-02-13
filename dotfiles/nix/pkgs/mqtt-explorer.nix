{
  stdenv,
  fetchFromGitHub,
  fetchYarnDeps,
  yarnConfigHook,
  yarn,
  nodejs,
  makeWrapper,
}:
let
  src = fetchFromGitHub {
    owner = "thomasnordquist";
    repo = "MQTT-Explorer";
    rev = "35f31973c456a024a37450f5961e4610dc9a9ce0";
    hash = "sha256-4+uLrejOun1GTjXfxA+3LseaNMzwLorbonevcfkv0gY=";
  };
  rootOfflineCache = fetchYarnDeps {
    yarnLock = "${src}/yarn.lock";
    hash = "sha256-v+urhGIDSUdAphn5xrGqbYztcc6EjGAiwyJPusB8iac=";
  };
  appOfflineCache = fetchYarnDeps {
    yarnLock = "${src}/app/yarn.lock";
    hash = "sha256-ftbYuhYDCdqizT9L5UvDsz+Zblhpti0Us5Y6hQAK+xE=";
  };
in
stdenv.mkDerivation {
  pname = "mqtt-explorer";
  version = "0.4.0-unstable-2025-06-30";
  inherit src;

  nativeBuildInputs = [
    yarnConfigHook
    yarn
    nodejs
    makeWrapper
  ];

  dontYarnInstallDeps = true;

  configurePhase = ''
    runHook preConfigure

    yarnOfflineCache="${rootOfflineCache}" yarnConfigHook

    pushd app
    yarnOfflineCache="${appOfflineCache}" yarnConfigHook
    popd

    substituteInPlace app/webpack.browser.config.mjs \
      --replace-fail "...baseConfig," "...baseConfig, output: { ...baseConfig.output, publicPath: '/mqtt/' },"

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    yarn --offline build:server
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/mqtt-explorer/app
    cp -r dist $out/lib/mqtt-explorer/
    cp -r app/build $out/lib/mqtt-explorer/app/
    cp package.json $out/lib/mqtt-explorer/
    cp -r node_modules $out/lib/mqtt-explorer/

    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/mqtt-explorer \
      --add-flags "$out/lib/mqtt-explorer/dist/src/server.js"

    runHook postInstall
  '';
}
