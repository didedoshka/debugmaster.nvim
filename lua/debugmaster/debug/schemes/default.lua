-- The stock keymap scheme (cfg.keymaps = "default").
local A = require("debugmaster.debug.actions")

---@type dm.MappingsGroup
local move_debugger_group = {
  name = "MOVE DEBUGGER",
  hlgroup = "ERROR",
  -- the main goal when developing keymaps for debug mode is to not override normal mode motions
  -- We want to our DEBUG mode be "constant". So we can freely move and can't edit text
  mappings = {
    {
      key = "o",
      action = A.step_over,
      desc = "Step over. Works with count (Try to type '5o')",
    },
    {
      key = "m",
      action = A.step_into,
      desc = "Step into (mine deeper)",
    },
    {
      key = "O",
      action = A.step_out,
      desc = "Step out ([O]ut of current stack frame)",
    },
    {
      key = "c",
      nowait = true,
      action = A.continue,
      desc = "Continue or start debug session",
    },
    {
      key = "r",
      action = A.run_to_cursor,
      desc = "Run to cursor",
    },
  }
}

---@type dm.MappingsGroup
local sidepanel = {
  name = "SIDEPANEL",
  hlgroup = "STRING",
  mappings = {
    {
      key = "L",
      action = A.open_or_focus_sidepanel,
      desc = "Open ui here, or go to it",
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
  }
}

---@type dm.MappingsGroup
local float_widgets = {
  name = "FLOAT WIDGETS",
  hlgroup = "STATEMENT",
  mappings = {
    {
      key = "df",
      action = A.frames_widget,
      desc = "Frames widget"
    },
    {
      key = "dt",
      action = A.threads_widget,
      desc = "Threads widget"
    },
    {
      key = "ds",
      action = A.sessions_widget,
      desc = "Debug sessions widget",
    },
    {
      key = "db",
      action = A.breakpoints_widget,
      desc = "Breakpoints widget"
    },
    {
      key = "I",
      modes = { "n", "v" },
      action = A.inspect,
      desc = "Inspect variable or visually selected expression",
    },
  }
}

---@type dm.MappingsGroup
local watches_group = {
  name = "WATCHES",
  hlgroup = "Keyword",
  mappings = {
    {
      key = "W",
      action = A.open_watches,
      desc = "Open watches panel",
    },
    {
      key = "dp",
      modes = { "n", "v" },
      action = A.add_to_watches,
      desc = "Add cursor word/selection to watches",
    },
    -- Watches panel keymaps (for Help display only, actual keymaps in Watches.lua)
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

---@type dm.MappingsGroup
local breakpoings_group = {
  name = "BREAKPOINTS",
  hlgroup = "Boolean",
  mappings = {
    {
      key = "t",
      action = A.toggle_breakpoint,
      desc = "Toggle breakpoint",
    },
    {
      key = "da",
      action = A.clear_breakpoints,
      desc = "Delete all breakpoints",
    },
    {
      key = "dc",
      action = A.conditional_breakpoint,
      desc = "Add conditional breakpoint",
    },
    {
      key = "[b",
      action = A.prev_breakpoint,
      desc = "Go to previous breakpoint"
    },
    {
      key = "]b",
      action = A.next_breakpoint,
      desc = "Go to next breakpoint"
    },
  },
}

---@type dm.MappingsGroup
local misc_group = {
  name = "MISCELANOUS",
  hlgroup = "TYPE",
  mappings = {
    {
      key = "q",
      action = A.exit_mode,
      desc = "Exit debug mode (back to normal mode)",
    },
    {
      key = "dr",
      desc = "Restart the current session or rerun last if none",
      action = A.restart,
    },
    {
      key = "dn",
      action = A.new_session,
      desc = "Debug start new sessions",
    },
    {
      key = "dq",
      action = A.quit,
      desc = "Quit debug"
    },
    {
      key = "[s",
      action = A.frame_down,
      desc = "Go to previous stack frame"
    },
    {
      key = "]s",
      action = A.frame_up,
      desc = "Go to next stack frame"
    },
    {
      key = "dj",
      action = A.focus_frame,
      desc = "Jump to the current stack frame"
    },
    {
      key = "x",
      action = A.exec_yanked,
      desc = "Execute last yanked or deleted text in the repl",
    },
    {
      key = "dm",
      action = A.move_terminal,
      desc = "Move current terminal to the 'Terminal' segment"
    },
  }
}

---@type dm.KeymapScheme
return {
  groups = {
    move_debugger_group,
    breakpoings_group,
    sidepanel,
    float_widgets,
    watches_group,
    misc_group,
  },
  misc = misc_group,
}
