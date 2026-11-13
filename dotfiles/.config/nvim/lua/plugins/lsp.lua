local servers = {
  "bashls",
  "clangd",
  "cssls",
  "html",
  "jsonls",
  "lua_ls",
  "marksman",
  "pyright",
  "rust_analyzer",
  "ts_ls",
  "yamlls",
}

local tools = {
  "black",
  "eslint_d",
  "isort",
  "prettier",
  "ruff",
  "shellcheck",
  "shfmt",
  "stylua",
}

return {
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    opts = {
      ui = { border = "single" },
    },
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    opts = {
      ensure_installed = servers,
    },
  },
  {
    "ray-x/lsp_signature.nvim",
    event = "InsertEnter",
    opts = {
      bind = true,
      handler_opts = { border = "single" },
      floating_window = true,
      floating_window_above_cur_line = true,
      hint_enable = true,
      hint_prefix = "› ",
      hint_scheme = "String",
      hint_inline = function()
        return true
      end,
      max_height = 12,
      max_width = 100,
      wrap = true,
      toggle_key = "<C-k>",
      select_signature_key = "<C-j>",
      hi_parameter = "LspSignatureActiveParameter",
      timer_interval = 200,
    },
    config = function(_, opts)
      require("lsp_signature").setup(opts)
    end,
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local function on_attach(client, bufnr)
        local map = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end

        map("n", "gd", vim.lsp.buf.definition, "Definition")
        map("n", "gD", vim.lsp.buf.declaration, "Declaration")
        map("n", "gr", "<cmd>Telescope lsp_references<cr>", "References")
        map("n", "gi", "<cmd>Telescope lsp_implementations<cr>", "Implementations")
        map("n", "gy", "<cmd>Telescope lsp_type_definitions<cr>", "Type definitions")
        map("n", "K", vim.lsp.buf.hover, "Hover")
        map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
        map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
        map("n", "<leader>ds", "<cmd>Telescope lsp_document_symbols<cr>", "Document symbols")
        map("n", "<leader>ws", "<cmd>Telescope lsp_workspace_symbols<cr>", "Workspace symbols")

        if client and client.server_capabilities and client.server_capabilities.inlayHintProvider then
          vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
        end

        local group = vim.api.nvim_create_augroup("MistLspHighlight_" .. bufnr, { clear = true })
        if vim.lsp.buf.document_highlight then
          vim.api.nvim_create_autocmd("CursorHold", {
            group = group,
            buffer = bufnr,
            callback = vim.lsp.buf.document_highlight,
          })
          vim.api.nvim_create_autocmd("CursorMoved", {
            group = group,
            buffer = bufnr,
            callback = vim.lsp.buf.clear_references,
          })
        end
      end

      vim.diagnostic.config({
        virtual_text = {
          spacing = 4,
          prefix = "●",
          source = "if_many",
        },
        severity_sort = true,
        float = { border = "single", source = true },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "✘",
            [vim.diagnostic.severity.WARN] = "▲",
            [vim.diagnostic.severity.INFO] = "◆",
            [vim.diagnostic.severity.HINT] = "●",
          },
        },
        underline = true,
        update_in_insert = false,
      })

      vim.lsp.config("*", {
        capabilities = capabilities,
        on_attach = on_attach,
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
            completion = { callSnippet = "Replace" },
            hint = {
              enable = true,
              paramName = "All",
              setType = true,
              arrayIndex = "Auto",
            },
          },
        },
      })

      vim.lsp.config("pyright", {
        settings = {
          python = {
            analysis = {
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              typeCheckingMode = "basic",
              inlayHints = {
                callArgumentNames = true,
                variableTypes = true,
                functionReturnTypes = true,
              },
            },
          },
        },
      })

      vim.lsp.config("ts_ls", {
        settings = {
          typescript = {
            inlayHints = {
              parameterNames = { enabled = "all" },
              variableTypes = { enabled = true },
              functionLikeReturnTypes = { enabled = true },
              propertyDeclarationTypes = { enabled = true },
              enumMemberValues = { enabled = true },
            },
          },
          javascript = {
            inlayHints = {
              parameterNames = { enabled = "all" },
              variableTypes = { enabled = true },
              functionLikeReturnTypes = { enabled = true },
              propertyDeclarationTypes = { enabled = true },
              enumMemberValues = { enabled = true },
            },
          },
        },
      })

      vim.lsp.config("rust_analyzer", {
        settings = {
          ["rust-analyzer"] = {
            cargo = { allFeatures = true },
            check = { command = "clippy" },
            inlayHints = { enable = true },
          },
        },
      })

      vim.lsp.config("yamlls", {
        settings = {
          yaml = {
            keyOrdering = false,
            schemaStore = { enable = true },
          },
        },
      })

      vim.lsp.enable(servers)
    end,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    event = "VeryLazy",
    opts = {
      ensure_installed = tools,
      auto_update = false,
      run_on_start = true,
      check_delay = 5000,
    },
  },
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          lua = { "stylua" },
          python = { "isort", "black" },
          javascript = { "prettier" },
          javascriptreact = { "prettier" },
          typescript = { "prettier" },
          typescriptreact = { "prettier" },
          css = { "prettier" },
          html = { "prettier" },
          json = { "prettier" },
          jsonc = { "prettier" },
          yaml = { "prettier" },
          markdown = { "prettier" },
          sh = { "shfmt" },
        },
        format_on_save = function()
          if not vim.g.autoformat then
            return nil
          end
          return { timeout_ms = 750, lsp_format = "fallback" }
        end,
      })
    end,
  },
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost", "InsertLeave" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        python = { "ruff" },
        sh = { "shellcheck" },
        javascript = { "eslint_d" },
        typescript = { "eslint_d" },
      }

      vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("MistLint", { clear = true }),
        callback = function()
          lint.try_lint()
        end,
      })
    end,
  },
}
