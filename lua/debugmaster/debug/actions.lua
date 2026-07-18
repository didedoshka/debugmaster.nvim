local utils = require("debugmaster.utils")
local api = vim.api

---Shared action callbacks for the keymap schemes (debug/schemes/*).
---Behavior lives here exactly once; schemes are thin key -> action tables.
---@class dm.debug.actions
local A = {}

-- Execution

function A.continue() require("dap").continue() end

function A.step_over() require("dap").step_over() end

function A.step_into() require("dap").step_into() end

function A.step_out() require("dap").step_out() end

function A.run_to_cursor() require("dap").run_to_cursor() end

function A.reverse_continue() require("dap").reverse_continue() end

function A.step_back() require("dap").step_back() end

function A.frame_up() require("dap").up() end

function A.frame_down() require("dap").down() end

function A.focus_frame() require("dap").focus_frame() end

function A.restart()
  require("debugmaster.plugins").plugins.last_config_rerunner.run_last_cached()
end

function A.new_session()
  vim.cmd("DapNew")
end

function A.quit()
  require("dap").terminate()
  local state = require("debugmaster.state")
  state.sidepanel:close()
end

function A.exit_mode()
  require("debugmaster.debug.mode").disable()
end

-- <CR> repeat slot (gdb scheme). Only execution commands enter it, so only
-- they are wrapped with A.repeatable in the scheme.
local last_exec = nil

---Wrap an action so invoking it makes it the repeat_last target
---@param fn fun()
---@return fun()
function A.repeatable(fn)
  return function()
    last_exec = fn
    fn()
  end
end

function A.repeat_last()
  if last_exec then
    last_exec()
  else
    print("Nothing to repeat yet")
  end
end

-- Breakpoints

function A.toggle_breakpoint() require("dap").toggle_breakpoint() end

function A.clear_breakpoints()
  require("dap").clear_breakpoints()
  print("All breakpoints removed")
end

function A.conditional_breakpoint()
  local condition = vim.fn.input({ prompt = "Enter breakpoint condition: " })
  if condition ~= "" then
    require("dap").toggle_breakpoint(condition)
  end
end

---gdb-style contextual delete: remove the breakpoint on the cursor line if
---there is one, otherwise offer to delete all breakpoints
function A.contextual_delete()
  local buf = api.nvim_get_current_buf()
  local line = api.nvim_win_get_cursor(0)[1]
  for _, bp in ipairs(require("dap.breakpoints").get(buf)[buf] or {}) do
    if bp.line == line then
      require("dap").toggle_breakpoint()
      return
    end
  end
  if vim.fn.confirm("Delete all breakpoints?", "&Yes\n&No", 2) == 1 then
    A.clear_breakpoints()
  end
end

function A.prev_breakpoint() utils.gotoBreakpoint("prev") end

function A.next_breakpoint() utils.gotoBreakpoint("next") end

-- Sidepanel

function A.toggle_sidepanel()
  require("debugmaster.state").sidepanel:toggle()
end

function A.toggle_layout()
  require("debugmaster.state").sidepanel:toggle_layout()
end

local function open_component(name)
  local state = require("debugmaster.state")
  state.sidepanel:set_active_with_open(state[name])
end

function A.open_scopes() open_component("scopes") end

function A.open_terminal() open_component("terminal") end

function A.open_repl() open_component("repl") end

function A.open_help() open_component("help") end

function A.open_watches() open_component("watches") end

function A.rotate_cw() require("debugmaster.state").sidepanel:rotate(1) end

function A.rotate_ccw() require("debugmaster.state").sidepanel:rotate(-1) end

function A.resize_inc() require("debugmaster.state").sidepanel:resize(10) end

function A.resize_dec() require("debugmaster.state").sidepanel:resize(-10) end

-- Float widgets & inspection

function A.frames_widget()
  local widgets = require("dap.ui.widgets")
  pcall(utils.open_dap_widget, widgets.frames, { title = "Frames" })
  utils.register_to_close_on_leave(api.nvim_get_current_win())
end

function A.threads_widget()
  local widgets = require("dap.ui.widgets")
  pcall(utils.open_dap_widget, widgets.threads, { title = "Threads" })
  utils.register_to_close_on_leave(api.nvim_get_current_win())
end

function A.sessions_widget()
  local widgets = require("dap.ui.widgets")
  local ok, sessions = pcall(utils.open_dap_widget, widgets.sessions, { title = "Sessions" })
  if not ok then
    return
  end
  utils.register_to_close_on_leave(api.nvim_get_current_win())
  vim.keymap.set("n", "<CR>", vim.schedule_wrap(function()
    require('dap.ui').trigger_actions({ mode = 'first' })
    api.nvim_exec_autocmds("User", { pattern = "DapSessionChanged" })
    require("dap").focus_frame()
  end), { expr = true, buffer = sessions.buf })
end

function A.breakpoints_widget()
  local state = require("debugmaster.state")
  utils.open_floating_window(state.breakpoints.buf, {
    min_width = 60,
    additional_height = 3,
  })
  utils.register_to_close_on_leave(api.nvim_get_current_win())
  vim.bo[state.breakpoints.buf].filetype = "dap-float"
end

function A.inspect()
  pcall(require('dap.ui.widgets').hover)
  utils.register_to_close_on_leave(api.nvim_get_current_win())
end

function A.add_to_watches()
  local state = require("debugmaster.state")
  local mode = vim.fn.mode()
  local expr
  if mode == 'v' or mode == 'V' then
    vim.cmd('normal! "vy')
    expr = vim.fn.getreg('v')
  end
  state.watches:add_cursor_expr(expr)
  state.sidepanel:set_active_with_open(state.watches)
end

function A.exec_yanked()
  local state = require("debugmaster.state")
  local text = vim.fn.getreg('"')
  require("dap").repl.execute("\n" .. text)
  state.sidepanel:set_active_with_open(state.repl)
  api.nvim_buf_call(state.repl.buf, function()
    vim.cmd("normal G")
  end)
end

function A.move_terminal()
  local state = require("debugmaster.state")
  local terminal = state.terminal
  local buf = api.nvim_get_current_buf()
  local is_term = api.nvim_get_option_value('buftype', { buf = buf }) == 'terminal'
  if not is_term then
    return print("Current buffer isn't terminal. Can't move to the Terminal section")
  end
  local ok = terminal:attach_terminal_to_current_session(buf)
  if ok then
    for _, win in ipairs(utils.get_windows_for_buffer(buf)) do
      api.nvim_win_close(win, true)
    end
    state.sidepanel:open()
    state.sidepanel:set_active(terminal)
  end
end

return A
