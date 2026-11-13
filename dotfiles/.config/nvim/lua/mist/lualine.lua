local c = require("mist.theme").palette

return {
  normal = {
    a = { fg = c.bg, bg = c.accent2, gui = "bold" },
    b = { fg = c.fg, bg = c.surface },
    c = { fg = c.muted, bg = "NONE" },
  },
  insert = {
    a = { fg = c.bg, bg = c.accent, gui = "bold" },
    b = { fg = c.fg, bg = c.surface },
    c = { fg = c.muted, bg = "NONE" },
  },
  visual = {
    a = { fg = c.bg, bg = c.magenta, gui = "bold" },
    b = { fg = c.fg, bg = c.surface },
    c = { fg = c.muted, bg = "NONE" },
  },
  replace = {
    a = { fg = c.bg, bg = c.red, gui = "bold" },
    b = { fg = c.fg, bg = c.surface },
    c = { fg = c.muted, bg = "NONE" },
  },
  command = {
    a = { fg = c.bg, bg = c.yellow, gui = "bold" },
    b = { fg = c.fg, bg = c.surface },
    c = { fg = c.muted, bg = "NONE" },
  },
  inactive = {
    a = { fg = c.muted, bg = c.surface },
    b = { fg = c.muted, bg = c.surface },
    c = { fg = c.muted, bg = "NONE" },
  },
}
