# nvf.config

Personal Neovim configuration built on [nvf](https://github.com/notashelf/nvf).
Ported from a previous [nixvim](https://github.com/nix-community/nixvim)
configuration; same plugins, same keymaps, different framework.

## Usage

Run directly:

```sh
nix run .
```

Build:

```sh
nix build .#default
./result/bin/nvim
```

The PARA helper script is exposed as a separate package and app:

```sh
nix run .#para -- <args>
```

It honours `PARA_BASE` (default `~/Documents/PARA`).

### Home Manager

```nix
{ inputs, pkgs, ... }:
{
  home.packages = [
    inputs.nvf-config.packages.${pkgs.system}.default
    inputs.nvf-config.packages.${pkgs.system}.para-cli
  ];

  home.sessionVariables = {
    PARA_BASE = "~/pkm";

    # CodeCompanion reads its API keys from these files at request time.
    # Defaults to ~/.config/codecompanion/{claude,gemini} if unset.
    CLAUDE_API_KEY_FILE = "/run/agenix/claude-api-key";
    GEMINI_API_KEY_FILE = "/run/agenix/gemini-api-key";
  };
}
```

## Layout

```
flake.nix         flake inputs (nvf, nixpkgs, gmn, template) and outputs
config.nix        top-level module, sets mapleader, imports the rest
options.nix       vim.options (number, tabstop, clipboard, ...)
theme.nix         ayu colorscheme via vim.extraPlugins
plugins.nix       all plugin enables, setupOpts, LSP, treesitter, codecompanion
keymaps.nix       vim.keymaps list
autocmds.nix      auto-open Neo-tree when launched on a directory
para/             PARA shell script
para-plugin/      Vim plugin layout for the PARA Lua module
  lua/para.lua    require('para') backend
```

## Plugins

### Native nvf modules

- `vim.tabline.nvimBufferline`
- `vim.statusline.lualine` (theme `ayu_dark`)
- `vim.filetree.neo-tree`
- `vim.dashboard.dashboard-nvim`
- `vim.ui.noice`
- `vim.telescope`
- `vim.treesitter` + `context` + `textobjects`
- `vim.comments.comment-nvim`
- `vim.git.gitsigns`
- `vim.binds.whichKey`
- `vim.autocomplete.nvim-cmp` + `vim.snippets.luasnip`
- `vim.lsp.lspconfig` + `vim.lsp.lspsaga` + `vim.lsp.trouble`
- `vim.lsp.inlayHints`
- `vim.assistant.codecompanion-nvim`

### Languages (LSP + treesitter wired by nvf)

- `bash` (bashls)
- `elixir` (elixir-ls)
- `markdown` (marksman)
- `nix` (nil)
- `typst` (tinymist, with `exportPdf = "onSave"` layered via `vim.lsp.config`)

### `vim.extraPlugins` (no native nvf module)

- `ayu-vim` (colorscheme)
- `lazygit.nvim`
- `lsp_lines.nvim`
- `typst.vim`
- `gmn.nvim` (built from the `gmn` flake input)
- `template.nvim` (built from the `template` flake input)
- `para` (built from `./para-plugin`)

### Extra binaries on Neovim's PATH

- `pkgs.erlang-language-platform` (`elp`), wired up in `luaConfigPost` since
  nvf has no Erlang language module.

## Notable porting decisions

- nvf has no built-in ayu theme; ayu-vim is shipped via `vim.extraPlugins`
  with `vim.theme.enable = false` to keep nvf from fighting it.
- The original used `lightline`. nvf does not wrap it, so this configuration
  uses `lualine` with the `ayu_dark` theme instead. Keymaps and look are
  unchanged.
- CodeCompanion adapters use Lua functions, so the entire `adapters` table is
  passed as a single `lua-inline` value (nvf only accepts one inline value at
  that option, not per-adapter inlines).
- `elp` is enabled via `vim.lsp.enable("elp")` in `luaConfigPost`, using the
  modern `vim.lsp.config` API rather than `require('lspconfig').elp.setup()`.
- The `tinymist` settings are layered with `vim.lsp.config("tinymist", { ... })`,
  not by re-calling lspconfig.
- `extraFiles."lua/para.lua"` from the original is replaced by a proper Vim
  plugin built from `./para-plugin`, which puts `lua/para.lua` on `runtimepath`
  the standard way.
- The original's treesitter `install_dir` override is dropped; nvf manages
  grammars via Nix derivations.

## PARA system

`<leader>p` opens the PARA which-key group. Keymaps:

| Keymap         | Action                       |
| -------------- | ---------------------------- |
| `<leader>pl`   | Open log file                |
| `<leader>pla`  | Add log entry                |
| `<leader>plx`  | Archive log entries          |
| `<leader>pt`   | Open tasks file              |
| `<leader>pta`  | Add task                     |
| `<leader>ptx`  | Archive done tasks           |
| `<leader>pn`   | Search notes by name         |
| `<leader>ps`   | Search notes by content      |
| `<leader>px`   | Archive project              |
| `<leader>tt`   | Toggle task done/undone      |

The base path is read from `PARA_BASE` (then `NIXVIM_PKM_PATH`, then
`~/Documents/PARA`) at startup.
