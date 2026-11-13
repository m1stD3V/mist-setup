local map = vim.keymap.set

-- Core -----------------------------------------------------------------------
map("n", "<leader>w", "<cmd>write<cr>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit window" })
map("n", "<leader>Q", "<cmd>qa<cr>", { desc = "Quit all" })
map("n", "<leader>h", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
map("n", "<Esc>", "<cmd>nohlsearch<cr><Esc>", { desc = "Clear search highlight" })
map("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "Toggle file explorer" })
map("n", "<leader>E", "<cmd>Neotree reveal<cr>", { desc = "Reveal file in explorer" })

-- Windows --------------------------------------------------------------------
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })
map("n", "<leader>sv", "<C-w>v", { desc = "Split vertical" })
map("n", "<leader>sh", "<C-w>s", { desc = "Split horizontal" })
map("n", "<leader>se", "<C-w>=", { desc = "Equalize splits" })
map("n", "<leader>sx", "<cmd>close<cr>", { desc = "Close split" })
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Grow window" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Shrink window" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Shrink window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Grow window width" })

-- Buffers --------------------------------------------------------------------
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })
map("n", "<leader>bo", "<cmd>%bd|e#<cr>", { desc = "Delete other buffers" })

-- Visual ---------------------------------------------------------------------
map("v", "J", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })
map("v", "<", "<gv", { desc = "Outdent selection" })
map("v", ">", ">gv", { desc = "Indent selection" })
map("v", "p", "\"_dP", { desc = "Paste without yanking" })

-- Telescope ------------------------------------------------------------------
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
map("n", "<leader>fw", "<cmd>Telescope grep_string<cr>", { desc = "Grep word under cursor" })
map("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Find buffers" })
map("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "Find help" })
map("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Recent files" })
map("n", "<leader>fc", "<cmd>Telescope commands<cr>", { desc = "Commands" })
map("n", "<leader>fk", "<cmd>Telescope keymaps<cr>", { desc = "Keymaps" })
map("n", "<leader>fd", "<cmd>Telescope diagnostics<cr>", { desc = "Diagnostics" })
map("n", "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>", { desc = "Document symbols" })
map("n", "<leader>fS", "<cmd>Telescope lsp_workspace_symbols<cr>", { desc = "Workspace symbols" })
map("n", "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<cr>", { desc = "Fuzzy search buffer" })

-- LSP ------------------------------------------------------------------------
map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
map("n", "<leader>cr", vim.lsp.buf.rename, { desc = "Rename symbol" })
map("n", "<leader>cf", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format file" })
map("n", "<leader>ci", "<cmd>Telescope lsp_implementations<cr>", { desc = "Implementations" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Diagnostic float" })
map("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })
map("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })
map("n", "[e", function()
  vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR, float = true })
end, { desc = "Previous error" })
map("n", "]e", function()
  vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR, float = true })
end, { desc = "Next error" })

-- Trouble / outline ----------------------------------------------------------
map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Diagnostics" })
map("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Buffer diagnostics" })
map("n", "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>", { desc = "Symbols" })
map("n", "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", { desc = "LSP references" })
map("n", "<leader>co", "<cmd>AerialToggle<cr>", { desc = "Outline" })

-- Git ------------------------------------------------------------------------
map("n", "<leader>gg", "<cmd>LazyGit<cr>", { desc = "LazyGit" })
map("n", "<leader>gs", "<cmd>Gitsigns stage_hunk<cr>", { desc = "Stage hunk" })
map("n", "<leader>gr", "<cmd>Gitsigns reset_hunk<cr>", { desc = "Reset hunk" })
map("n", "<leader>gp", "<cmd>Gitsigns preview_hunk<cr>", { desc = "Preview hunk" })
map("n", "<leader>gb", "<cmd>Gitsigns toggle_current_line_blame<cr>", { desc = "Toggle line blame" })
map("n", "<leader>gd", "<cmd>Gitsigns diffthis<cr>", { desc = "Diff this" })

-- Terminal -------------------------------------------------------------------
map("n", "<leader>tt", "<cmd>ToggleTerm direction=float<cr>", { desc = "Floating terminal" })
map("n", "<leader>th", "<cmd>ToggleTerm direction=horizontal size=14<cr>", { desc = "Horizontal terminal" })
map("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- UI toggles -----------------------------------------------------------------
map("n", "<leader>un", function()
  vim.o.number = not vim.o.number
  vim.o.relativenumber = vim.o.number
end, { desc = "Toggle line numbers" })
map("n", "<leader>uw", function()
  vim.wo.wrap = not vim.wo.wrap
end, { desc = "Toggle wrap" })
map("n", "<leader>us", function()
  vim.wo.spell = not vim.wo.spell
end, { desc = "Toggle spell" })
map("n", "<leader>ut", function()
  require("mist.theme").reload()
end, { desc = "Reload mist theme" })
map("n", "<leader>uh", function()
  local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
  vim.lsp.inlay_hint.enable(not enabled, { bufnr = 0 })
  vim.notify("Inlay hints " .. (enabled and "disabled" or "enabled"))
end, { desc = "Toggle inlay hints" })
map("n", "<leader>uf", function()
  vim.g.autoformat = not vim.g.autoformat
  vim.notify("Autoformat " .. (vim.g.autoformat and "enabled" or "disabled"))
end, { desc = "Toggle format on save" })

-- Sessions / undo ------------------------------------------------------------
map("n", "<leader>qs", function()
  require("persistence").load()
end, { desc = "Restore session" })
map("n", "<leader>ql", function()
  require("persistence").load({ last = true })
end, { desc = "Restore last session" })
map("n", "<leader>qd", function()
  require("persistence").stop()
end, { desc = "Stop session recording" })
map("n", "<leader>uU", "<cmd>UndotreeToggle<cr>", { desc = "Undo tree" })

-- Quickfix -------------------------------------------------------------------
map("n", "<leader>xq", "<cmd>copen<cr>", { desc = "Quickfix list" })
map("n", "<leader>xl", "<cmd>lopen<cr>", { desc = "Location list" })

-- Neovim 0.12 removed LspInfo; keep the familiar alias.
if vim.fn.exists(":LspInfo") == 0 then
  vim.api.nvim_create_user_command("LspInfo", function()
    vim.cmd("checkhealth vim.lsp")
  end, { desc = "Show LSP status" })
end
