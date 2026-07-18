---@class dm.Cfg
local cfg = {
  -- Debug mode keymap scheme: "default" (stock maps) or "gdb" (full modal
  -- gdb layer, doc/keymaps-gdb-modal.md). Read once, at the first debug
  -- mode enable (or first keys.get/add call) — set it before that.
  ---@type "default"|"gdb"
  keymaps = "default",
  widgets = {
    -- Use snacks.nvim to render DAP widgets with borders and styling.
    use_snacks = true,
    snacks = {
      win = {
        position = "float",
        border = "rounded",
        backdrop = false,
        width = 0.5,
        height = 0.4,
        minimal = true,
        enter = true,
        wo = {
          wrap = false,
          number = false,
          relativenumber = false,
          signcolumn = "no",
        },
      },
    },
  },
}

return cfg
