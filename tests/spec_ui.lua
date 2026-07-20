-- Offline spec for the two UI pieces the other specs only touch from the
-- outside: the watches model and the sidepanel.
--
-- Watches needs a stopped session for everything except the refusal path, so
-- dap.session is swapped for a fake that logs its requests and answers them
-- from a table. That is the whole point: the request/response shapes, the
-- updated-value detection, the line -> view maps and the rendered highlights
-- are the parts that break, and none of them need an adapter.
--
-- Own nvim (tests/run.sh runs each spec separately): this file replaces
-- dap.session and vim.notify, and creates its own Watches instances.

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

local dap = require("dap")
local Watches = require("debugmaster.ui.Watches")
local Sidepanel = require("debugmaster.ui.Sidepanel")

-- notifications are assertions here, not noise. Real arity kept: with a
-- one-argument stub lua-ls relearns vim.notify's signature from this
-- assignment and then flags every two-argument call in the source.
local notes = {}
---@diagnostic disable-next-line: duplicate-set-field
vim.notify = function(msg, _level, _opts)
  table.insert(notes, tostring(msg))
end

---A stopped session that answers requests from `replies` and logs every call.
---@param replies table<string, fun(args: table): any, table?> command -> err, response
local function fake_session(replies, opts)
  opts = opts or {}
  local s = {
    -- not `opts.running and nil or 1`: that always yields 1
    stopped_thread_id = (not opts.running) and 1 or nil,
    current_frame = opts.no_frame and nil or { id = opts.frame_id or 7 },
    capabilities = opts.capabilities or {},
    log = {},
  }
  function s:request(command, args)
    table.insert(self.log, { command = command, args = args })
    local reply = replies[command]
    if not reply then
      return { message = "unexpected request: " .. command }, nil
    end
    return reply(args)
  end
  return s
end

local real_session = dap.session
---@param sess table?
local function with_session(sess, fn)
  ---@diagnostic disable-next-line: duplicate-set-field
  dap.session = function()
    return sess
  end
  local called, err = pcall(fn)
  dap.session = real_session
  if not called then
    error(err, 0)
  end
end

local function lines_of(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

---{ line, col, end_col, hl } for every highlight the watches namespace drew
local function marks_of(w)
  local out = {}
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(w.buf, w.ns_id, 0, -1, { details = true })) do
    table.insert(out, { m[2], m[3], m[4].end_col, m[4].hl_group })
  end
  return out
end

---highlight groups drawn on one 0-based line
local function hls_on(w, line)
  local out = {}
  for _, m in ipairs(marks_of(w)) do
    if m[1] == line then
      table.insert(out, m[4])
    end
  end
  return out
end

---show a watches buffer in the current window with the cursor on `line`
local function focus(w, line)
  vim.api.nvim_win_set_buf(0, w.buf)
  vim.api.nvim_win_set_cursor(0, { line, 0 })
end

local function evaluates(result, opts)
  opts = opts or {}
  return function()
    return nil, { result = result, type = opts.type, variablesReference = opts.ref or 0 }
  end
end

-- 1. Refusals ---------------------------------------------------------------

local w = Watches.new()
eq(lines_of(w.buf), { "No expressions.", "", "Press 'a' to add, '?' for help." },
  "a fresh watches buffer shows the placeholder")

notes = {}
with_session(nil, function()
  ok(w:add_watch_expr("x", false) == false, "add_watch_expr refuses without a session")
end)
eq(notes, { "No active debug session" }, "and says why")

notes = {}
with_session(fake_session({}, { running = true }), function()
  ok(w:add_watch_expr("x", false) == false, "add_watch_expr refuses while the session is running")
end)
eq(notes, { "Session is not stopped" }, "and says the session is not stopped")

with_session(fake_session({}), function()
  ok(w:add_watch_expr("", false) == false, "an empty expression is refused")
end)

-- 2. Evaluate + render ------------------------------------------------------

