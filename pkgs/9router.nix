{ lib, buildNpmPackage, fetchFromGitHub }:

buildNpmPackage rec {
  pname = "9router";
  version = "0.4.27";

  src = fetchFromGitHub {
    owner = "decolua";
    repo = "9router";
    rev = "v${version}";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  meta = with lib; {
    description = "AI coding router & token saver - connect CLI tools to 40+ providers with auto-fallback";
    homepage = "https://github.com/decolua/9router";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "9router";
  };
}