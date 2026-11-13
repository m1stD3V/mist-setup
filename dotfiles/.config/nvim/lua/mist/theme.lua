local M = {}

local fallback = {
  bg = "#102317",
  fg = "#d2cedf",
  cursor = "#734cf0",
  selection = "#6551a4",
  ansi = {
    [0] = "#0b0911",
    [1] = "#c95e79",
    [2] = "#5cbc96",
    [3] = "#d0a36c",
    [4] = "#8269d3",
    [5] = "#b671d6",
    [6] = "#72b0c0",
    [7] = "#d2cedf",
    [8] = "#564d75",
    [9] = "#dd889e",
    [10] = "#85d1b2",
    [11] = "#e1c098",
    [12] = "#aa98e1",
    [13] = "#cfa0e3",
    [14] = "#9acad6",
    [15] = "#f7f6f8",
  },
}

local function parse_hex(hex)
  if type(hex) ~= "string" then
    return nil
  end
  hex = hex:gsub("#", "")
  if #hex ~= 6 then
    return nil
  end
  return {
    tonumber(hex:sub(1, 2), 16),
    tonumber(hex:sub(3, 4), 16),
    tonumber(hex:sub(5, 6), 16),
  }
end

local function to_hex(rgb)
  return string.format("#%02x%02x%02x", rgb[1], rgb[2], rgb[3])
end

local function mix(fg, bg, amount)
  local f = parse_hex(fg) or parse_hex(fallback.fg)
  local b = parse_hex(bg) or parse_hex(fallback.bg)
  return to_hex({
    math.floor(f[1] * amount + b[1] * (1 - amount) + 0.5),
    math.floor(f[2] * amount + b[2] * (1 - amount) + 0.5),
    math.floor(f[3] * amount + b[3] * (1 - amount) + 0.5),
  })
end

local function read()
  local raw = vim.deepcopy(fallback)
  local ok, lines = pcall(vim.fn.readfile, vim.fn.expand("~/.config/ghostty/theme"))
  if ok then
    for _, line in ipairs(lines) do
      local key, value = line:match("^%s*([%w%-]+)%s*=%s*(#%x%x%x%x%x%x)")
      if key == "background" then
        raw.bg = value
      elseif key == "foreground" then
        raw.fg = value
      elseif key == "cursor-color" then
        raw.cursor = value
      elseif key == "selection-background" then
        raw.selection = value
      end

      local index, color = line:match("^%s*palette%s*=%s*(%d+)%s*=%s*(#%x%x%x%x%x%x)")
      if index then
        raw.ansi[tonumber(index)] = color
      end
    end
  end

  local p = raw.ansi
  local c = {
    bg = raw.bg,
    fg = raw.fg,
    cursor = raw.cursor,
    selection = raw.selection,
    ansi = p,
    surface = mix(raw.fg, raw.bg, 0.06),
    surface2 = mix(raw.fg, raw.bg, 0.10),
    surface3 = mix(raw.fg, raw.bg, 0.16),
    border = mix(raw.fg, raw.bg, 0.22),
    dim = mix(raw.fg, raw.bg, 0.55),
    muted = p[8],
    accent = p[4],
    accent2 = p[12],
    ok = p[2],
    warn = p[3],
    err = p[1],
    info = p[6],
    added = p[2],
    changed = p[3],
    removed = p[1],
    black = p[0],
    red = p[1],
    green = p[2],
    yellow = p[3],
    blue = p[4],
    magenta = p[5],
    cyan = p[6],
    white = p[7],
    bright_black = p[8],
    bright_red = p[9],
    bright_green = p[10],
    bright_yellow = p[11],
    bright_blue = p[12],
    bright_magenta = p[13],
    bright_cyan = p[14],
    bright_white = p[15],
  }
  return c
end

M.palette = read()

function M.load()
  return read()
end

function M.reload()
  M.palette = read()
  vim.cmd.colorscheme("mist")
  pcall(function()
    require("lualine").refresh({ place = { "statusline" } })
  end)
end

vim.api.nvim_create_user_command("MistReload", M.reload, {})

return M
