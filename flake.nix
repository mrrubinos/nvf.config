{
  description = "Neovim configuration with nvf";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nvf.url = "github:notashelf/nvf";
    nvf.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";

    gmn = {
      url = "github:meinside/gmn.nvim";
      flake = false;
    };
    template = {
      url = "github:nvimdev/template.nvim";
      flake = false;
    };
  };

  outputs = inputs:
    inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = inputs.nixpkgs.legacyPackages.${system};

        # Baked into init.lua and the para wrapper, so a launch with no
        # environment at all still finds the store. PARA_BASE overrides it.
        defaultParaBase = "~/Documents/PARA";

        mkNvim = { paraBase ? defaultParaBase }:
          (inputs.nvf.lib.neovimConfiguration {
            inherit pkgs;
            modules = [ (import ./config.nix { inherit inputs pkgs paraBase; }) ];
          }).neovim;

        mkPara = { paraBase ? defaultParaBase }:
          pkgs.writeShellScriptBin "para" ''
            export PARA_BASE="''${PARA_BASE:-${paraBase}}"
            export PARA_LOGS="$PARA_BASE/logs"
            exec ${pkgs.bash}/bin/bash ${./para} "$@"
          '';

        nvim = mkNvim { };
        para-cli = mkPara { };
      in {
        lib = { inherit mkNvim mkPara defaultParaBase; };

        packages.default = nvim;
        packages.para-cli = para-cli;

        apps.default = {
          type = "app";
          program = "${nvim}/bin/nvim";
        };
        apps.para = {
          type = "app";
          program = "${para-cli}/bin/para";
        };
      });
}
