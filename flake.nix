{
  description = "Flake to create and run Package and DevShell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      with pkgs;
      {
        devShells = {
          myshell = mkShell {
            shellHook = "echo -e '\n Succesfully loaded development environment!\n' ";
            packages = [
              nasm
              nim
              nimble
              nimlangserver
              openssl
            ];
          };
          default = self.devShells.${system}.myshell;
        };
      }
    );
}
