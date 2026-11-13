local opt = vim.opt

-- UI -------------------------------------------------------------------------
opt.termguicolors = true
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.colorcolumn = "100"
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false
opt.linebreak = true
opt.list = true
opt.listchars = {
  tab = "» ",
  trail = "·",
  nbsp = "␣",
  extends = "›",
  precedes = "‹",
}
opt.fillchars = {
  eob = " ",
  fold = "·",
  foldopen = "▾",
  foldclose = "▸",
  diff = "╱",
  vert = "│",
  horiz = "─",
}
opt.pumheight = 12
opt.cmdheight = 1
opt.showmode = false
opt.laststatus = 3
opt.ruler = false
opt.showcmd = false
opt.winborder = "single"
opt.splitright = true
opt.splitbelow = true
opt.splitkeep = "screen"
opt.helpheight = 20

-- Editing --------------------------------------------------------------------
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true
opt.autoindent = true
opt.breakindent = true
opt.shiftround = true
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true
opt.inccommand = "split"
opt.fileencoding = "utf-8"
opt.backup = false
opt.writebackup = false
opt.swapfile = false
opt.undofile = true
opt.confirm = true
opt.hidden = true
opt.updatetime = 200
opt.timeoutlen = 350
opt.ttimeoutlen = 20
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.completeopt = { "menuone", "noselect" }
opt.pumblend = 0
opt.winblend = 0
opt.sessionoptions = "buffers,curdir,folds,help,tabpages,winsize,terminal"
opt.shada = "!,'100,<50,s10,h"

local undodir = vim.fn.stdpath("state") .. "/undo"
vim.fn.mkdir(undodir, "p")
opt.undodir = undodir

-- Filetype tuning ------------------------------------------------------------
vim.g.autoformat = true

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("MistIndent", { clear = true }),
  pattern = { "c", "cpp", "rust", "java", "go", "zig" },
  callback = function()
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
    vim.bo.softtabstop = 4
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("MistWrap", { clear = true }),
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.wo.wrap = true
    vim.wo.linebreak = true
    vim.wo.spell = true
  end,
})

-- Virtual color column -------------------------------------------------------
local function setup_virt_column()
  local ns = vim.api.nvim_create_namespace("virt-column")

  local function refresh_highlight()
    vim.api.nvim_set_hl(0, "VirtColumn", { link = "NonText", default = true })
    vim.api.nvim_set_hl(0, "ColorColumn", {})
  end

  refresh_highlight()

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("VirtColumn", { clear = true }),
    callback = refresh_highlight,
  })

  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, win, bufnr, toprow, botrow)
      if vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ~= "" then
        return false
      end

      local textwidth = vim.api.nvim_get_option_value("textwidth", { buf = bufnr })
      local columns = {}
      for _, value in ipairs(vim.split(
        vim.api.nvim_get_option_value("colorcolumn", { win = win }),
        ",",
        { trimempty = true }
      )) do
        local col
        if vim.startswith(value, "+") then
          col = textwidth ~= 0 and textwidth + tonumber(value:sub(2)) or nil
        elseif vim.startswith(value, "-") then
          col = textwidth ~= 0 and textwidth - tonumber(value:sub(2)) or nil
        else
          col = tonumber(value)
        end
        if col then
          columns[#columns + 1] = col
        end
      end

      if #columns == 0 then
        return false
      end

      local leftcol = vim.api.nvim_win_call(win, function()
        return vim.fn.winsaveview().leftcol
      end)
      local last = math.min(botrow, vim.api.nvim_buf_line_count(bufnr) - 1)

      for row = toprow, last do
        local width = vim.api.nvim_win_call(win, function()
          return vim.fn.virtcol({ row + 1, "$" }) - 1
        end)
        for _, col in ipairs(columns) do
          local win_col = col - 1 - leftcol
          if width < col and win_col >= 0 then
            pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, 0, {
              virt_text = { { "│", "VirtColumn" } },
              virt_text_pos = "overlay",
              hl_mode = "combine",
              virt_text_win_col = win_col,
              priority = 1,
              ephemeral = true,
            })
          end
        end
      end

      return false
    end,
  })
end

setup_virt_column()
