return {
  {
    "nickjvandyke/opencode.nvim",
    version = "*",
    lazy = false,
    config = function()
      vim.g.opencode_opts = {
        server = {
          start = function()
            vim.cmd("vsplit term://opencode --port | wincmd p")
          end,
        },
      }

      local map = vim.keymap.set

      map({ "n", "x" }, "<leader>oa", function()
        require("opencode").ask("@this: ")
      end, { desc = "Ask OpenCode" })

      map({ "n", "x" }, "<leader>os", function()
        require("opencode").select()
      end, { desc = "OpenCode menu" })

      map("n", "go", function()
        return require("opencode").operator("@this")
      end, { desc = "Send range to OpenCode", expr = true })

      map("n", "goo", function()
        return require("opencode").operator("@this") .. "_"
      end, { desc = "Send line to OpenCode", expr = true })
    end,
  },
}
