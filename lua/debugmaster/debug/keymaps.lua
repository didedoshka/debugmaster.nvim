local M = {}

---@class dm.KeySpec
---@field key string
---@field action fun()? nil for help-display-only entries (panel-local keys)
---@field desc string?
---@field nowait boolean?
---@field group string?
---@field nop boolean? generated layer nop; hidden from keys.get
---@field modes table | nil Table with modes like in vim.keymap.set. {"n"} by default


---@class dm.MappingsGroup
---@field name string? Group name. Not shown in HelpPopup if nil
---@field hlgroup string? Define name highlight color in HelpPopup
---@field mappings dm.KeySpec[]

---@class dm.KeymapScheme
---@field groups dm.MappingsGroup[]
---@field misc dm.MappingsGroup the group keys.add() appends to

---@type dm.KeymapScheme?
local scheme = nil

---Resolves cfg.keymaps into a scheme module. Happens once, on first use
---(first debug mode enable or first keys.get/add call); the choice is
---fixed for the rest of the session.
---@return dm.KeymapScheme
local function resolve()
  if not scheme then
    local name = require("debugmaster.cfg").keymaps
    local ok, mod = pcall(require, "debugmaster.debug.schemes." .. tostring(name))
    if not ok then
      error(('debugmaster: cfg.keymaps must be "default" or "gdb", got %s'):format(vim.inspect(name)))
    end
    scheme = mod
  end
  return scheme
end

---Mapping groups of the active scheme
---@return dm.MappingsGroup[]
function M.get_groups()
  return resolve().groups
end

---Give the reference to the key entry so you can remap it to something else
---Throws an error if the key doesn't exist
---@return dm.KeySpec
function M.get(key)
  for _, group in ipairs(M.get_groups()) do
    for _, mapping in ipairs(group.mappings) do
      if mapping.key == key and not mapping.nop then
        return mapping
      end
    end
  end
  error("Key doesn't exist")
end

--- Add new user mapping to the active scheme
---@param mapping dm.KeySpec
function M.add(mapping)
  table.insert(resolve().misc.mappings, mapping)
end

--- Map every command of the active scheme globally under `prefix`, so a single
--- debug action can be fired without entering debug mode: with prefix "<bs>",
--- `<bs>n` steps over once and leaves you in normal mode.
---
--- Reads the scheme once, so call it after every keys.add(); mappings added
--- afterwards get no one-shot. The prefix is the caller's to choose -- which
--- key is worth spending is a config decision, not a plugin one.
---@param prefix string
function M.oneshot(prefix)
  for _, group in ipairs(M.get_groups()) do
    for _, mapping in ipairs(group.mappings) do
      -- Two kinds of entry are not commands: nops exist to swallow keys
      -- inside the layer and mean nothing outside it, and entries without an
      -- action are help text for keys that are really buffer-local to a panel.
      if mapping.action and not mapping.nop then
        vim.keymap.set(mapping.modes or { "n" }, prefix .. mapping.key, mapping.action,
          { desc = mapping.desc })
      end
    end
  end
end

return M
