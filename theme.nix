{ pkgs, ... }:
{
  # nvf has no built-in ayu theme; ship ayu-vim and select it manually.
  config.vim = {
    theme.enable = false;

    extraPlugins.ayu = {
      package = pkgs.vimPlugins.ayu-vim;
      setup = ''
        vim.opt.termguicolors = true
        vim.cmd.colorscheme("ayu")
      '';
    };
  };
}
