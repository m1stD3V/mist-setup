return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope-fzf-native.nvim",
      "nvim-telescope/telescope-ui-select.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = "Telescope",
    config = function()
      local finder = vim.fn.executable("fd") == 1 and "fd" or "fdfind"
      local telescope = require("telescope")

      telescope.setup({
        defaults = {
          prompt_prefix = "  ",
          selection_caret = "  ",
          entry_prefix = "  ",
          sorting_strategy = "ascending",
          layout_strategy = "horizontal",
          layout_config = {
            prompt_position = "top",
            width = 0.9,
            height = 0.85,
            preview_width = 0.55,
          },
          file_ignore_patterns = {
            "node_modules",
            "%.git/",
            "target/",
            "dist/",
            "build/",
            "%.cache/",
          },
          mappings = {
            i = {
              ["<C-j>"] = "move_selection_next",
              ["<C-k>"] = "move_selection_previous",
              ["<C-u>"] = false,
              ["<C-d>"] = false,
            },
          },
        },
        pickers = {
          find_files = {
            hidden = true,
            find_command = {
              finder,
              "--type",
              "f",
              "--hidden",
              "--follow",
              "--exclude",
              ".git",
              "--exclude",
              "node_modules",
              "--exclude",
              "target",
            },
          },
          live_grep = {
            additional_args = { "--hidden", "--glob", "!.git/*" },
          },
          oldfiles = {
            include_current_session = true,
          },
        },
        extensions = {
          ["ui-select"] = {
            require("telescope.themes").get_dropdown(),
          },
        },
      })

      pcall(telescope.load_extension, "fzf")
      pcall(telescope.load_extension, "ui-select")
    end,
  },
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
    cond = function()
      return vim.fn.executable("make") == 1
    end,
  },
}
