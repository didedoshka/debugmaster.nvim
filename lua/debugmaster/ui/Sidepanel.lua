local utils = require("debugmaster.utils")
local api = vim.api

-- the Vim error alone (E1513 for 'winfixbuf', ...), not the Lua traceback around it
local function vim_error(err)
  return tostring(err):match("E%d+: [^\n]*") or err
end

---@class dm.ui.Sidepanel.IComponent
---@field name string
---@field buf number

---@class dm.ui.Sidepanel
local Sidepanel = {}


function Sidepanel.new()
  ---@class dm.ui.Sidepanel
  local self = setmetatable({}, { __index = Sidepanel })
  self.win = -1 -- always need to check if valid before doing something
  self.shown_buf = -1 -- the buffer the panel last put in self.win
  self.direction = "right"
  self.float = false
  -- open in the current window, oil-style, instead of a split: closing gives
  -- the window its buffer back, so the layout never changes. float still floats
  self.inplace = false
  -- while open in place: the window's own buffer and view, to give back
  ---@type { buf: integer, view: vim.fn.winsaveview.ret }?
  self.borrowed = nil
  self.size = 50 -- size for the split. not applied to float. always in the range [10;90]

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

  api.nvim_create_autocmd("VimResized", {
    callback = function()
      -- an in-place panel is sized by the user's layout, not by us
      if self:is_open() and not self.borrowed then
        self:close()
        self:open()
      end
    end
  })

  -- winbar indents are computed for the width at open time; recook them when
  -- this window's size changes (splits, <C-w> resizes -- not just VimResized)
  api.nvim_create_autocmd("WinResized", {
    callback = function()
      if self:is_open() and vim.tbl_contains(vim.v.event.windows or {}, self.win) then
        self:_cook_winbar()
      end
    end
  })

  return self
end

-- the window alone is not enough: in place, :bnext or <C-^> takes the panel
-- out of a window that stays valid
function Sidepanel:is_open()
  return api.nvim_win_is_valid(self.win) and api.nvim_win_get_buf(self.win) == self.shown_buf
end

function Sidepanel:is_focused()
  return api.nvim_get_current_win() == self.win
end

function Sidepanel:toggle()
  if not self:is_open() then
    self:open()
  else
    self:close()
  end
end

---@class dm.ui.Sidepanel.OpenOptions
---@field direction "left" | "right" | "above" | "below" | nil Opens in previous state if nil (right when open first time)
---@field float boolean? If float specified then it creates float window and ignore direction

---@param opts dm.ui.Sidepanel.OpenOptions?
function Sidepanel:open(opts)
  if self:is_open() then
    return
  end

  -- preparing new options (float, direction)
  opts = opts or {}
  local float = self.float
  if opts.float ~= nil then
    float = opts.float
  end
  local direction = opts.direction or self.direction

  local win, borrowed
  if self.inplace and not float then
    win = api.nvim_get_current_win()
    borrowed = { buf = api.nvim_win_get_buf(win), view = vim.fn.winsaveview() }
  else
    ---@type vim.api.keyset.win_config
    local cfg = {}
    local enter = false

    if float then
      cfg = utils.make_center_float_win_cfg()
      enter = true
    else
      cfg.split = direction
      cfg.win = -1
      cfg.width = math.floor(vim.o.columns  * (self.size / 100))
      cfg.height = math.floor(vim.o.lines  * (self.size / 100))
    end

    --  it saves us if we try open it in a float window
    local ok, res = pcall(api.nvim_open_win, self.active.buf, enter, cfg)
    if not ok then
      print("Can't open window.", res)
      return
    end
    win = res
  end

  -- in place, this is the buffer switch, refused by 'winfixbuf' for one
  self.win = win
  local ok, err = pcall(self._show, self, self.active.buf)
  if not ok then
    print("Can't open the panel here.", vim_error(err))
    return
  end

  -- Applying new options (if pcall successfull)
  self.borrowed = borrowed
  self.direction = direction
  self.float = float
  if self.float then
    utils.register_to_close_on_leave(self.win)
  end
end

-- keepalt/keepjumps: the panel's buffers must not become the user's # or
-- land in the jumplist. The options are :setlocal, so they stay with the
-- panel buffer -- whatever enters the window next keeps its own
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

function Sidepanel:close()
  if not self:is_open() then
    return
  end
  local borrowed = self.borrowed
  if not borrowed then
    -- may fail if trying to close last window
    pcall(api.nvim_win_close, self.win, true)
    return
  end
  local ok, err = pcall(api.nvim_win_call, self.win, function()
    if api.nvim_buf_is_valid(borrowed.buf) then
      vim.cmd("keepalt keepjumps buffer " .. borrowed.buf)
      vim.fn.winrestview(borrowed.view)
    else
      -- not :enew, which reuses the current buffer when it is an empty panel one
      vim.cmd("keepalt keepjumps buffer " .. api.nvim_create_buf(true, false))
    end
  end)
  if not ok then
    print("Can't give the window its buffer back.", vim_error(err))
  end
end

---rotate sidebar clockwise
---@param step number
function Sidepanel:rotate(step)
  if not self:is_open() or self.float or self.borrowed then
    return
  end
  local was_focused = self:is_focused()
  local cur_direction = self.direction
  self:close()
  local directions = { "below", "left", "above", "right" }
  for i, direction in ipairs(directions) do
    if direction == cur_direction then
      -- let's pretend array starts with zero (hence i - 1)
      local index = ((i - 1) + step) % #directions
      local next = directions[index + 1]
      self:open({ direction = next })
    end
  end
  if was_focused then
    api.nvim_set_current_win(self.win)
  end
end

function math.clamp(n, low, high)
  return math.min(math.max(n, low), high)
end

function Sidepanel:resize(step)
  if self.float or self.borrowed or not self:is_open() then
    return
  end
  self.size = math.clamp(self.size + step, 10, 90)
  self:close()
  self:open()
end

function Sidepanel:toggle_layout()
  if not self:is_open() then
    self:open()
  end
  self:close()
  self:open({ float = not self.float })
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
