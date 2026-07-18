# Design B — gdb vocabulary, motions preserved

Status: **superseded 2026-07-17** by [keymaps-gdb-modal.md](./keymaps-gdb-modal.md) (Design C, full modal layer) — kept as design history. Drafted 2026-07-16 alongside [keymaps-gdb.md](./keymaps-gdb.md) (Design A).

Design A takes gdb literally and pays for it with motions (`n b f t e` are gone). Design B is the hedge: **keep the motion contract the stock plugin promises, and speak gdb wherever gdb doesn't collide with a motion.** Where gdb collides, fall back to the stock plugin's proven answer rather than inventing something new.

Everything in Design A that isn't about motions carries over unchanged: `<CR>` = repeat, uppercase = UI namespace, `i` = info prefix, `rc`/`rs`/`rn` = reverse, contextual `d`, `up`/`do` = frame up/down, the timeout policy.

## The motion contract

**Preserved:** `h j k l`, `w b e ge W B E`, `f F ; ,`, `/ ? n N`, `gg G` and the `g` prefix, `{ } ( ) %`, `v`, `y`, `z*`, `a` (instant insert-mode escape hatch, since `i` is a prefix).

This is exactly the set the stock design philosophy names ("`b`, `w`, `e`, `hjkl`, `f`, `F`, `/`, `n`, `N` are not overridden") — Design B holds that line.

**Sacrificed:**
- `t` / `T` (till motions) — stock sacrifices these too; `f`/`F` + `;`/`,` cover in-line aiming.
- `H` / `M` / `L` (screen motions) — low frequency, and the uppercase namespace is needed for UI. `z`-scrolling still works.
- `-` / `+` (line motions) — redundant with `j`/`k`; stock already spends them on resize.
- All editing keys (`c d i m o p q r s u x` and most uppercase) — the buffer isn't editable in debug mode, so these are free money.

## Keymap

### Execution

| Key | Action | Notes |
|---|---|---|
| `c` | continue | gdb ✓ literal. Instant |
| `o` | step over | gdb's `n` is search-next here, so stock's `o` ("over"). Instant |
| `s` | step into | gdb ✓ literal — improves on stock's `m`. Instant |
| `q` | step out | stock's "[q]uit current stack frame". gdb's `fin` is impossible: `f` is a motion, and a `fin` mapping would shadow `fi` (find the letter `i`). Instant |
| `u` | run to cursor | gdb `until` ✓ (`u LOCATION` runs to a location; cursor is the location) |
| `up` / `do` | frame up / down | gdb's own abbreviations; repeat with `<CR>` |
| `J` | jump to current frame | gdb `frame`, but `f` is a motion here. `J` = "**J**ump"; join-lines is worthless in a read-only mode |
| `r` | restart / run | gdb `run` ✓ |
| `rc` `rs` `rn` | reverse continue / step / next | gdb's official abbreviations. See Design A's "Reverse debugging" — needs `record` (or an rr-backed adapter) |
| `<CR>` | repeat last debug action | gdb Enter |

**The whole step family — `c o s q` — is instant here**, which is Design B's quiet win over Design A. Design A's `fin` and `bt` are what force `f` and `b` into prefixes; drop those spellings and the reflex tier gets shorter.

### Breakpoints

| Key | Action | Notes |
|---|---|---|
| `t` | toggle breakpoint | gdb's `b` is word-back here → stock's `t`. Delayed by `tc` |
| `tc` | conditional breakpoint | same shape as Design A's `bc` — "toggle, conditional" |
| `d` | contextual delete | gdb `delete` ✓. Breakpoint on the current line if there is one, else confirm-and-delete-all |
| `[b` / `]b` | previous / next breakpoint | vim bracket idiom, no gdb analog |

### Inspection

