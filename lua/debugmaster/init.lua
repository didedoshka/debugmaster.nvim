local M = {}
local keymaps = require("debugmaster.debug.keymaps")

M.cfg = require("debugmaster.cfg")

-- maybe want to lazyload it in the future. not critical right now anyway
M.plugins = require("debugmaster.plugins").plugins

-- The panel and the plugin integrations are only built once the mode is first
-- entered, so every entry point pays for them; disable cannot be reached
-- without one of them having run first.
local function entered(action)
  return function()
    require("debugmaster.plugins").init()
    require("debugmaster.state")
    require("debugmaster.debug.mode")[action]()
  end
end

M.mode = {
  toggle = entered("toggle"),
  enable = entered("enable"),
  disable = require("debugmaster.debug.mode").disable
}

M.keys = {
  get = keymaps.get,
  add = keymaps.add,
  oneshot = keymaps.oneshot
}

return M
