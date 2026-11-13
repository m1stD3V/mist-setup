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

require("mason").setup({ ui = { border = "single" } })
require("mason-lspconfig").setup({ ensure_installed = servers })
require("mason-tool-installer").setup({
  ensure_installed = tools,
  auto_update = false,
  run_on_start = false,
})

local function finished()
  local installed = {}
  for _, server in ipairs(require("mason-lspconfig").get_installed_servers()) do
    installed[server] = true
  end
  for _, server in ipairs(servers) do
    if not installed[server] then
      return false
    end
  end

  local registry = require("mason-registry")
  for _, tool in ipairs(tools) do
    local ok, package = pcall(registry.get_package, tool)
    if not ok or not package:is_installed() then
      return false
    end
  end
  return true
end

require("mason-tool-installer").check_install(false, true)
local ok = vim.wait(540000, finished, 1000)
print(ok and "MASON_OK" or "MASON_TIMEOUT")
