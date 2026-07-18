# Design A — Literal gdb, full modal commitment

Status: **superseded 2026-07-17** by [keymaps-gdb-modal.md](./keymaps-gdb-modal.md) (Design C, full modal layer) — kept as design history.
Companion: [keymaps-gdb-motion.md](./keymaps-gdb-motion.md) — a variant that preserves more vim motions at the cost of some gdb fidelity.

## Philosophy

1. **Debug mode mirrors gdb muscle memory as literally as possible.** If gdb users type it, we map it: `c`, `n`, `s`, `fin`, `b`, `bt`, `p`, `u`, `r`, `q`, `up`, even `rc`/`rs`/`rn`.
2. **Overriding normal-mode keys is fine.** Unlike the stock plugin philosophy, we treat debug mode like insert mode: switching modes should be cheap and constant, so debug mode may claim keys aggressively. ("Switching modes all the way.")
3. **…except motions, because the cursor is the argument.** In gdb, commands take arguments (`b main.c:42`, `p myvar`). In a modal editor the cursor position replaces the argument: move to a line and press `b`; put the cursor on a variable and press `p`; `u` runs to the *cursor*. Motions aren't a navigation luxury — they're the argument-passing mechanism for half the command set. This is why `h j k l g w /` survive even though gdb technically has `h`(elp), `l`(ist), `k`(ill): those are low-value in nvim (source is already on screen; `H` shows help; `q` covers kill), while motions are load-bearing.
4. **gdb's grammar is prefix-free only because of Enter.** `s` and `si` never collide at the gdb prompt because Enter terminates commands. Vim keymaps have no terminator, so any multi-char command sharing a prefix with a single-char one (`b`/`bt`) makes the short key wait `timeoutlen`. Consequence: **the hot keys must not be prefixes.** `c n s p q e <CR>` are prefix-free and `nowait` — truly instant. Delay is confined to warm-tier keys only: `b u d f r i`.

**Preserved (never mapped):** `h j k l`, `w`, `ge`, `gg`/`G` and the rest of the `g` prefix, `/` and `?`, `{ } ( ) %`, `v` (visual mode), `y` (yank — you copy values out of the scopes panel), `z*` (scroll/folds), `a` (kept as an *instant* way into insert mode, since `i` is delayed).
5. **`<CR>` = repeat last debug action.** gdb users don't type `nnnn`; they type `n` once and hammer Enter. Vim's `.` exists but is two keypresses on this keyboard layout and repeats *edits*, not debug actions. `<CR>` in normal mode does nothing valuable — free key, deep gdb habit.
6. **Uppercase = UI namespace.** gdb has no vocabulary for panels/windows, so UI keys are pure invention. With one-shot shift modifiers, an uppercase key costs the same as any two-key combo. Lowercase talks to the debugger; uppercase manipulates windows.
7. **`i` = gdb's `info` prefix (state widgets); uppercase = window manipulation.** gdb `info` *shows state*; toggling a terminal panel *manipulates UI*. Two namespaces, deliberately not mixed.

## Keymap

### Execution

| Key | Action | Notes |
|---|---|---|
| `c` | continue | instant (`nowait`); nothing else may ever start with `c` |
| `n` | step over | instant; gdb `next` |
| `s` | step into | instant; gdb `step` |
| `fin` | step out | gdb `finish` — the literal keys gdb users type |
| `f` | focus current frame | gdb `frame`; fires after timeout (prefix of `fin`) |
| `u` | run to cursor | gdb `until`; cursor is the argument |
| `up` / `do` | frame up / down | gdb's own abbreviations; repeat with `<CR>` |
| `r` | restart / run | gdb `run` |
| `rc` `rs` `rn` | reverse continue / step / next | gdb's official abbreviations (see "Reverse debugging") |
| `<CR>` | repeat last debug action | gdb Enter |

### Breakpoints

| Key | Action | Notes |
|---|---|---|
| `b` | toggle breakpoint | gdb `break`; cursor line is the argument |
| `bc` | conditional breakpoint | **not** literal gdb — gdb's `condition` starts with `c`, which would make `c` a prefix and put a delay on continue; unacceptable. `bc` reads as "break, conditional" |
| `d` | contextual delete | breakpoint on current line if there is one, else confirm-and-delete-all — covers both gdb bare-`delete` and per-breakpoint deletion with one key |
| `[b` / `]b` | previous / next breakpoint | no gdb analog; vim bracket idiom |

### Inspection

