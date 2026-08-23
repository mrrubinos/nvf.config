{ inputs, pkgs, paraBase }:
{ lib, ... }:
{
  imports = [
    ./options.nix
    ./theme.nix
    (import ./plugins.nix { inherit inputs pkgs lib paraBase; })
    ./keymaps.nix
    ./autocmds.nix
  ];

  config.vim.globals = {
    mapleader = " ";
    maplocalleader = " ";
  };
}
