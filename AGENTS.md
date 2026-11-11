# debugmaster.nvim — session rules

Fork of debugmaster.nvim with a watches panel, developed locally.

## Layout
- `lua/debugmaster/` — source. `init.lua` = public API (`cfg`, `mode`, `keys`, `plugins`);
  `debug/` = debug mode + keymap registry; `ui/` = sidepanel components (class-style
  modules with `.new()`); `state.lua` wires them; `plugins.lua` = optional integrations.
- `doc/keymaps-gdb-modal.md` — authoritative keymap redesign (Design C),
  implemented behind `cfg.keymaps = "gdb"`; `"default"` (stock) is the default.
  `keymaps-gdb.md` / `keymaps-gdb-motion.md` are superseded history.
  `debug/keymaps.lua` = lazy scheme registry (resolved at first enable);
  shared callbacks in `debug/actions.lua`, schemes in `debug/schemes/`.
- `tests/` — offline suite; also fired by the PostToolUse hook on every Lua edit.

## Invariants
- Only hard dependency: nvim-dap. snacks.nvim is optional — every use sits behind
  `pcall(require, "snacks")` with a native fallback. Keep it that way.
- Neovim >= 0.10 must keep working.
- Debug mode must restore the user's original keymaps exactly on disable, across
  repeated enable/disable cycles (`debug/mode.lua` originals table; tested).
- The `DebugModeChanged` User autocmd is public API (statusline recipe depends on it).

## Verify
- `tests/run.sh` (offline, end-to-end, ~0.1 s) + `lua-language-server --check .`
  (baseline: **0 problems**; always run from repo root — it can't find `.luarc.json`
  from a subdir). lua-ls does NOT catch cross-module breakage; only the suite does.
  Tiers and live checks: `.agents/skills/verify/SKILL.md`.

## Style & workflow
- 2-space indent. Formatting comes from lua_ls/EmmyLuaCodeStyle via the `format`
  block in `.luarc.json` — no stylua, don't add it.
- Keep `---@class dm.*` annotations truthful; the lint gates on them.
- Commit each verified change (suite + lua-ls green) without asking: on `main`,
  `area: lowercase summary`.
  Never rewrite history -- no amend, rebase, or reset past a commit; fix forward
  with a new commit, so nothing is ever lost.
