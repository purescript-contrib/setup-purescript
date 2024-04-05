{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    purescript-overlay = {
      url = "github:thomashoneyman/purescript-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      nixpkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
        config = { };
        overlays = builtins.attrValues self.overlays;
      });
    in {
      overlays = {
        purescript = inputs.purescript-overlay.overlays.default;
      };

      # fix
      # does not provide attribute 'packages.x86_64-linux.default' or 'defaultPackage.x86_64-linux'
      # on `nix shell`
      packages = self.devShells;

      devShells = forAllSystems (system:
        # pkgs now has access to the standard PureScript toolchain
        let pkgs = nixpkgsFor.${system}; in {
          default = pkgs.mkShell {
            name = "setup-purescript";
            buildInputs = with pkgs; [
              purs
              spago-unstable
              nodejs_latest
            ];

            shellHook = ''
              source <(node --completion-bash)
              source <(spago --bash-completion-script `which spago`)
            '';
          };
        });
  };
}