w = Watches.new()
local sess = fake_session({ evaluate = evaluates("42", { type = "integer" }) })
with_session(sess, function()
  ok(w:add_watch_expr("counter", false), "add_watch_expr accepts with a stopped session")
  w:render()
end)
eq(lines_of(w.buf), { "counter = 42" }, "the expression and its value are rendered")
eq(sess.log[1].command, "evaluate", "an evaluate request was sent")
eq(sess.log[1].args, { expression = "counter", context = "watch", frameId = 7 },
  "evaluate carries the watch context and the current frame")
eq(hls_on(w, 0), { "Function", "Number" }, "name is Function, an integer value is Number")
eq(w.expression_views_by_line[1].expression, "counter", "line 1 maps back to the expression")

-- non-modifiable so a stray keystroke cannot corrupt the view
eq(vim.api.nvim_get_option_value("modifiable", { buf = w.buf }), false, "the buffer stays unmodifiable")

-- 3. Change detection -------------------------------------------------------

w = Watches.new()
with_session(fake_session({ evaluate = evaluates("1") }), function()
  w:add_watch_expr("v", false)
  w:render()
end)
eq(hls_on(w, 0), { "Function" }, "an unchanged value has no update highlight")
with_session(fake_session({ evaluate = evaluates("2") }), function()
  w:_evaluate_expression("v", false)
  w:render()
end)
eq(lines_of(w.buf), { "v = 2" }, "the new value is rendered")
eq(hls_on(w, 0), { "Function", "DiagnosticWarn" }, "a changed value is marked as updated")
with_session(fake_session({ evaluate = evaluates("2") }), function()
  w:_evaluate_expression("v", false)
  w:render()
end)
eq(hls_on(w, 0), { "Function" }, "evaluating to the same value clears the update mark")

-- 4. Errors -----------------------------------------------------------------

w = Watches.new()
with_session(fake_session({ evaluate = evaluates("has children", { ref = 3 }) }), function()
  w:add_watch_expr("obj", true)
end)
with_session(fake_session({
  evaluate = function()
    return "no symbol \"obj\" in current context", nil
  end,
}), function()
  w:_evaluate_expression("obj", false)
  w:render()
end)
eq(lines_of(w.buf), { 'obj = no symbol "obj" in current context' }, "the error is rendered as the value")
eq(hls_on(w, 0), { "Function", "DiagnosticError" }, "an errored expression is highlighted as an error")
ok(w.watched_expressions["obj"].children == nil, "an error drops the cached children")
ok(w.watched_expressions["obj"].expanded == false, "an error collapses the expression")

-- 5. Expansion --------------------------------------------------------------

local function struct_session(opts)
  return fake_session({
    evaluate = evaluates("{...}", { ref = 100, type = "object" }),
    variables = function(args)
      if args.variablesReference == 100 then
        return nil, {
          variables = {
            { name = "a", value = "1", type = "integer", variablesReference = 0, evaluateName = "s.a" },
            { name = "b", value = "", type = "object", variablesReference = 200, evaluateName = "s.b" },
          },
        }
      end
      return nil, {
        variables = {
          { name = "deep", value = "9", type = "integer", variablesReference = 0, evaluateName = "s.b.deep" },
        },
      }
    end,
  }, opts)
end

w = Watches.new()
sess = struct_session()
with_session(sess, function()
  w:add_watch_expr("s", true) -- default_expanded
  w:render()
end)
eq(lines_of(w.buf), { "s = {...}", "\ta = 1", "\tb = ..." }, "children render indented under the expression")
eq(sess.log[2].command, "variables", "expanding sends a variables request")
eq(sess.log[2].args.variablesReference, 100, "with the reference the evaluate returned")
eq(hls_on(w, 1), { "Identifier", "Number" }, "a child name is Identifier and its integer value is Number")
eq(hls_on(w, 2), { "Identifier", "Comment" }, "a child with no value renders an expandable hint")
eq(w.variable_views_by_line[2].variable.name, "a", "line 2 maps to the first child")
eq(w.variable_views_by_line[3].parent_reference, 100, "a child knows the reference it came from")

