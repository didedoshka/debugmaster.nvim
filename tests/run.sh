#!/usr/bin/env bash
# Offline test harness: no network, no services, no debug adapter.
# Usage: tests/run.sh   (exits non-zero on any failure)
set -u
cd "$(dirname "$0")/.."

# nvim-dap is the plugin's one hard dependency; point DEBUGMASTER_DAP at a
# checkout if it isn't in the default lazy.nvim location.
DAP="${DEBUGMASTER_DAP:-$HOME/.local/share/nvim/lazy/nvim-dap}"
if [ ! -d "$DAP/lua/dap" ]; then
  echo "error: nvim-dap not found at $DAP (set DEBUGMASTER_DAP=/path/to/nvim-dap)" >&2
  exit 1
fi

# Each spec gets its own nvim: keymap scheme resolution is once-per-process.
status=0
for spec in tests/spec.lua tests/spec_gdb.lua tests/spec_ui.lua; do
  nvim --headless --clean --cmd "set rtp+=$PWD,$DAP" -l "$spec" || status=1
done
exit "$status"
