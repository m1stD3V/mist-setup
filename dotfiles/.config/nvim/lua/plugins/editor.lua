return {
  {
    "numToStr/Comment.nvim",
    event = "VeryLazy",
    opts = {},
  },
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {
      check_ts = true,
      fast_wrap = {},
    },
  },
  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    opts = {},
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "┃" },
        change = { text = "┃" },
        delete = { text = "┃" },
        topdelete = { text = "‾" },
        changedelete = { text = "┃" },
        untracked = { text = "┆" },
      },
      current_line_blame = false,
      preview_config = { border = "single" },
    },
  },
  {
    "kdheepak/lazygit.nvim",
    cmd = "LazyGit",
    dependencies = { "nvim-lua/plenary.nvim" },
  },
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    cmd = "ToggleTerm",
    opts = {
      size = 14,
      open_mapping = [[<c-\>]],
      direction = "float",
      shade_terminals = true,
      start_in_insert = true,
      persist_size = true,
      close_on_exit = true,
    },
  },
  {
    "folke/todo-comments.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = { signs = true },
  },
  {
    "mbbill/undotree",
    cmd = "UndotreeToggle",
  },
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {
      dir = vim.fn.stdpath("state") .. "/sessions/",
    },
  },
  {
    "yamatsum/nvim-cursorline",
    event = "VeryLazy",
    opts = {
      cursorline = {
        enable = true,
        timeout = 0,
        number = false,
      },
      cursorword = {
        enable = true,
        timeout = 0,
        min_length = 3,
        hl = { underline = true },
      },
    },
  },
}
