{ inputs, pkgs, lib, paraBase }:
{ ... }:
let
  # Helper for embedding raw lua values inside nix attrsets passed to setup().
  luaInline = expr: { _type = "lua-inline"; inherit expr; };

  # .cmt/.cmi artefacts are compiler-version specific, so prefer the project's own ocamllsp.
  ocamllsp = pkgs.writeShellScript "ocamllsp" ''
    if command -v ocamllsp >/dev/null 2>&1; then
      exec ocamllsp "$@"
    fi
    if [ -n "''${OPAM_SWITCH_PREFIX:-}" ] && command -v opam >/dev/null 2>&1; then
      exec opam exec -- ocamllsp "$@"
    fi
    exec ${lib.getExe pkgs.ocamlPackages.ocaml-lsp} "$@"
  '';
in {
  config.vim = {
    # ── Editor UI ────────────────────────────────────────────────────────────
    tabline.nvimBufferline = {
      enable = true;
      setupOpts.options.numbers = "ordinal";
    };

    statusline.lualine = {
      enable = true;
      theme = "ayu_dark";
    };

    filetree.neo-tree = {
      enable = true;
      setupOpts = {
        close_if_last_window = true;
        filesystem = {
          follow_current_file = { enabled = true; };
          use_libuv_file_watcher = true;
        };
        window = {
          position = "left";
          width = 30;
          mappings = {
            "<tab>" = "next_source";
            "<s-tab>" = "prev_source";
          };
        };
        source_selector = {
          winbar = true;
          statusline = false;
        };
      };
    };

    dashboard.dashboard-nvim = {
      enable = true;
      setupOpts.config = {
        header = [
          "                                            "
          "███╗   ██╗██╗██╗  ██╗██╗   ██╗██╗███╗   ███╗"
          "████╗  ██║██║╚██╗██╔╝██║   ██║██║████╗ ████║"
          "██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██║██╔████╔██║"
          "██║╚██╗██║██║ ██╔██╗ ╚██╗ ██╔╝██║██║╚██╔╝██║"
          "██║ ╚████║██║██╔╝ ██╗ ╚████╔╝ ██║██║ ╚═╝ ██║"
          "╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝╚═╝     ╚═╝"
          "                                            "
          "                                            "
        ];
        shortcut = [
          { icon = " "; desc = "Find";  key = "f"; keymap = "<leader>ff"; action = "Telescope find_files"; }
          { icon = " "; desc = "New";   key = "n"; action = "enew"; }
          { icon = " "; desc = "Grep";  key = "/"; keymap = "<leader>fg"; action = "Telescope live_grep"; }
          { icon = " "; desc = "Log";   key = "l"; keymap = "<leader>pl"; action = "lua require('para').open_log()"; }
          { icon = " "; desc = "Tasks"; key = "t"; keymap = "<leader>pt"; action = "lua require('para').open_tasks()"; }
          { icon = " "; desc = "PARA";  key = "p"; keymap = "<leader>pp"; action = "lua require('para').menu()"; }
          { icon = " "; desc = "Notes"; key = "s"; keymap = "<leader>ps"; action = "lua require('para').search_notes_by_content()"; }
          { icon = " "; desc = "Quit";  key = "q"; action = "qa"; }
        ];
      };
    };

    ui.noice = {
      enable = true;
      setupOpts = {
        cmdline = {
          enabled = true;
          view = "cmdline_popup";
          format = {
            cmdline = {
              pattern = "^:";
              icon = "";
              lang = "vim";
              opts.border.text.top = " Command ";
            };
            substitute = {
              pattern = "^:%%?s/";
              icon = "󰛔";
              lang = "";
            };
          };
        };
        lsp = {
          hover.enabled = false;
          signature.enabled = false;
        };
      };
    };

    visuals.nvim-web-devicons.enable = true;

    # ── Telescope ────────────────────────────────────────────────────────────
    telescope.enable = true;

    # ── Treesitter ───────────────────────────────────────────────────────────
    treesitter = {
      enable = true;
      highlight.enable = true;
      indent.enable = true;
      context = {
        enable = true;
        setupOpts.max_lines = 3;
      };
      textobjects = {
        enable = true;
        setupOpts = {
          move = {
            enable = true;
            goto_next_start = { "]m" = "@function.outer"; };
            goto_previous_start = { "[m" = "@function.outer"; };
          };
          select = {
            enable = true;
            lookahead = true;
            keymaps = {
              "af" = "@function.outer";
              "if" = "@function.inner";
            };
          };
        };
      };
      grammars = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        bash erlang elixir json yaml eex heex lua make markdown
        markdown_inline nix ocaml ocaml_interface regex typst vim vimdoc
      ];
    };

    # ── Comments / Git / Which-key ───────────────────────────────────────────
    comments.comment-nvim.enable = true;

    git = {
      enable = true;
      gitsigns.enable = true;
    };

    binds.whichKey = {
      enable = true;
      register = {
        "<leader>p"   = "󰂮 PARA System";
        "<leader>pp"  = "PARA menu";
        "<leader>pf"  = "Find project/area/resource";
        "<leader>pN"  = "New project/area/resource";
        "<leader>pc"  = "New note in an entity";
        "<leader>pP"  = "Projects menu";
        "<leader>pA"  = "Areas menu";
        "<leader>pR"  = "Resources menu";
        "<leader>pe"  = "Add log entry to an entity";
        "<leader>px"  = "Archive project/area/resource";
        "<leader>pl"  = "Open global log";
        "<leader>pla" = "Add global log entry";
        "<leader>plx" = "Archive global log entries";
        "<leader>pli" = "Insert log entry template";
        "<leader>pt"  = "Open tasks file";
        "<leader>pta" = "Add task";
        "<leader>ptx" = "Archive done tasks";
        "<leader>pti" = "Insert task template";
        "<leader>pn"  = "Search notes by name";
        "<leader>ps"  = "Search notes by content";
        "<leader>pS"  = "PARA statistics";
        "<leader>tt"  = "Toggle task done/undone";
        "<leader>t"   = " Typst";
        "<leader>tp"  = "Preview PDF";
        "<leader>o"   = "OCaml";
        "<leader>ot"  = "Type enclosing";
        "<leader>oc"  = "Construct (fill hole)";
        "<leader>on"  = "Next hole";
        "<leader>oN"  = "Previous hole";
        "<leader>oj"  = "Jump to target";
        "<leader>os"  = "Switch .ml/.mli";
        "<leader>oi"  = "Infer interface";
        "<leader>od"  = "Search definition by type";
        "<leader>o]"  = "Next phrase";
        "<leader>o["  = "Previous phrase";
        "<leader>x"   = " Diagnostics";
        "<leader>l"   = " LSP";
      };
    };

    # ── Autocomplete ─────────────────────────────────────────────────────────
    autocomplete.nvim-cmp = {
      enable = true;
      sources = {
        nvim_lsp = "[LSP]";
        treesitter = "[Treesitter]";
        path = "[Path]";
        buffer = "[Buffer]";
      };
      mappings = {
        next = "<C-n>";
        previous = "<C-p>";
        scrollDocsUp = "<C-d>";
        scrollDocsDown = "<C-f>";
        close = "<C-e>";
        confirm = "<CR>";
      };
    };

    snippets.luasnip.enable = true;

    # ── LSP ──────────────────────────────────────────────────────────────────
    lsp = {
      enable = true;
      lspconfig.enable = true;
      lspsaga = {
        enable = true;
        setupOpts = {
          lightbulb.enable = false;
          symbol_in_winbar.enable = false;
          implement.enable = false;
        };
      };
      trouble = {
        enable = true;
        setupOpts = {
          auto_close = true;
          focus = true;
        };
      };
      inlayHints.enable = true;

      servers.ocaml-lsp.cmd = lib.mkForce [ "${ocamllsp}" ];
    };

    # Per-language LSPs that nvf wraps natively.
    languages = {
      bash.lsp.enable = true;

      elixir = {
        enable = true;
        lsp.enable = true;
      };

      go = {
        enable = true;
        treesitter.enable = true;
        lsp.enable = true;
        format = {
          enable = true;
          type = [ "goimports" ];
        };
        dap.enable = true;
        extraDiagnostics.enable = true;
        extensions.gopher-nvim.enable = true;
      };

      markdown = {
        enable = true;
        lsp.enable = true;
      };

      nix = {
        enable = true;
        lsp = {
          enable = true;
          servers = [ "nil" ];
        };
      };

      ocaml = {
        enable = true;
        lsp.enable = true;
      };

      typst = {
        enable = true;
        lsp.enable = true;
      };
    };

    # ── Tools that must live on Neovim's PATH ────────────────────────────────
    extraPackages = [
      # elp is wired up via raw lspconfig in luaConfigPost; nvf doesn't ship
      # a language module that would install it for us.
      pkgs.erlang-language-platform

      # ocaml-lsp shells out to dune to read the merlin config, and throws on
      # didOpen without it, leaving the document unregistered.
      pkgs.dune_3

      # ocaml-lsp drives ocamlformat over RPC to pretty-print types in hover
      # and type-enclosing output; unrelated to format-on-save.
      pkgs.ocamlPackages.ocamlformat

      # gopls root detection runs `go env GOMOD`, so the toolchain must be on Neovim's PATH.
      pkgs.go
    ];

    # ── Extra plugins not wrapped by nvf ─────────────────────────────────────
    extraPlugins = {
      lazygit-nvim.package = pkgs.vimPlugins.lazygit-nvim;

      typst-vim.package = pkgs.vimPlugins.typst-vim;

      lsp-lines = {
        package = pkgs.vimPlugins.lsp_lines-nvim;
        setup = "require('lsp_lines').setup()";
      };

      # A `keymaps` table replaces the plugin's defaults wholesale, which is how its
      # <leader>p / <leader>t globals are kept from clobbering PARA and Typst.
      ocaml-nvim = {
        package = pkgs.vimPlugins.ocaml-nvim;
        setup = ''
          require('ocaml').setup({
            params = { client = 'ocaml-lsp' },
            keymaps = {
              type_enclosing_grow     = '<Up>',
              type_enclosing_shrink   = '<Down>',
              type_enclosing_increase = '<Right>',
              type_enclosing_decrease = '<Left>',
            },
          })
        '';
      };

      gmn = {
        package = pkgs.vimUtils.buildVimPlugin {
          pname = "gmn-nvim";
          version = "unstable";
          src = inputs.gmn;
          dependencies = [ pkgs.vimPlugins.plenary-nvim ];
        };
        setup = ''
          require('gmn').setup({
            configFilepath = '~/.config/gemini.nvim/config.json',
            timeout = 30 * 1000,
            model = 'gemini-2.5-pro-preview-05-06',
            safetyThreshold = 'BLOCK_ONLY_HIGH',
            stripOutermostCodeblock = function()
              return vim.bo.filetype ~= 'markdown'
            end,
            verbose = false,
          })
        '';
      };

      template-nvim = {
        package = pkgs.vimUtils.buildVimPlugin {
          pname = "template-nvim";
          version = "unstable";
          src = inputs.template;
        };
        setup = ''
          local function git_config(key, fallback)
            local handle = io.popen("git config --global --get " .. key .. " 2>/dev/null")
            if not handle then return fallback end
            local result = handle:read("*l")
            handle:close()
            if result == nil or result == "" then return fallback end
            return result
          end
          require('template').setup({
            temp_dir = '~/.local/share/nvim/templates',
            author = git_config("user.name", "Anonymous"),
            email = git_config("user.email", "anonymous@example.com"),
            project = {
              ['erl'] = {
                'application',
                'common_test',
                'escript',
                'gen_event',
                'gen_fsm',
                'gen_server',
                'gen_statem',
                'header',
                'library',
                'supervisor',
              },
            },
          })
        '';
      };

      # PARA Method plugin — sourced from this flake.
      para = {
        package = pkgs.vimUtils.buildVimPlugin {
          pname = "para";
          version = "local";
          src = ./para-plugin;
        };
      };
    };

    # ── CodeCompanion (assistant) ────────────────────────────────────────────
    assistant.codecompanion-nvim = {
      enable = true;
      setupOpts = {
        adapters = luaInline ''
          {
            anthropic = function()
              local path = vim.env.CLAUDE_API_KEY_FILE
                or vim.fn.expand("~/.config/codecompanion/claude")
              return require('codecompanion.adapters').extend('anthropic', {
                env = { api_key = "cmd:cat " .. path },
              })
            end,
            gemini = function()
              local path = vim.env.GEMINI_API_KEY_FILE
                or vim.fn.expand("~/.config/codecompanion/gemini")
              return require('codecompanion.adapters').extend('gemini', {
                env = { api_key = "cmd:cat " .. path },
              })
            end,
          }
        '';
        opts = {
          send_code = true;
          use_default_actions = true;
          use_default_prompts = true;
          log_level = "DEBUG";
        };
        strategies = {
          agent.adapter  = "anthropic";
          chat.adapter   = "anthropic";
          inline.adapter = "anthropic";
        };
      };
    };

    # ── Extra LSP servers + per-plugin setup not exposed declaratively ──────
    luaConfigPost = ''
      -- elp (Erlang Language Platform): not in nvf's language modules.
      -- nvim-lspconfig ships defaults under vim.lsp.config.elp; just enable it.
      vim.lsp.enable("elp")

      -- Layer project-specific PDF export settings onto tinymist.
      vim.lsp.config("tinymist", {
        settings = {
          exportPdf = "onSave",
          outputPath = "$root/$name",
        },
      })

      -- PARA Method Task & Note Management Setup
      local pkm_path = vim.fn.getenv("PARA_BASE")
      if pkm_path == vim.NIL or pkm_path == "" then
        pkm_path = "${paraBase}"
      end
      pkm_path = vim.fn.expand(pkm_path)

      require('para').setup({
        base_path = pkm_path,
        log_file = pkm_path .. "/log.md",
        log_archive_dir = pkm_path .. "/logs/archive",
        tasks_file = pkm_path .. "/tasks.md",
        tasks_archive_file = pkm_path .. "/tasks_archive.md",
      })
    '';
  };
}
