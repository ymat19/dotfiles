{ lib, stdenv, fetchzip, nodejs_22, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "9router";
  version = "0.4.27";

  src = fetchzip {
    url = "https://registry.npmjs.org/9router/-/9router-${version}.tgz";
    hash = "sha256-q68rtIegsBDGoYmW9m7phUkWNE8Vi2MStNPlMT+T28I=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/9router $out/bin
    cp -r . $out/lib/9router/
    chmod +x $out/lib/9router/cli.js
    makeWrapper ${nodejs_22}/bin/node $out/bin/9router \
      --add-flags $out/lib/9router/cli.js \
      --prefix PATH : ${nodejs_22}/bin
    runHook postInstall
  '';

  meta = with lib; {
    description = "AI coding router & token saver - connect CLI tools to 40+ providers with auto-fallback";
    homepage = "https://github.com/decolua/9router";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "9router";
    platforms = platforms.unix;
  };
}