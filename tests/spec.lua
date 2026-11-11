-- Offline spec, run by tests/run.sh via `nvim --headless --clean -l`.
-- Everything here runs end-to-end against real nvim + real nvim-dap,
-- just without a debug adapter attached.

local failed = {}
local passed = 0

local function ok(cond, msg)
  if cond then
    passed = passed + 1
  else
    table.insert(failed, msg)
    io.stderr:write("FAIL: " .. msg .. "\n")
  end
end

local function eq(got, want, msg)
  ok(vim.deep_equal(got, want), ("%s (got %s, want %s)"):format(msg, vim.inspect(got), vim.inspect(want)))
end

-- 1. Every module loads. Catches cross-module breakage at require-time
--    (lua-language-server can't; see AGENTS.md).
local root = vim.fn.getcwd()
for _, path in ipairs(vim.fn.glob(root .. "/lua/debugmaster/**/*.lua", false, true)) do
  local mod = path:match("lua/(.+)%.lua$"):gsub("/", ".")
  local loaded, err = pcall(require, mod)
  ok(loaded, "module loads: " .. mod .. (loaded and "" or (" — " .. tostring(err))))
end

-- 2. Public API surface.
local dm = require("debugmaster")
ok(type(dm.cfg) == "table", "dm.cfg is a table")
ok(type(dm.cfg.widgets) == "table", "dm.cfg.widgets exists")
ok(type(dm.mode.toggle) == "function", "dm.mode.toggle is a function")
ok(type(dm.mode.disable) == "function", "dm.mode.disable is a function")
ok(type(dm.plugins) == "table", "dm.plugins is a table")

-- 3. Keymap registry.
local c = dm.keys.get("c")
ok(c and c.key == "c" and type(c.action) == "function", 'keys.get("c") returns a real spec')
ok(not pcall(dm.keys.get, "definitely-not-a-key"), "keys.get on unknown key errors")
dm.keys.add({ key = "Z", action = function() end, desc = "spec dummy" })
ok(dm.keys.get("Z").desc == "spec dummy", "keys.add makes the key retrievable")

-- 4. Debug mode end-to-end: real keymap save/override/restore.
vim.keymap.set("n", "o", "k", { desc = "orig-o" })
-- an expr mapping among the originals: restored without expr it still runs but
-- its return value is dropped, so the key silently stops doing anything
vim.keymap.set("n", "t", function() return "l" end, { expr = true, desc = "orig-t" })

-- Every normal-mode mapping, with the flags that decide how it behaves. The
-- invariant is that disable() puts this back exactly: keys the user never
-- mapped must be *removed*, not left mapped to themselves (a leftover
-- multi-key mapping makes its first key wait out timeoutlen).
local function keymap_snapshot()
  local out = {}
  for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
    out[m.lhs] = ("%s|%s|%s|e%s|s%s|n%s|r%s"):format(
      m.rhs or "", tostring(m.desc), m.callback and "fn" or "-",
      m.expr, m.silent, m.nowait, m.noremap)
  end
  return out
end
local maps_before = keymap_snapshot()
local mode = require("debugmaster.debug.mode")
local events = 0
vim.api.nvim_create_autocmd("User", {
  pattern = "DebugModeChanged",
  callback = function() events = events + 1 end,
})

dm.mode.toggle() -- full entry path: plugins.init + state + mode.enable
ok(mode.is_active(), "toggle() activates debug mode")
ok(vim.fn.maparg("o", "n", false, true).callback ~= nil, "debug mode overrides 'o' with a callback")

-- A real keypress drives a real dap action: 't' toggles a breakpoint.
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line1", "line2", "line3" })
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_feedkeys("t", "x", false)
local bps = require("dap.breakpoints").get()
ok(next(bps) ~= nil, "'t' keypress sets a real dap breakpoint")

-- gotoBreakpoint navigates between real breakpoints.
vim.api.nvim_win_set_cursor(0, { 3, 0 })
vim.api.nvim_feedkeys("t", "x", false) -- second breakpoint at line 3
vim.api.nvim_win_set_cursor(0, { 1, 0 })
require("debugmaster.utils").gotoBreakpoint("next")
eq(vim.api.nvim_win_get_cursor(0)[1], 3, "gotoBreakpoint('next') jumps 1 -> 3")
require("debugmaster.utils").gotoBreakpoint("next")
eq(vim.api.nvim_win_get_cursor(0)[1], 1, "gotoBreakpoint('next') wraps 3 -> 1")
require("dap").clear_breakpoints()

dm.mode.toggle() -- disable
ok(not mode.is_active(), "second toggle() deactivates debug mode")
local restored = vim.fn.maparg("o", "n", false, true)
ok(restored.rhs == "k" and restored.desc == "orig-o", "'o' restored to the original mapping")

-- Survives re-setup: enable/disable again, restore still intact.
dm.mode.toggle()
dm.mode.toggle()
restored = vim.fn.maparg("o", "n", false, true)
ok(restored.rhs == "k" and restored.desc == "orig-o", "'o' still original after second enable/disable cycle")

local maps_after = keymap_snapshot()
local diffs = {}
for lhs, sig in pairs(maps_before) do
  if maps_after[lhs] ~= sig then
    table.insert(diffs, ("%s: %s -> %s"):format(lhs, sig, tostring(maps_after[lhs])))
  end
end
for lhs in pairs(maps_after) do
  if maps_before[lhs] == nil then
    table.insert(diffs, ("%s: leftover (%s)"):format(lhs, maps_after[lhs]))
  end
end
table.sort(diffs)
ok(#diffs == 0, "every normal-mode mapping is byte-identical after enable/disable: "
  .. table.concat(diffs, "; "))
eq(events, 4, "DebugModeChanged fired once per enable/disable")

-- 5. State graph: sidepanel and every component exist with real buffers.
local state = require("debugmaster.state")
for _, name in ipairs({ "scopes", "watches", "repl", "terminal", "help", "breakpoints" }) do
  ok(state[name] ~= nil, "state." .. name .. " exists")
end
ok(state.sidepanel ~= nil, "state.sidepanel exists")

-- 6. Watches without a session: politely refuses instead of erroring.
ok(state.watches:add_watch_expr("some_var", false) == false, "add_watch_expr returns false with no session")

-- 7. Pure(ish) utils with real assertions.
local utils = require("debugmaster.utils")
eq(utils.status_line_apply_hl("txt", "Hl"), "%#Hl#txt%*", "status_line_apply_hl formats correctly")

-- open_floating_window: snacks is absent under --clean, so this exercises the
-- native-float fallback even though cfg.use_snacks defaults to true.
local fbuf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(fbuf, 0, -1, false, { "hello floating world" })
local fwin = utils.open_floating_window(fbuf, { min_width = 30 })
-- nvim reports cursor-relative floats back as win-relative; assert "is a float of the right size"
local wincfg = vim.api.nvim_win_get_config(fwin)
ok(wincfg.relative ~= "" and wincfg.width >= 30, "open_floating_window opens a float (snacks fallback)")
vim.api.nvim_win_close(fwin, true)

local count = 0
local bumped = utils.debounce(function() count = count + 1 end, 20)
bumped(); bumped(); bumped()
vim.wait(500, function() return count > 0 end)
eq(count, 1, "debounce collapses a burst into one call")

-- Setting cfg.keymaps after the scheme is fixed reads as config that took
-- effect and didn't -- the bug this guard exists for. Last, it poisons cfg.
local dmcfg = require("debugmaster.cfg")
dmcfg.keymaps = "gdb"
local changed, err = pcall(require("debugmaster.debug.keymaps").get, "o")
ok(not changed, "changing cfg.keymaps after resolution throws")
ok(tostring(err):match("already resolved"), "the error says the scheme was already resolved")
dmcfg.keymaps = "default"
ok(pcall(require("debugmaster.debug.keymaps").get, "o"), "setting it back is fine")

-- Verdict.
io.write(("passed: %d, failed: %d\n"):format(passed, #failed))
if #failed > 0 then
  os.exit(1)
end
os.exit(0)
