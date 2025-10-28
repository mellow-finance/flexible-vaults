{
  description = "Flexible Vaults - Solidity development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    foundry.url = "github:shazow/foundry.nix/main";
  };

  outputs = { self, nixpkgs, flake-utils, foundry }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ foundry.overlay ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            foundry-bin
            yarn
          ];
          shellHook = ''
            echo "🔨 Flexible Vaults Development Environment"
            echo ""
            echo "Available tools:"
            echo "  - forge $(forge --version | head -1)"
            echo "  - yarn $(yarn --version)"

            export PATH=$PWD/node_modules/.bin:$PATH
          '';
        };
      }
    );
}
