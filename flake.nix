{
  description = "Modo Emacs para el lenguaje Aiken";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        aiken-mode = pkgs.emacsPackages.trivialBuild {
          pname = "aiken-mode";
          version = "0.1.0";
          src = ./.; # Usa el directorio actual como fuente

          # Si tienes dependencias de otros paquetes de Emacs, agrégalas aquí
          # propagatedUserEnvPkgs = with pkgs.emacsPackages; [
          #   pkg1
          #   pkg2
          # ];
        };
      in
      {
        packages = {
          default = aiken-mode;
          aiken-mode = aiken-mode;
        };
      }
    );
}