-- expanding a child goes one level deeper
focus(w, 3) -- the "b" line
with_session(struct_session(), function()
  w:_expand_or_collapse()
  vim.wait(200, function()
    return #lines_of(w.buf) > 3
  end)
end)
eq(lines_of(w.buf), { "s = {...}", "\ta = 1", "\tb = ...", "\t\tdeep = 9" },
  "a nested child renders one indent deeper")

-- collapsing again
focus(w, 3)
with_session(struct_session(), function()
  w:_expand_or_collapse()
  vim.wait(200, function()
    return #lines_of(w.buf) == 3
  end)
end)
eq(lines_of(w.buf), { "s = {...}", "\ta = 1", "\tb = ..." }, "collapsing hides the nested children again")

-- 6. Multi-line and whitespace-heavy values ---------------------------------

w = Watches.new()
with_session(fake_session({ evaluate = evaluates("line1\n  line2\tend") }), function()
  w:add_watch_expr("multi", false)
  w:render()
end)
eq(lines_of(w.buf), { "multi = line1 line2 end" },
  "a value spanning lines is collapsed: nvim_buf_set_lines would reject it otherwise")

-- 7. Ordering ---------------------------------------------------------------

w = Watches.new()
with_session(fake_session({ evaluate = evaluates("v") }), function()
  w:add_watch_expr("first", false, true)  -- append
  w:add_watch_expr("second", false, true) -- append
  w:add_watch_expr("zeroth", false, false) -- prepend
  w:render()
end)
eq(lines_of(w.buf), { "zeroth = v", "first = v", "second = v" },
  "appended expressions keep insertion order; a prepended one goes to the top")

-- 8. Delete / edit / copy ---------------------------------------------------

focus(w, 2) -- "first"
w:_delete_expression()
eq(lines_of(w.buf), { "zeroth = v", "second = v" }, "delete removes the expression under the cursor")
ok(w.watched_expressions["first"] == nil, "and drops it from the model")

