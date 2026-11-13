return {
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    opts = function()
      local c = require("mist.theme").palette
      return {
        options = {
          theme = require("mist.lualine"),
          globalstatus = true,
          disabled_filetypes = {
            statusline = { "dashboard", "alpha", "neo-tree", "lazy" },
          },
          section_separators = { left = "", right = "" },
          component_separators = { left = "│", right = "│" },
          always_divide_middle = true,
        },
        sections = {
          lualine_a = {
            {
              "mode",
              fmt = function(s)
                return s:upper()
              end,
            },
          },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = {
            {
              "filename",
              path = 1,
              symbols = {
                modified = " ●",
                readonly = " RO",
                unnamed = " [NO NAME]",
                newfile = " NEW",
              },
            },
          },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = {
            {
              function()
                local ok, opencode = pcall(require, "opencode")
                return ok and opencode.statusline() or ""
              end,
            },
            "location",
          },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { "filename" },
          lualine_x = { "location" },
          lualine_y = {},
          lualine_z = {},
        },
        tabline = {},
        extensions = { "neo-tree", "lazy" },
      }
    end,
  },
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", desc = "Toggle Pin" },
      { "<leader>bP", "<Cmd>BufferLineGroupClose ungrouped<CR>", desc = "Delete Non-Pinned Buffers" },
      { "<leader>br", "<Cmd>BufferLineCloseRight<CR>", desc = "Delete Buffers to the Right" },
      { "<leader>bl", "<Cmd>BufferLineCloseLeft<CR>", desc = "Delete Buffers to the Left" },
      { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
      { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
      { "[b", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
      { "]b", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
      { "[B", "<cmd>BufferLineMovePrev<cr>", desc = "Move buffer prev" },
      { "]B", "<cmd>BufferLineMoveNext<cr>", desc = "Move buffer next" },
      { "<leader>bj", "<cmd>BufferLinePick<cr>", desc = "Pick Buffer" },
    },
    opts = {
      options = {
        close_command = function(n)
          vim.cmd("bdelete " .. n)
        end,
        right_mouse_command = function(n)
          vim.cmd("bdelete " .. n)
        end,
        diagnostics = "nvim_lsp",
        always_show_bufferline = false,
        diagnostics_indicator = function(_, _, diag)
          local ret = (diag.error and "E" .. diag.error .. " " or "")
            .. (diag.warning and "W" .. diag.warning or "")
          return vim.trim(ret)
        end,
        offsets = {
          {
            filetype = "neo-tree",
            text = "Neo-tree",
            highlight = "Directory",
            text_align = "left",
          },
        },
      },
    },
    config = function(_, opts)
      require("bufferline").setup(opts)
      vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete" }, {
        callback = function()
          vim.schedule(function()
            pcall(nvim_bufferline)
          end)
        end,
      })
    end,
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = "Neotree",
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Toggle file explorer" },
    },
    opts = {
      close_if_last_window = true,
      popup_border_style = "single",
      enable_git_status = true,
      enable_diagnostics = true,
      filesystem = {
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_hidden = false,
        },
        window = {
          width = 32,
          mappings = {
            ["<space>"] = "none",
          },
        },
      },
      default_component_configs = {
        indent = {
          indent_size = 2,
          with_markers = true,
          indent_marker = "│",
          last_indent_marker = "└",
          highlight = "NeoTreeIndentMarker",
        },
        icon = {
          folder_closed = "▸",
          folder_open = "▾",
          folder_empty = "◇",
          default = "▪",
        },
        git_status = {
          symbols = {
            added = "✚",
            modified = "●",
            deleted = "✖",
            renamed = "➜",
            untracked = "★",
            ignored = "◌",
            unstaged = "●",
            staged = "✓",
            conflict = "▲",
          },
        },
      },
      window = {
        width = 32,
        mappings = {
          ["<space>"] = "none",
        },
      },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "classic",
      delay = 300,
      win = { border = "single" },
      spec = {
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>c", group = "code" },
        { "<leader>x", group = "diagnostics" },
        { "<leader>u", group = "ui" },
        { "<leader>o", group = "opencode" },
        { "<leader>q", group = "session / quit" },
        { "<leader>s", group = "split" },
        { "<leader>t", group = "terminal" },
      },
    },
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      indent = { char = "│" },
      scope = { enabled = true, show_start = false, show_end = false },
      exclude = {
        filetypes = { "help", "alpha", "dashboard", "neo-tree", "lazy", "mason" },
      },
    },
  },
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {},
  },
  {
    "stevearc/aerial.nvim",
    cmd = "Aerial",
    keys = {
      { "<leader>co", "<cmd>AerialToggle<cr>", desc = "Outline" },
    },
    opts = {
      backends = { "lsp", "treesitter" },
      layout = { default_direction = "right", min_width = 30, max_width = 60 },
      show_guides = true,
      filter_kind = false,
    },
  },
  {
    "rcarriga/nvim-notify",
    event = "VeryLazy",
    config = function()
      local c = require("mist.theme").palette
      require("notify").setup({
        background_colour = c.surface,
        stages = "fade",
        timeout = 2200,
        render = "compact",
        max_width = 60,
      })
      vim.notify = require("notify")
    end,
  },
  {
    "goolord/alpha-nvim",
    dependencies = { "nvim-tree/nvim-web-devicons", "nvim-lua/plenary.nvim" },
    event = "VimEnter",
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      dashboard.section.header.val = {
        "  ███╗   ███╗ ██╗ ███████╗ ████████╗",
        "  ████╗ ████║ ██║ ██╔════╝ ╚══██╔══╝",
        "  ██╔████╔██║ ██║ ███████╗    ██║   ",
        "  ██║╚██╔╝██║ ██║ ╚════██║    ██║   ",
        "  ██║ ╚═╝ ██║ ██║ ███████║    ██║   ",
        "  ╚═╝     ╚═╝ ╚═╝ ╚══════╝    ╚═╝   ",
      }
      dashboard.section.header.opts.hl = "AlphaHeader"

      dashboard.section.buttons.val = {
        dashboard.button("f", "  Find file", "<cmd>Telescope find_files<cr>"),
        dashboard.button("n", "  New file", "<cmd>ene<cr>"),
        dashboard.button("r", "  Recent files", "<cmd>Telescope oldfiles<cr>"),
        dashboard.button("g", "  Live grep", "<cmd>Telescope live_grep<cr>"),
        dashboard.button("c", "  Config", "<cmd>cd ~/.config/nvim | Telescope find_files<cr>"),
        dashboard.button("q", "  Quit", "<cmd>qa<cr>"),
      }
      dashboard.section.buttons.opts.hl = "AlphaButtons"

      dashboard.section.footer.val = { "MIST // NEOVIM", "" }
      dashboard.section.footer.opts.hl = "AlphaFooter"

      alpha.setup(dashboard.opts)
    end,
  },
  {
    "RRethy/vim-illuminate",
    event = "VeryLazy",
    config = function()
      require("illuminate").configure({
        providers = { "lsp", "treesitter", "regex" },
        delay = 200,
        large_file_cutoff = 2000,
      })
    end,
  },
}
