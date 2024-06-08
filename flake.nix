{
  description = "thmshmm.github.io flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=release-23.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-utils, nixpkgs }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

      in rec {
        devShell = pkgs.mkShell { nativeBuildInputs = [ pkgs.nodejs pkgs.nodePackages."@astrojs/language-server" pkgs.nodePackages.typescript-language-server ]; };
      });
}
