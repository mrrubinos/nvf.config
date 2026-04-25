{ inputs, pkgs }:
{ lib, ... }:
{
  imports = [
    ./options.nix
    ./theme.nix
    (import ./plugins.nix { inherit inputs pkgs lib; })
    ./keymaps.nix
    ./autocmds.nix
  ];

  config.vim.globals = {
    mapleader = " ";
    maplocalleader = " ";
  };
}
