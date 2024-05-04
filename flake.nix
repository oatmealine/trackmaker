{
  description = "cathy";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        #inherit (pkgs) stdenv lib;
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [ love gnome.zenity ];
        };
      }
    );
}
