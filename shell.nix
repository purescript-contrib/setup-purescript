let
  pkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/23.11.tar.gz";
  }) {};

  # 2021-08-05 nix-prefetch-git https://github.com/justinwoo/easy-purescript-nix
  pursPkgs = import (pkgs.fetchFromGitHub {
    owner = "justinwoo";
    repo = "easy-purescript-nix";
    rev = "117fd96acb69d7d1727df95b6fde9d8715e031fc";
    sha256 = "1g91mzllzghm1x8y0np8vhrz3az087xipci23f28ax22w4h13hlm";
  }) { inherit pkgs; };

in pkgs.stdenv.mkDerivation {
  name = "setup-purescript";
  buildInputs = with pursPkgs; [
    pursPkgs.purs
    pursPkgs.spago
    pkgs.nodejs-18_x
  ];
}
