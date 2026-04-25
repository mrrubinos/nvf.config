{ ... }:
{
  config.vim.keymaps = [
    # ── Windows / buffers / misc ─────────────────────────────────────────────
    { mode = "n"; key = "<leader>e";  action = ":Neotree toggle<CR>";          silent = true; desc = "Toggle Explorer"; }
    { mode = "n"; key = "<leader>,";  action = ":BufferLineCyclePrev<CR>";     silent = true; desc = "Switch Buffer"; }
    { mode = "n"; key = "<leader>-";  action = ":split<CR>";                   silent = true; desc = "Split horizontal"; }
    { mode = "n"; key = "<leader>|";  action = ":vsplit<CR>";                  silent = true; desc = "Split vertical"; }
    { mode = "n"; key = "<leader>/";  action = "<Plug>(comment_toggle_linewise_current)"; silent = true; desc = "Toggle comment"; }
    { mode = "n"; key = "<leader>:";  action = "<cmd>Telescope command_history<CR>"; silent = true; desc = "Command History"; }

    # ── Buffer operations ────────────────────────────────────────────────────
    { mode = "n"; key = "<leader>bb"; action = "<cmd>Telescope buffers<CR>";   silent = true; desc = "Switch Buffer"; }
    { mode = "n"; key = "<leader>bd"; action = ":bdelete<CR>";                 silent = true; desc = "Delete Buffer"; }
    { mode = "n"; key = "<leader>bn"; action = ":bnext<CR>";                   silent = true; desc = "Next Buffer"; }
    { mode = "n"; key = "<leader>bp"; action = ":bprevious<CR>";               silent = true; desc = "Previous Buffer"; }

    # ── File operations ──────────────────────────────────────────────────────
    { mode = "n"; key = "<leader>ff"; action = "<cmd>Telescope find_files<CR>"; silent = true; desc = "Find File"; }
    { mode = "n"; key = "<leader>fg"; action = "<cmd>Telescope live_grep<CR>";  silent = true; desc = "Find Text"; }
    { mode = "n"; key = "<leader>fr"; action = "<cmd>Telescope oldfiles<CR>";   silent = true; desc = "Recent Files"; }
    { mode = "n"; key = "<leader>fn"; action = ":enew<CR>";                     silent = true; desc = "New File"; }

    # ── Git ──────────────────────────────────────────────────────────────────
    { mode = "n"; key = "<leader>gg"; action = ":LazyGit<CR>";                  silent = true; desc = "LazyGit"; }
    { mode = "n"; key = "<leader>gb"; action = "<cmd>Telescope git_branches<CR>"; silent = true; desc = "Branches"; }
    { mode = "n"; key = "<leader>gc"; action = "<cmd>Telescope git_commits<CR>";  silent = true; desc = "Commits"; }
    { mode = "n"; key = "<leader>gs"; action = "<cmd>Telescope git_status<CR>";   silent = true; desc = "Status"; }
    { mode = "n"; key = "<leader>gr"; action = "<cmd>Gitsigns reset_hunk<CR>";    silent = true; desc = "Reset"; }
    { mode = "n"; key = "<leader>gn"; action = "<cmd>Gitsigns next_hunk<CR>";     silent = true; desc = "Next"; }
    { mode = "n"; key = "<leader>gp"; action = "<cmd>Gitsigns prev_hunk<CR>";     silent = true; desc = "Previous"; }

    # ── LSP (lspsaga) ────────────────────────────────────────────────────────
    { mode = "n"; key = "<leader>ih"; action = "<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<CR>"; silent = true; desc = "Toggle Inlay Hints"; }
    { mode = "n"; key = "<leader>lh"; action = "<cmd>Lspsaga hover_doc<CR>";       silent = true; desc = "Hover Doc"; }
    { mode = "n"; key = "<leader>ld"; action = "<cmd>Lspsaga goto_definition<CR>"; silent = true; desc = "Go to Definition"; }
    { mode = "n"; key = "<leader>lp"; action = "<cmd>Lspsaga peek_definition<CR>"; silent = true; desc = "Peek Definition"; }
    { mode = "n"; key = "<leader>lD"; action = ":lua vim.lsp.buf.declaration()<CR>"; silent = true; desc = "Declaration"; }
    { mode = "n"; key = "<leader>li"; action = "<cmd>Lspsaga finder<CR>";          silent = true; desc = "Finder (def+ref+impl)"; }
    { mode = "n"; key = "<leader>la"; action = "<cmd>Lspsaga code_action<CR>";     silent = true; desc = "Code Action"; }
    { mode = "n"; key = "<leader>lR"; action = "<cmd>Lspsaga rename<CR>";          silent = true; desc = "Rename"; }
    { mode = "n"; key = "<leader>lo"; action = "<cmd>Lspsaga outline<CR>";         silent = true; desc = "Outline"; }
    { mode = "n"; key = "<leader>lc"; action = "<cmd>Lspsaga incoming_calls<CR>";  silent = true; desc = "Incoming Calls"; }
    { mode = "n"; key = "<leader>lC"; action = "<cmd>Lspsaga outgoing_calls<CR>";  silent = true; desc = "Outgoing Calls"; }

    # ── Telescope LSP wrappers ───────────────────────────────────────────────
    { mode = "n"; key = "<leader>lr"; action = "<cmd>Telescope lsp_references<CR>";        silent = true; desc = "References (Telescope)"; }
    { mode = "n"; key = "<leader>ls"; action = "<cmd>Telescope lsp_document_symbols<CR>";  silent = true; desc = "Document Symbols"; }
    { mode = "n"; key = "<leader>lS"; action = "<cmd>Telescope lsp_workspace_symbols<CR>"; silent = true; desc = "Workspace Symbols"; }
    { mode = "n"; key = "<leader>lf"; action = ":lua vim.lsp.buf.format()<CR>";            silent = true; desc = "Format"; }

    # ── Trouble diagnostics ──────────────────────────────────────────────────
    { mode = "n"; key = "<leader>xx"; action = "<cmd>Trouble diagnostics toggle<CR>";              silent = true; desc = "Toggle Diagnostics"; }
    { mode = "n"; key = "<leader>xw"; action = "<cmd>Trouble diagnostics toggle<CR>";              silent = true; desc = "Workspace Diagnostics"; }
    { mode = "n"; key = "<leader>xd"; action = "<cmd>Trouble diagnostics toggle filter.buf=0<CR>"; silent = true; desc = "Document Diagnostics"; }
    { mode = "n"; key = "<leader>xq"; action = "<cmd>Trouble qflist toggle<CR>";                   silent = true; desc = "Quickfix List"; }

    # ── Search ───────────────────────────────────────────────────────────────
    { mode = "n"; key = "<leader>sh"; action = "<cmd>Telescope help_tags<CR>"; silent = true; desc = "Help Tags"; }
    { mode = "n"; key = "<leader>sk"; action = "<cmd>Telescope keymaps<CR>";   silent = true; desc = "Keymaps"; }
    { mode = "n"; key = "<leader>sc"; action = "<cmd>Telescope commands<CR>";  silent = true; desc = "Commands"; }

    # ── CodeCompanion ────────────────────────────────────────────────────────
    { mode = "v";          key = "<leader>ce"; action = "<cmd>CodeCompanion /explain<cr>"; desc = "Explain Selection / Buffer (CodeCompanion)"; }
    { mode = "v";          key = "<leader>cl"; action = "<cmd>CodeCompanion /lsp<cr>";     desc = "Explain LSP (CodeCompanion)"; }
    { mode = "v";          key = "<leader>cf"; action = "<cmd>CodeCompanion /fix<cr>";     desc = "Fix (CodeCompanion)"; }
    { mode = "v";          key = "<leader>ct"; action = "<cmd>CodeCompanion /tests<cr>";   desc = "Generate tests (CodeCompanion)"; }
    { mode = "n";          key = "<leader>cC"; action = "<cmd>CodeCompanion /commit<cr>";  desc = "Generate commit message (CodeCompanion)"; }
    { mode = "n";          key = "<leader>cc"; action = "<cmd>CodeCompanionChat<cr>";      desc = "Chat (CodeCompanion)"; }
    { mode = "n";          key = "<leader>ct"; action = "<cmd>CodeCompanionChat Toggle<cr>"; desc = "Chat Toggle (CodeCompanion)"; }
    { mode = "n";          key = "<leader>cb"; action = "<cmd>CodeCompanionChat #buffer<cr>"; desc = "Chat with Buffer Content (CodeCompanion)"; }
    { mode = "v";          key = "<leader>ca"; action = "<cmd>CodeCompanionActions<cr>";   desc = "Add Selection to Chat Buffer (CodeCompanion)"; }
    { mode = [ "v" "n" ];  key = "<leader>cg"; action = "<cmd>CodeCompanionToggle gemini<cr>";    desc = "Toggle to Gemini Adapter (CodeCompanion)"; }
    { mode = [ "v" "n" ];  key = "<leader>ca"; action = "<cmd>CodeCompanionToggle anthropic<cr>"; desc = "Toggle to Anthropic Adapter (CodeCompanion)"; }

    # ── Typst ────────────────────────────────────────────────────────────────
    { mode = "n"; key = "<leader>tp";
      action = "<cmd>lua vim.fn.jobstart('xdg-open ' .. vim.fn.expand('%:p:r') .. '.pdf', {detach = true})<CR>";
      silent = true; desc = "Preview PDF"; }
  ];
}
