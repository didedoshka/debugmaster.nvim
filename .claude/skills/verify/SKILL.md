---
name: verify
description: How to confirm a debugmaster.nvim change actually works, in tiers — offline suite always; live checks for anything touching a real debug session or rendering.
---

# Verifying changes in debugmaster.nvim

## Tier 0 — offline, run for every change (the hook runs this too)

```sh
tests/run.sh                     # end-to-end headless suite, ~0.1 s, exit != 0 on failure
lua-language-server --check .    # from repo ROOT only; baseline is 0 problems
```

What the suite really covers: every module loads against real nvim-dap; the public API
surface; keymap registry get/add/error; debug-mode enable/disable with real keymap
override + exact restore across cycles; a real `t` keypress setting a real dap
breakpoint; `gotoBreakpoint` navigation + wraparound; the `DebugModeChanged` event
contract; watches' no-session refusal; utils (statusline hl, float configs, the
snacks-absent float fallback, debounce).

Division of labor, measured not assumed: lua-ls finds undefined globals/wrong
annotations but is blind to cross-module breakage (a deleted function with live
callers is "no problems found"). The suite catches that only for code it loads or
exercises. New pure logic ⇒ add an assertion to `tests/spec.lua`, not a mock.

## Tier 1 — live, needs a real debug session (user-driven)

Anything touching session behavior (Watches evaluate/expand/set-value, Scopes, REPL,
stepping, frame navigation) is only truly verified inside a session. Cheapest real
session: osv lua debugging per `doc/RECIPES.md` — ask the user to run it and step.
UI rendering (sidepanel layout, snacks-styled widgets — snacks exists only in the
user's real config, never under `--clean`) also needs eyes on a real editor.

## Never verified — do not fire just to "test"

- Reverse debugging (`rc`/`rs`/`rn`, rr-backed adapters) — no rr setup has ever been
  exercised from this repo.
- Real language adapters (gdb, codelldb, debugpy) — not installed here.
- Attaching lua-language-server headlessly to test LSP formatting **hangs**; ask the
  user to run `:lua vim.lsp.buf.format()` instead.
