-- The full modal gdb layer (cfg.keymaps = "gdb"), doc/keymaps-gdb-modal.md.
-- Lowercase talks to the debugger, uppercase manipulates panels, every other
-- printable key is a nop — navigation happens outside the layer.
local A = require("debugmaster.debug.actions")
local api = vim.api

local rep = A.repeatable

---@type dm.MappingsGroup
local execution = {
  name = "EXECUTION",
  hlgroup = "ERROR",
  mappings = {
    {
      key = "c",
      nowait = true,
      action = rep(A.continue),
      desc = "Continue or start debug session",
    },
    {
      key = "n",
      nowait = true,
      action = rep(A.step_over),
      desc = "Step over (gdb next)",
    },
    {
      key = "s",
      nowait = true,
      action = rep(A.step_into),
      desc = "Step into (gdb step)",
    },
    {
      key = "fin",
      action = rep(A.step_out),
      desc = "Step out (gdb finish)",
    },
    {
      key = "f",
      action = A.focus_frame,
      desc = "Focus current frame (gdb frame)",
    },
    {
      key = "u",
      action = rep(A.run_to_cursor),
      desc = "Run to cursor (gdb until)",
    },
    {
      key = "up",
      action = rep(A.frame_up),
      desc = "Frame up (older frame)",
    },
    {
      key = "do",
      action = rep(A.frame_down),
      desc = "Frame down (newer frame)",
    },
    {
      key = "r",
      action = A.restart,
      desc = "Restart session or rerun last (gdb run)",
    },
    {
      key = "rc",
      action = rep(A.reverse_continue),
      desc = "Reverse continue (needs record/rr adapter)",
    },
    {
      key = "rs",
      action = rep(A.step_back),
      desc = "Reverse step (DAP has no reverse step-into; same as rn)",
    },
    {
      key = "rn",
      action = rep(A.step_back),
      desc = "Reverse next (step back)",
    },
    {
      key = "<CR>",
      nowait = true,
      action = A.repeat_last,
      desc = "Repeat last execution command",
    },
  }
}

---@type dm.MappingsGroup
local breakpoints = {
  name = "BREAKPOINTS",
  hlgroup = "Boolean",
  mappings = {
    {
      key = "b",
      action = A.toggle_breakpoint,
      desc = "Toggle breakpoint (gdb break)",
    },
    {
      key = "bc",
      action = A.conditional_breakpoint,
      desc = "Conditional breakpoint",
    },
    {
      key = "d",
      action = A.contextual_delete,
      desc = "Delete breakpoint on line, else delete all (confirms)",
    },
    {
      key = "[b",
      action = A.prev_breakpoint,
      desc = "Go to previous breakpoint",
    },
    {
      key = "]b",
      action = A.next_breakpoint,
      desc = "Go to next breakpoint",
    },
  }
}

---@type dm.MappingsGroup
local inspection = {
  name = "INSPECTION",
  hlgroup = "STATEMENT",
  mappings = {
    {
      key = "p",
      nowait = true,
      modes = { "n", "v" },
      action = A.inspect,
      desc = "Print: inspect word or selection (gdb print)",
    },
    {
      key = "bt",
      action = A.frames_widget,
      desc = "Backtrace: frames widget",
    },
    {
      key = "bq",
      action = A.frames_to_qf,
      desc = "Backtrace to quickfix",
    },
    {
      key = "t",
      nowait = true,
      action = A.threads_widget,
      desc = "Threads widget",
    },
    {
      key = "w",
      nowait = true,
      modes = { "n", "v" },
      action = A.add_to_watches,
      desc = "Watch cursor word/selection, open watches panel",
    },
    {
      key = "ib",
      action = A.breakpoints_widget,
      desc = "Info breakpoints widget",
    },
    {
      key = "is",
      action = A.sessions_widget,
      desc = "Info sessions widget",
    },
    {
      key = "e",
      nowait = true,
      action = A.exec_yanked,
      desc = "Execute last yanked or deleted text in the repl",
    },
  }
}

---@type dm.MappingsGroup
local session = {
  name = "SESSION",
  hlgroup = "TYPE",
  mappings = {
    {
      key = "q",
      nowait = true,
      action = function()
        A.quit()
        A.exit_mode()
      end,
      desc = "Terminate session, exit debug mode (gdb quit)",
    },
    {
      key = "N",
      action = A.new_session,
      desc = "New debug session",
    },
  }
}

