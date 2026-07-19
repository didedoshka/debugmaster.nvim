-- Offline spec for the gdb keymap scheme (cfg.keymaps = "gdb"), run by
-- tests/run.sh in its own nvim: scheme resolution is once-per-process,
-- so this can't share a process with spec.lua (default scheme).

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

local dm = require("debugmaster")
dm.cfg.keymaps = "gdb"

-- 1. Registry resolves the gdb scheme.
local n = dm.keys.get("n")
ok(n and type(n.action) == "function", 'keys.get("n") returns a real spec')
ok(not pcall(dm.keys.get, "o"), "stock-only key 'o' is unknown in the gdb scheme")
ok(not pcall(dm.keys.get, "j"), "nops are hidden from keys.get")
ok(pcall(dm.keys.get, "bq"), "'bq' (backtrace to quickfix) is a known command")

-- 2. Enable: gdb commands and nops are installed.
local mode = require("debugmaster.debug.mode")
dm.mode.toggle()
ok(mode.is_active(), "toggle() activates debug mode")
ok(vim.fn.maparg("n", "n", false, true).callback ~= nil, "'n' (step over) is mapped")
ok(vim.fn.maparg("j", "n", false, true).callback ~= nil, "'j' is nop-mapped")
ok(vim.fn.maparg("<C-d>", "n", false, true).callback ~= nil, "'<C-d>' is nop-mapped")
ok(vim.fn.maparg("p", "v", false, true).callback ~= nil, "visual 'p' (inspect) is mapped in the layer")
ok(vim.fn.maparg("w", "v", false, true).callback ~= nil, "visual 'w' (watch) is mapped in the layer")
ok(vim.fn.maparg("d", "v", false, true).callback ~= nil, "visual 'd' is nop-mapped (no edits in the layer)")

-- 3. Real keypresses in a real file buffer.
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line1", "line2", "line3", "line4" })
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_win_set_cursor(0, { 1, 0 })

-- 'b' toggles a breakpoint (gdb break)
vim.api.nvim_feedkeys("b", "x", false)
ok(next(require("dap.breakpoints").get()) ~= nil, "'b' keypress sets a real dap breakpoint")

-- contextual 'd' removes the breakpoint on the cursor line (no confirm path)
vim.api.nvim_feedkeys("d", "x", false)
ok(next(require("dap.breakpoints").get()) == nil, "'d' keypress deletes the breakpoint on the line")

-- motions are swallowed in a file buffer
vim.api.nvim_feedkeys("j", "x", false)
eq(vim.api.nvim_win_get_cursor(0)[1], 1, "'j' is a nop in a file buffer")
vim.api.nvim_feedkeys("v", "x", false)
eq(vim.fn.mode(), "n", "'v' is a nop: no visual mode from inside the layer")
vim.api.nvim_feedkeys(vim.keycode("<C-d>"), "x", false)
eq(vim.api.nvim_win_get_cursor(0)[1], 1, "'<C-d>' is a nop in a file buffer")

-- 4. Nop passthrough in special buffers (panels/terminal/REPL), with count.
local scratch = vim.api.nvim_create_buf(false, true) -- buftype=nofile
vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { "a", "b", "c", "d" })
vim.api.nvim_set_current_buf(scratch)
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_feedkeys("j", "x", false)
eq(vim.api.nvim_win_get_cursor(0)[1], 2, "'j' passes through in a special buffer")
vim.api.nvim_feedkeys("2j", "x", false)
eq(vim.api.nvim_win_get_cursor(0)[1], 4, "count survives the passthrough ('2j')")
vim.api.nvim_feedkeys(vim.keycode("<C-u>"), "x", false)
ok(vim.api.nvim_win_get_cursor(0)[1] < 4, "'<C-u>' passes through in a special buffer")

-- 5. Help popup: gdb groups are rendered, nops are not.
local state = require("debugmaster.state")
local help_lines = vim.api.nvim_buf_get_lines(state.help.buf, 0, -1, false)
local has_execution, has_nop_line = false, false
for _, line in ipairs(help_lines) do
  if line == "EXECUTION" then has_execution = true end
  if line:match("^j%s") or line:match("^k%s") then has_nop_line = true end
end
ok(has_execution, "help shows the EXECUTION group")
ok(not has_nop_line, "help doesn't list nop keys")

-- 6. Disable: everything restored, across repeated cycles.
vim.api.nvim_set_current_buf(buf)
dm.mode.toggle()
ok(not mode.is_active(), "second toggle() deactivates debug mode")
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_feedkeys("j", "x", false)
eq(vim.api.nvim_win_get_cursor(0)[1], 2, "'j' moves again after disable")
ok(vim.fn.maparg("n", "n", false, true).callback == nil, "'n' has no plugin callback after disable")

dm.mode.toggle()
dm.mode.toggle()
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_feedkeys("j", "x", false)
eq(vim.api.nvim_win_get_cursor(0)[1], 2, "'j' still native after second enable/disable cycle")

-- 7. One-shot maps: scheme commands under a prefix, fired without the layer.
dm.keys.add({ key = "Z", action = function() end, desc = "probe" })
dm.keys.oneshot("<bs>")
ok(vim.fn.maparg("<bs>n", "n", false, true).callback ~= nil, "one-shot maps a command key")
ok(vim.fn.maparg("<bs>Z", "n", false, true).callback ~= nil, "one-shot maps keys.add() entries")
ok(vim.fn.maparg("<bs>j", "n", false, true).callback == nil, "one-shot skips nops")
ok(vim.fn.maparg("<bs>p", "v", false, true).callback ~= nil, "one-shot honours multi-mode specs")
eq(vim.fn.maparg("<bs>n", "n", false, true).desc, "Step over (gdb next)", "one-shot carries the scheme desc")

-- The point of the whole thing: it works with debug mode off, and leaves it off.
ok(not mode.is_active(), "debug mode is off going into the one-shot test")
vim.api.nvim_win_set_cursor(0, { 3, 0 })
vim.api.nvim_feedkeys(vim.keycode("<bs>b"), "x", false)
ok(next(require("dap.breakpoints").get()) ~= nil, "'<bs>b' sets a breakpoint outside debug mode")
ok(not mode.is_active(), "a one-shot does not enter debug mode")
vim.api.nvim_feedkeys(vim.keycode("<bs>d"), "x", false)
ok(next(require("dap.breakpoints").get()) == nil, "'<bs>d' deletes it again")

-- Verdict.
print(("passed: %d, failed: %d"):format(passed, #failed))
if #failed > 0 then
  os.exit(1)
end
os.exit(0)
