return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      local parsers = {
        "bash",
        "c",
        "cpp",
        "css",
        "diff",
        "dockerfile",
        "gitignore",
        "html",
        "javascript",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "regex",
        "rust",
        "scss",
        "toml",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "yaml",
      }

      if vim.fn.executable("tree-sitter") == 1 then
        require("nvim-treesitter").install(parsers)
      else
        vim.notify(
          "tree-sitter CLI not found; Treesitter parsers will not be installed.\n"
            .. "Install it with: sudo pacman -S tree-sitter-cli",
          vim.log.levels.WARN
        )
      end

      vim.treesitter.language.register("bash", "zsh")

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("MistTreesitter", { clear = true }),
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
          pcall(function()
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end)
        end,
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "VeryLazy",
    opts = {
      max_lines = 3,
      multiline_threshold = 20,
      mode = "cursor",
    },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "markdown.mdx" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {},
  },
}