| Key | Action | Notes |
|---|---|---|
| `p` | print (hover inspect; evaluate selection in visual) | gdb `print` |
| `bt` | backtrace (frames float) | literal gdb |
| `t` | threads float | gdb `thread`; instant unless `tb` (tbreak) is ever added |
| `ib` / `is` | breakpoints / sessions widgets | gdb `info` group. `il` dropped (redundant with `S`), `it` dropped (redundant with `t`) |
| `e` | execute yanked text in REPL | no gdb analog. `x` was rejected: gdb `x` is *examine memory*, not eval. Bare `e` is ambiguous in gdb (echo/edit/enable/eval) so no muscle memory collides; mnemonic: **e**xecute/**e**val |

### Session

| Key | Action | Notes |
|---|---|---|
| `q` | terminate session, leave debug mode | gdb `quit`; macro recording deemed worthless mid-debug |
| `N` | new session | no gdb analog ("N"ew) |

### UI (uppercase family)

| Key | Action | Notes |
|---|---|---|
| `U` | toggle sidepanel | was stock `u` |
| `F` | toggle float layout | "F"loat; was stock `U` |
| `S` `T` `R` `H` | scopes / terminal / REPL / help sections | unchanged from stock |
| `M` | move current terminal into panel | was stock `dm` |
| `<` / `>` | rotate panel | was stock `{`/`}` — this returns paragraph motions to normal use; `<`/`>` indent operators are worthless in a non-editable mode |
| `-` / `+` | resize panel | unchanged |

## Timeout mechanics (why the delays are acceptable)

- The delay applies **only to prefix keys** (`b u d f r i`) and **only on isolated presses** — press the key and wait, and it fires after `timeoutlen`. In a burst, the next keypress resolves the pending one immediately, so hammering is never delayed. Adapter round-trips (50–300ms per step) mask part of it anyway.
- **`timeoutlen` is global.** Lowering it (e.g. to 200–300ms) applies to *all* mappings while active — leader combos become "type within the window or they break." Plan: lower it **only while debug mode is active**, restore on exit; exact value to be dialed by feel after real use.
- **Misfire window:** a prefix key followed within the timeout by a continuation key fires the mapping. Realistic case: pressing `i` (intending insert in the REPL) and typing `b` fast triggers `ib`. Mitigation: `a` remains an *instant* way into insert mode.
- Dropping `si`/`ni` (never used) was the key unlock: it un-prefixed `s` and `n`, making the two hottest keys instant.

## Reverse debugging

gdb's commands are `reverse-continue`, `reverse-step`, `reverse-next`, abbreviated `rc`/`rs`/`rn` — that is real gdb muscle memory, so they live under `r`. The uppercase-as-reverse convention (`C` = reverse continue) belongs to nvim-dap-rr and the stock plugin philosophy, not gdb; uppercase went to UI instead.

Native gdb reverse requires enabling recording first (`record`/`rec`) and is slow; in practice reverse debugging means an **rr**-backed adapter where the whole run is recorded and reverse commands just work. Enabling `record` on native gdb is once-per-session: type `rec` at the REPL prompt. No keymap spent; `rec` slots cleanly under `r` later if wanted.

## Visual mode

No machinery needed: debug-mode maps are normal-mode mappings, and visual mode has its own map table. Entering visual mode automatically restores *all* motions (`b w e f t n`) for extending selections. The only debug key mapped in visual is `p` (evaluate selection) — exactly the one wanted there.

## Known losses (accepted, watch in practice)

- **Search-next `n` is gone** (it's step over). `/` still works; repeating a search has no key. Candidates if it stings: `gn`, `<C-n>`. Deliberately deferred until felt.
- `b`, `f`, `t`, `e` motions gone in normal mode (`w`, `ge` still cover word movement; visual mode has everything).
- Insert via `i` is delayed by the timeout in REPL/terminal; `a` is instant.
- `w` deliberately left unmapped — reserved as the natural home for `watch` if a watches panel ever exists.

## Mapping from stock keymaps

`o`→`n`, `m`→`s`, `q`(step out)→`fin`, `dj`→`f`, `da`→contextual `d`, `dc`→`bc`, `dr`→`r`, `dq`→`q`, `dn`→`N`, `dm`→`M`, `[s`/`]s`→`up`/`do` (+`<CR>` repeat), `u`→`U`, `U`→`F`, `{`/`}`→`<`/`>`, `x`→`e`, `df`→`bt`, `dt`→`t`, `db`→`ib`, `ds`→`is`, `I`→`p`, `t`(toggle bp)→`b`.