---@type dm.MappingsGroup
local ui = {
  name = "UI",
  hlgroup = "STRING",
  mappings = {
    {
      key = "U",
      action = A.toggle_sidepanel,
      desc = "Toggle sidepanel",
    },
    {
      key = "F",
      action = A.toggle_layout,
      desc = "Toggle ui float mode",
    },
    {
      key = "S",
      action = A.open_scopes,
      desc = "Open scopes (global, local, etc variables)",
    },
    {
      key = "T",
      action = A.open_terminal,
      desc = "Open terminal",
    },
    {
      key = "R",
      action = A.open_repl,
      desc = "Open repl",
    },
    {
      key = "H",
      action = A.open_help,
      desc = "Open help",
    },
    {
      key = "W",
      action = A.open_watches,
      desc = "Open watches panel",
    },
    {
      key = "M",
      action = A.move_terminal,
      desc = "Move current terminal to the 'Terminal' segment",
    },
    {
      key = ">",
      action = A.rotate_cw,
      desc = "Rotate sidepanel clockwise",
    },
    {
      key = "<",
      action = A.rotate_ccw,
      desc = "Rotate sidepanel anticlockwise",
    },
    {
      key = "-",
      action = A.resize_dec,
      desc = "Decrease sidepanel size",
    },
    {
      key = "+",
      action = A.resize_inc,
      desc = "Increase sidepanel size",
    },
  }
}

---@type dm.MappingsGroup
local watches_panel = {
  name = "WATCHES PANEL",
  hlgroup = "Keyword",
  mappings = {
    -- Help display only, actual keymaps are buffer-local in Watches.lua
    { key = "a", desc = "(in panel) Add expression (append)" },
    { key = "i", desc = "(in panel) Insert expression (prepend)" },
    { key = "d", desc = "(in panel) Delete expression" },
    { key = "e", desc = "(in panel) Edit expression" },
    { key = "s", desc = "(in panel) Set variable value" },
    { key = "c", desc = "(in panel) Copy expression" },
    { key = "<CR>", desc = "(in panel) Expand/collapse" },
    { key = "r", desc = "(in panel) Refresh" },
  }
}

-- keys.add() lands here; last so user mappings override generated nops
---@type dm.MappingsGroup
local misc = {
  mappings = {}
}

local command_groups = { execution, breakpoints, inspection, session, ui }

-- Nops: every printable key without an exact command mapping is swallowed,
-- and so are <C-d>/<C-u>: no vertical movement may work inside the layer,
-- so "does j (or C-d) move?" always answers which side of the layer you're
-- on. Survivors (never nop'd): count digits and the z* scroll/fold family;
-- Esc, the <C-w> family and the mouse aren't printable and are untouched.
-- Space is left alone too (leader safety, zero gdb cost).
-- Prefix-only keys (bare `i`, `[`, `]`) do get a nop, so a timed-out
-- prefix press dies instead of falling through to a vim command.

local survivors = { z = true }
for i = 0, 9 do
  survivors[tostring(i)] = true
end

local exact = { n = {}, v = {} }
for _, group in ipairs(command_groups) do
  for _, mapping in ipairs(group.mappings) do
    if mapping.action then
      for _, mode in ipairs(mapping.modes or { "n" }) do
        exact[mode][mapping.key] = true
      end
    end
  end
end

local function make_nop(key)
  local keycode = vim.keycode(key)
  return function()
    -- In panels, terminal, REPL and any other special buffer the layer
    -- steps aside: replay the key (with its count) natively.
    if vim.bo.buftype ~= "" then
      local count = vim.v.count > 0 and tostring(vim.v.count) or ""
      api.nvim_feedkeys(count .. keycode, "n", false)
    end
  end
end

---@type dm.MappingsGroup
local nops = {
  mappings = {}
}
for char = 33, 126 do
  local key = string.char(char)
  if not survivors[key] then
    for _, mode in ipairs({ "n", "v" }) do
      if not exact[mode][key] then
        table.insert(nops.mappings, {
          key = key,
          modes = { mode },
          action = make_nop(key),
          nop = true,
        })
      end
    end
  end
end

for _, key in ipairs({ "<C-d>", "<C-u>" }) do
  for _, mode in ipairs({ "n", "v" }) do
    table.insert(nops.mappings, {
      key = key,
      modes = { mode },
      action = make_nop(key),
      nop = true,
    })
  end
end

---@type dm.KeymapScheme
return {
  groups = {
    execution,
    breakpoints,
    inspection,
    session,
    ui,
    watches_panel,
    nops,
    misc,
  },
  misc = misc,
}
