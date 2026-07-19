# Design C — implementation decisions

Companion to `keymaps-gdb-modal.md` (the what/why). This doc records the
how. Agreed and implemented 2026-07-18.

## 1. Scheme selection via config

- New option `cfg.keymaps = "default" | "gdb"`; `"default"` = the current
  stock maps and is the default value.
- Resolved lazily at the first `mode.enable()` call. No live switching:
  the originals save/restore machinery in `debug/mode.lua` snapshots the
  user's maps once, and a mid-session scheme swap buys nothing.
- Both schemes are maintained; `"default"` is not a deprecation alias.

## 2. Module structure

- Extract the action callbacks out of `debug/keymaps.lua` into a shared
  `debug/actions.lua` so behavior is written once.
- Each scheme is a thin key→action table (groups of `dm.KeySpec`, same
  shape as today): `debug/schemes/default.lua`, `debug/schemes/gdb.lua`.
- `debug/keymaps.lua` stays the registry: picks the scheme per `cfg.keymaps`
  and keeps exposing `groups`, `get`, `add` — the public `M.keys` API and
  the HelpPopup (which renders from `groups`) are unchanged and follow the
  active scheme automatically.

## 3. Nop mechanism

- Enumerate every printable key the gdb scheme doesn't map and that isn't a
  survivor — plus `<C-d>`/`<C-u>` (2026-07-19, no vertical movement inside
  the layer) — and map each through the existing save/restore machinery in
  `mode.lua` — no `vim.on_key` (global, needs fragile mode/buffer guards to
  avoid eating keys in the REPL terminal and cmdline).
- The nop is a function, not a literal `<Nop>`: in non-file buffers
  (`buftype ~= ""` — panels, terminal, REPL, dap floats) it feeds the key
  through natively (`feedkeys`, noremap) so `j`/`k`/`G` etc. still move
  inside panels; in real file buffers it does nothing.
- Swallowed keys are silent — no hint UI. Easiest option first; revisit
  after battle-testing.
- Nop mappings are not listed in the help popup.

## 4. Deferred: count chaining (`5n`)

Digits stay survivors, but step actions don't honor counts yet:
`dap.step_over()` takes no count and steps are async, so a correct
implementation needs chaining on `stopped` events. `5n` currently performs
one step. Revisit later.

## 5. `<CR>` repeat slot

Only execution commands enter the repeat slot: `c n s fin u up do` and the
reverse variants `rc rs rn`. `r`, `q`, `N`, inspection (`p`, `bt`, …) and
UI keys never do. Not gdb-faithful (gdb repeats most commands) — minimal
version first.

## 6. Visual workflow

Per the design doc (updated 2026-07-18): `p`/`w` get visual-mode variants
*inside* the layer; selection is made outside and carried back in by
re-entering the layer with the selection active. No maps outside the layer,
no dap lifecycle listeners. The user's `<BS>` entry binding must also be
mapped in visual mode (user config, not plugin).

## 7. Mode indication

Out of scope — already covered by the user's lualine via the
`DebugModeChanged` autocmd.

## 8. Minor

- `d`'s delete-all path confirms via `vim.fn.confirm()` before clearing.
