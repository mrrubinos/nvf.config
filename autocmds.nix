{ ... }:
{
  config.vim.autocmds = [
    {
      event = [ "VimEnter" ];
      desc = "Open Neo-tree when nvim is launched on a directory";
      callback = {
        _type = "lua-inline";
        expr = ''
          function(data)
            local directory = vim.fn.isdirectory(data.file) == 1
            if not directory then
              return
            end
            vim.cmd.cd(data.file)
            require("neo-tree.command").execute({ action = "show" })
          end
        '';
      };
    }
  ];
}