| Key | Action | Notes |
|---|---|---|
| `p` | print (hover; evaluate selection in visual) | gdb `print` ✓ |
| `if` | frames float (backtrace) | gdb's `bt` is impossible (`b` is a motion). `info stack`/`info frame` is the legitimate gdb cousin — the `bt` muscle memory is the single biggest fidelity loss in Design B |
| `it` | threads float | gdb `info threads` ✓ literal |
| `ib` | breakpoints widget | gdb `info breakpoints` ✓ literal |
| `is` | sessions widget | no gdb analog |
| `x` | execute yanked text in REPL | `e` is a motion here, so stock's `x` returns by default. Note this contradicts Design A's reasoning (gdb's `x` is *examine memory*, not eval) — in Design B it's simply the least-bad free key |

`il` (info locals) is intentionally dropped in both designs: it would be a second name for `S` (scopes).

### Session

| Key | Action | Notes |
|---|---|---|
| `Q` | terminate session, leave debug mode | gdb `quit`, bumped to uppercase because `q` is step out |
| `D` | new session | arbitrary — "**D**ebug new" / DapNew. `N` (Design A's choice) is search-prev here |

### UI (uppercase family)

| Key | Action | Notes |
|---|---|---|
| `U` | toggle sidepanel | was stock `u` |
| `M` | toggle float layout | "**M**aximize" — float mode exists to give the panel more room. Design A's `F` is find-back here |
| `S` `T` `R` `H` | scopes / terminal / REPL / help sections | unchanged from stock |
| `A` | attach current terminal to the panel | "**A**ttach" (the code literally calls `attach_terminal_to_current_session`). Lowercase `a` stays insert |
| `<` / `>` | rotate panel | frees `{`/`}` paragraph motions; indent operators are worthless in a read-only mode |
| `-` / `+` | resize panel | unchanged from stock |

## Prefix / timeout profile

**Instant:** `c o s q p x a J <CR>` + every uppercase UI key.
**Delayed:** `t` (by `tc`), `u` (by `up`), `d` (by `do`), `r` (by `rc`/`rs`/`rn`), `i` (by the info group), `[`/`]`.

Same policy as Design A: lower `timeoutlen` only while debug mode is active, restore on exit, dial the value by feel. The misfire window is identical in shape (`i` then a fast `b` gives `ib`, not insert-then-b; `a` is the instant escape hatch).

## What Design B costs, honestly

- **`bt` is gone** — a top-tier gdb reflex, replaced by `if`. This is the real price.
- **`fin` is gone** — `q` instead. Less of a loss than it looks: `q` is what this plugin has always used, and it's instant.
- **`b` = break is gone** — `t` instead. `b` is arguably gdb's single most-typed letter after the step family, so this hurts about as much as `bt`.
- **`x` for "execute in REPL"** has no justification beyond precedent.
- Two keys shift off Design A's choices for no reason except collisions (`Q`, `D`), which makes the uppercase family less mnemonic than Design A's.

## What Design B buys

- Search (`n`/`N`) survives — the loss Design A explicitly flagged as "watch this in practice."
- In-line aiming (`f`/`F`/`;`/`,`) and word motions (`b`/`e`) survive, so landing the cursor on a variable to `p` it never needs a mode switch.
- The entire reflex tier (`c o s q`) is instant, with no timeout tuning needed to feel good.
- It is a strict superset of the stock plugin's motion guarantees, so it's the safer thing to live with if the "switch modes all the way" bet doesn't pan out.

## Switching between the two

The designs differ in 11 keys. If both are implemented as selectable presets, the diff is:

| Action | Design A | Design B |
|---|---|---|
| step over | `n` | `o` |
| step out | `fin` | `q` |
| focus frame | `f` | `J` |
| toggle breakpoint | `b` | `t` |
| conditional bp | `bc` | `tc` |
| backtrace | `bt` | `if` |
| threads | `t` | `it` |
| execute in REPL | `e` | `x` |
| quit session | `q` | `Q` |
| new session | `N` | `D` |
| float layout | `F` | `M` |

Identical in both: `c`, `s`, `u`, `up`/`do`, `r`, `rc`/`rs`/`rn`, `p`, `d`, `[b`/`]b`, `ib`, `is`, `<CR>`, `U`, `S`, `T`, `R`, `H`, `<`/`>`, `-`/`+`, `a`, and the visual-mode story (`p` only — every other motion returns automatically, because debug maps are normal-mode maps and visual mode has its own table).
