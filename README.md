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

It honours `PARA_BASE`, falling back to the base compiled into the wrapper
(`~/Documents/PARA` unless `mkPara` was given another).

### Home Manager

`mkNvim` and `mkPara` take the PARA base directory as a build-time argument.
The value is compiled into `init.lua` and into the `para` wrapper, so a launch
with no environment reaches the same store as a launch from a shell. This is
what makes `neovide` started from a window manager menu agree with `nvim`
started from a terminal.

```nix
{ inputs, pkgs, ... }:
let
  para = inputs.nvf-config.lib.${pkgs.system};
  paraBase = "~/drive/mrrubinos/pkm";
in
{
  home.packages = [
    (para.mkNvim { inherit paraBase; })
    (para.mkPara { inherit paraBase; })
  ];

  home.sessionVariables = {
    # CodeCompanion reads its API keys from these files at request time.
    # Defaults to ~/.config/codecompanion/{claude,gemini} if unset.
    CLAUDE_API_KEY_FILE = "/run/agenix/claude-api-key";
    GEMINI_API_KEY_FILE = "/run/agenix/gemini-api-key";
  };
}
```

`packages.default` and `packages.para-cli` are the same builders called with
the default base, `~/Documents/PARA`. Use them when the path does not matter:

```nix
home.packages = [
  inputs.nvf-config.packages.${pkgs.system}.default
  inputs.nvf-config.packages.${pkgs.system}.para-cli
];
```

Exporting `PARA_BASE` still overrides the compiled value, so a one-off store
needs no rebuild.

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

### Layout

A project, area or resource is a directory under its category root. It holds
an optional page, a `notes/` directory and its own log. Subdirectories appear
the first time you put something in them.

```
$PARA_BASE/
  log.md                      global log
  logs/archive/               archived global log entries
  tasks.md
  tasks_archive.md
  1_projects/api-redesign/
    api-redesign.md           the page, optional
    notes/auth-flow.md
    log.md                    project log
    logs/archive/
  2_areas/health/
  3_resources/ste100-cheatsheet/
  4_archive/                  whole directories move here
```

The page is never mandatory. `new` writes one from the template unless you
pass `--bare`. Every command tolerates its absence: opening an entity with no
page gives you a picker over the files it holds. A flat `<slug>.md` from the
old layout becomes `<slug>/<slug>.md` the first time you add a note or a log
entry to it.

The base path is read from `PARA_BASE`, falling back to the base compiled in
by `mkNvim` / `mkPara` (`~/Documents/PARA` unless you passed another).

### Keymaps

`<leader>p` opens the PARA which-key group. `<leader>pp` opens a menu that
reaches every action, so the keymaps below are shortcuts, not the only way in.

| Keymap        | Action                             |
| ------------- | ---------------------------------- |
| `<leader>pp`  | PARA menu                          |
| `<leader>pf`  | Find and open any entity           |
| `<leader>pN`  | New project, area or resource      |
| `<leader>pc`  | New note in an entity              |
| `<leader>pP`  | Projects menu                      |
| `<leader>pA`  | Areas menu                         |
| `<leader>pR`  | Resources menu                     |
| `<leader>pe`  | Add log entry to an entity         |
| `<leader>px`  | Archive an entity                  |
| `<leader>pl`  | Open global log                    |
| `<leader>pla` | Add global log entry               |
| `<leader>plx` | Archive global log entries         |
| `<leader>pli` | Insert log entry template          |
| `<leader>pt`  | Open tasks file                    |
| `<leader>pta` | Add task                           |
| `<leader>ptx` | Archive done tasks                 |
| `<leader>pti` | Insert task template               |
| `<leader>pn`  | Search notes by name               |
| `<leader>ps`  | Search notes by content            |
| `<leader>pS`  | Statistics                         |
| `<leader>tt`  | Toggle task done or undone         |

`:Para [subcommand]` reaches the same menus from the command line. The
subcommands are `menu`, `find`, `projects`, `areas`, `resources`, `note`,
`tasks`, `log`, `search` and `stats`. With no argument it opens the menu.

Pickers use Telescope when it is available and fall back to `vim.ui.select`.

### Shell CLI

```sh
nix run .#para -- <args>
```

Every entity verb works the same for `project`, `area` and `resource`:

```sh
para project new "API Redesign"        # create, with a page
para project new "Spike" --bare        # create, no page
para project list                      # list with note and log counts
para project open api-redesign
para project note api-redesign "Auth flow"
para project notes api-redesign
para project log api-redesign "shipped the token endpoint"
para project log-show api-redesign
para project log-archive api-redesign 2026-01-01
para project archive api-redesign
para project path api-redesign
para project api-redesign              # shorthand for open
```

Listing and the rest:

```sh
para list projects | areas | resources | archive
para list notes [name]                 # one entity, or every note
para list log [name]                   # one entity log, or the global log
para list tasks --open --project api-redesign
para task --critical --project api-redesign "Fix token expiry"
para log "Had a good meeting with the team"
para search "supervision tree"
para stats
para menu                              # interactive, covers everything
```

`para` with no argument opens the menu. `para help` lists every command.
Menus use `fzf` when it is on `PATH` and fall back to the shell `select`
builtin. Colour is disabled when output is not a terminal, or when `NO_COLOR`
is set.
