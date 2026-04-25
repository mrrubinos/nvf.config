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

        nvim = (inputs.nvf.lib.neovimConfiguration {
          inherit pkgs;
          modules = [ (import ./config.nix { inherit inputs pkgs; }) ];
        }).neovim;

        para-cli = pkgs.writeShellScriptBin "para" ''
          export PARA_BASE="''${PARA_BASE:-~/Documents/PARA}"
          export PARA_LOGS="$PARA_BASE/logs"
          exec ${pkgs.bash}/bin/bash ${./para} "$@"
        '';
      in {
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