notes = {}
local child_w = Watches.new()
with_session(struct_session(), function()
  child_w:add_watch_expr("s", true)
  child_w:render()
end)
focus(child_w, 2) -- a child variable, not an expression
child_w:_delete_expression()
eq(notes, { "No expression under cursor" }, "deleting a variable line says so")
eq(#lines_of(child_w.buf), 3, "and changes nothing")

notes = {}
focus(w, 1)
w:_copy_expression()
eq(vim.fn.getreg("+"), "zeroth", "copy puts the expression in the clipboard register")
eq(notes, { "Expression copied: zeroth" }, "and reports it")

w = Watches.new()
with_session(struct_session(), function()
  w:add_watch_expr("s", true)
  w:render()
end)
notes = {}
focus(w, 2) -- the child "a"
w:_copy_expression()
eq(vim.fn.getreg("+"), "s.a", "on a variable line, copy takes evaluateName")
eq(notes, { "Variable copied: s.a" }, "and says it copied a variable")

-- a variable the adapter gave no evaluateName for cannot be copied
w.variable_views_by_line[2].variable.evaluateName = nil
notes = {}
w:_copy_expression()
eq(notes, { "Missing evaluateName, can't copy variable" }, "no evaluateName is reported, not crashed")

-- edit replaces the expression, keeping its expansion state
w = Watches.new()
with_session(fake_session({ evaluate = evaluates("1") }), function()
  w:add_watch_expr("old", false)
  w:render()
end)
focus(w, 1)
---@diagnostic disable-next-line: duplicate-set-field
vim.ui.input = function(opts, on_confirm)
  eq(opts.default, "old", "edit prefills the current expression")
  on_confirm("new")
end
with_session(fake_session({ evaluate = evaluates("2") }), function()
  w:_edit_expression()
  vim.wait(200, function()
    return lines_of(w.buf)[1] ~= "old = 1"
  end)
end)
eq(lines_of(w.buf), { "new = 2" }, "edit swaps the expression in place")
ok(w.watched_expressions["old"] == nil, "the old expression is gone from the model")

-- 9. Setting values ---------------------------------------------------------

w = Watches.new()
with_session(fake_session({ evaluate = evaluates("1") }), function()
  w:add_watch_expr("target", false)
  w:render()
end)
focus(w, 1)
---@diagnostic disable-next-line: duplicate-set-field
vim.ui.input = function(opts, on_confirm)
  eq(opts.default, "1", "set value prefills the current result")
  on_confirm("99")
end
notes = {}
with_session(fake_session({}), function()
  w:_set_value()
  vim.wait(100)
end)
eq(notes, { "Adapter doesn't support setExpression" }, "an adapter without setExpression is refused")

sess = fake_session({
  setExpression = function()
    return nil, {}
  end,
  evaluate = evaluates("99"),
}, { capabilities = { supportsSetExpression = true } })
with_session(sess, function()
  w:_set_value()
  vim.wait(200, function()
    return lines_of(w.buf)[1] == "target = 99"
  end)
end)
eq(sess.log[1].command, "setExpression", "a capable adapter gets setExpression")
eq(sess.log[1].args, { expression = "target", value = "99", frameId = 7 },
  "with the expression, the new value and the frame")
eq(lines_of(w.buf), { "target = 99" }, "and the view refreshes afterwards")

-- on a variable line it is setVariable, addressed by parent reference
w = Watches.new()
with_session(struct_session(), function()
  w:add_watch_expr("s", true)
  w:render()
end)
focus(w, 2)
---@diagnostic disable-next-line: duplicate-set-field
vim.ui.input = function(opts, on_confirm)
  eq(opts.default, "1", "set value prefills the variable's value")
  on_confirm("5")
end
sess = struct_session()
with_session(sess, function()
  w:_set_value()
  vim.wait(100)
end)
eq(sess.log[1].command, "setVariable", "a variable line uses setVariable")
eq(sess.log[1].args, { variablesReference = 100, name = "a", value = "5" },
  "addressed by the parent reference and the variable name")

-- 10. refresh + cursor expression -------------------------------------------

w = Watches.new()
sess = fake_session({ evaluate = evaluates("1") })
with_session(sess, function()
  -- append=true is the only path production takes (add_cursor_expr), and it is
  -- what keeps insertion order; omitting it prepends, so "b" would sort above "a".
  w:add_watch_expr("a", false, true)
  w:add_watch_expr("b", false, true)
end)
sess = fake_session({ evaluate = evaluates("2") })
with_session(sess, function()
  w:refresh()
  vim.wait(200, function()
    return lines_of(w.buf)[1] == "a = 2"
  end)
end)
eq(#sess.log, 2, "refresh re-evaluates every watched expression")
eq(lines_of(w.buf), { "a = 2", "b = 2" }, "and re-renders them all")

w = Watches.new()
w:refresh()
eq(lines_of(w.buf), { "No expressions.", "", "Press 'a' to add, '?' for help." },
  "refreshing with nothing watched shows the placeholder instead of requesting")

-- <cexpr> under the cursor, from an ordinary buffer
w = Watches.new()
local code = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(code, 0, -1, false, { "int v = arr[12].field;" })
vim.api.nvim_set_current_buf(code)
-- on "field": <cexpr> grows leftward, so it picks up the whole `arr[12].field`
-- chain. Sitting on "arr" would yield just "arr" -- that is vim's behaviour, not a bug.
vim.api.nvim_win_set_cursor(0, { 1, 16 })
sess = fake_session({ evaluate = evaluates("7") })
with_session(sess, function()
  w:add_cursor_expr()
  vim.wait(200, function()
    return not vim.tbl_isempty(w.watched_expressions)
  end)
end)
eq(sess.log[1].args.expression, "arr[12].field", "add_cursor_expr takes the whole <cexpr>")

notes = {}
vim.api.nvim_buf_set_lines(code, 0, -1, false, { "   " })
vim.api.nvim_win_set_cursor(0, { 1, 1 })
with_session(fake_session({}), function()
  w:add_cursor_expr()
  vim.wait(50)
end)
eq(notes, { "No expression to add" }, "nothing under the cursor is reported, not requested")

-- an explicit expression skips the cursor entirely
sess = fake_session({ evaluate = evaluates("1") })
with_session(sess, function()
  w:add_cursor_expr("explicit_expr")
  vim.wait(200, function()
    return #sess.log > 0
  end)
end)
eq(sess.log[1].args.expression, "explicit_expr", "an explicit expression is used as given")

-- 11. Sidepanel -------------------------------------------------------------

vim.cmd("only")
local panel = Sidepanel.new()
local function component(name)
  return { name = name, buf = vim.api.nvim_create_buf(false, true) }
end
local one, two = component("[O]ne"), component("[T]wo")
panel:add_component(one)
panel:add_component(two)

ok(not panel:is_open(), "a new sidepanel is closed")
panel:set_active_with_open(one)
ok(panel:is_open(), "set_active_with_open opens it")
eq(vim.api.nvim_win_get_buf(panel.win), one.buf, "showing the active component")
ok(not panel:is_focused(), "and does not steal focus for a split")

local winbar = vim.wo[panel.win].winbar
ok(winbar:find("[O]ne", 1, true) and winbar:find("[T]wo", 1, true), "the winbar lists every component")
ok(winbar:find("%#Exception#", 1, true), "the active component is highlighted in the winbar")

panel:set_active(two)
eq(vim.api.nvim_win_get_buf(panel.win), two.buf, "set_active swaps the visible buffer")

panel:toggle()
ok(not panel:is_open(), "toggle closes an open panel")
panel:toggle()
ok(panel:is_open(), "and opens it again")
eq(vim.api.nvim_win_get_buf(panel.win), two.buf, "reopening keeps the active component")

-- rotation goes clockwise and survives a full circle
eq(panel.direction, "right", "the default direction is right")
for _, want in ipairs({ "below", "left", "above", "right" }) do
  panel:rotate(1)
  eq(panel.direction, want, "rotate(1) moves to " .. want)
  ok(panel:is_open(), "the panel stays open across rotate(" .. want .. ")")
end
panel:rotate(-1)
eq(panel.direction, "above", "rotate(-1) goes back anticlockwise")
panel:rotate(1)

-- resize clamps instead of collapsing the window
panel.size = 50
panel:resize(30)
eq(panel.size, 80, "resize adds its step")
panel:resize(30)
eq(panel.size, 90, "and clamps at 90")
panel:resize(-100)
eq(panel.size, 10, "and at 10")
panel.size = 50
panel:resize(0)

-- float layout
panel:toggle_layout()
ok(panel.float, "toggle_layout switches to a float")
ok(vim.api.nvim_win_get_config(panel.win).relative ~= "", "and the window really is floating")
panel:toggle_layout()
ok(not panel.float, "toggling again returns to a split")
eq(vim.api.nvim_win_get_config(panel.win).relative, "", "which is not floating")

-- rotate and resize are no-ops while floating
panel:toggle_layout()
local before = panel.direction
panel:rotate(1)
eq(panel.direction, before, "rotate does nothing to a float")
panel.size = 50
panel:resize(20)
eq(panel.size, 50, "resize does nothing to a float")
panel:toggle_layout()

-- a component that swaps its buffer is picked up through the User autocmd
local fresh = vim.api.nvim_create_buf(false, true)
two.buf = fresh
vim.api.nvim_exec_autocmds("User", { pattern = "WidgetBufferNumberChanged" })
vim.wait(200, function()
  return vim.api.nvim_win_get_buf(panel.win) == fresh
end)
eq(vim.api.nvim_win_get_buf(panel.win), fresh, "the panel follows a component's new buffer")

panel:close()
ok(not panel:is_open(), "close closes it")
panel:close()
ok(not panel:is_open(), "closing an already closed panel is harmless")
panel:set_active(one)
ok(not panel:is_open(), "set_active on a closed panel does not open it")

io.write(("passed: %d, failed: %d\n"):format(passed, #failed))
if #failed > 0 then
  os.exit(1)
end
os.exit(0)
