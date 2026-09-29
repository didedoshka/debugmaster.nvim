local utils = require("debugmaster.utils")
local api = vim.api

-- the Vim error alone (E1513 for 'winfixbuf', ...), not the Lua traceback around it
local function vim_error(err)
  return tostring(err):match("E%d+: [^\n]*") or err
end

---@class dm.ui.Sidepanel.IComponent
---@field name string
---@field buf number

-- The panel is a buffer, oil-style: it opens in the current window, and
-- nothing ever closes it -- it stays until you open something else there.
---@class dm.ui.Sidepanel
local Sidepanel = {}


function Sidepanel.new()
  ---@class dm.ui.Sidepanel
  local self = setmetatable({}, { __index = Sidepanel })
  self.win = -1 -- the window the panel was last shown in; check is_open before using it
  self.shown_buf = -1 -- the buffer the panel last put in self.win

  ---@type dm.ui.Sidepanel.IComponent[]
  self.components = {}
  ---@type dm.ui.Sidepanel.IComponent
  self.active = nil

  api.nvim_create_autocmd("User", {
    pattern = "WidgetBufferNumberChanged",
    callback = vim.schedule_wrap(function()
      if self.active and self:is_open() then
        self:_show(self.active.buf)
      end
    end)
  })

  -- winbar indents are computed for the window's width; recook them whenever
  -- this window's size changes
  api.nvim_create_autocmd("WinResized", {
    callback = function()
      if self:is_open() and vim.tbl_contains(vim.v.event.windows or {}, self.win) then
        self:_cook_winbar()
      end
    end
  })

  return self
end

-- the window alone is not enough: :b or <C-^> takes the panel out of a
-- window that stays valid
function Sidepanel:is_open()
  return api.nvim_win_is_valid(self.win) and api.nvim_win_get_buf(self.win) == self.shown_buf
end

function Sidepanel:is_focused()
  return api.nvim_get_current_win() == self.win
end

-- show the panel in the current window, unless it is already on screen
function Sidepanel:open()
  if self:is_open() then
    return
  end
  local win = api.nvim_get_current_win()
  -- a plain :buffer, like opening any buffer: # becomes the one you left,
  -- so <C-^> takes you back to it
  local ok, err = pcall(vim.cmd.buffer, self.active.buf)
  if not ok then
    print("Can't open the panel here.", vim_error(err))
    return
  end
  self.win = win
  self:_show(self.active.buf)
end

-- open the panel here if it is nowhere on screen, go to it if it is
function Sidepanel:open_or_focus()
  if self:is_open() then
    api.nvim_set_current_win(self.win)
  else
    self:open()
  end
end

-- keepalt/keepjumps: switching sections must not move # or the jumplist off
-- the buffer you left for the panel. The options are :setlocal, so they stay
-- with the panel buffer -- whatever you open in the window next keeps its own
---@param buf integer
function Sidepanel:_show(buf)
  api.nvim_win_call(self.win, function()
    vim.cmd("keepalt keepjumps buffer " .. buf)
  end)
  self.shown_buf = buf
  local wo = vim.wo[self.win][0]
  wo.number = false
  wo.relativenumber = false
  wo.wrap = false
  self:_cook_winbar()
end

function Sidepanel:_cook_winbar()
  local win_width = api.nvim_win_get_width(self.win)
  local join_text_width = 0
  for _, comp in ipairs(self.components) do
    join_text_width = join_text_width + #comp.name
  end
  local max_indent = math.floor((win_width - join_text_width) / #self.components)
  local indent = string.rep(" ", max_indent)

  local winbar = {}
  for i, comp in ipairs(self.components) do
    local text = comp.name
    -- Each clickable region needs a unique identifier (using index i)
    text = string.format("%%%d@v:lua.DebugmasterClickWinbar@%s%%*", i, text)

    if comp == self.active then
      -- Apply highlight after the clickable region
      text = utils.status_line_apply_hl(text, "Exception")
    end

    table.insert(winbar, text)
  end

  vim.wo[self.win][0].winbar = table.concat(winbar, indent)
end

function DebugmasterClickWinbar(index)
  -- this code is absolutely cursed, don't want to even speak about this...
  local self = require("debugmaster.state").sidepanel
  local comp = self.components[index]
  self:set_active(comp)
end

---@param comp dm.ui.Sidepanel.IComponent
function Sidepanel:set_active(comp)
  self.active = comp
  if self:is_open() then
    self:_show(self.active.buf)
  end
end

-- if this comp already active then it do nothing
-- set comp as active and open panel if it is closed
---@param comp dm.ui.Sidepanel.IComponent
function Sidepanel:set_active_with_open(comp)
  if self.active == comp and self:is_open() then
    return
  end
  self:set_active(comp)
  self:open()
end

---@param comp dm.ui.Sidepanel.IComponent
function Sidepanel:add_component(comp)
  table.insert(self.components, comp)
end

return Sidepanel
