# Design C — Full modal gdb layer

Status: implemented 2026-07-18 behind `cfg.keymaps = "gdb"` (the stock
scheme, `"default"`, stays the default). Implementation decisions: see
`keymaps-gdb-modal-impl.md`.

Supersedes Design A (`keymaps-gdb.md` — literal gdb, motions as arguments) and
Design B (`keymaps-gdb-motion.md` — motion contract, gdb where free). See
History at the bottom.

## Philosophy

1. **Debug mode is a pure gdb command layer. No vim motions exist inside it.**
   Real key-usage data (keyreport 2026-07-17) killed the A/B compromise: `n`
   (133 presses/day) and `b` (122) are simultaneously top-6 vim keys *and*
   gdb's two most important commands. Changing them in vim is a bad idea;
   changing them in gdb mode is hateful; keeping both is impossible. Mixing
   lands in no-man's land — so we stop mixing. Every key in the layer speaks
   gdb, manipulates UI, or does nothing.
2. **Navigation happens outside the layer.** Constant layer switching is easy
   to think about — it is literally how this keyboard already works (34-key
   board: all punctuation and digits live on one-shot layers; only letters,
   Esc, Tab and three thumb keys are single-press). Cursor-as-argument
   becomes: pop out → place cursor → pop in → command.
3. **Unmapped keys are nops, not passthroughs.** Passthrough would leak
   motions back in and re-create the no-man's land.
4. **Survivors — things that move the viewport or window, never the
   argument:** mouse wheel (scroll), the `<C-w>` family (window nav —
   user's `<Tab>`), `z*` (scroll/folds; viewport-only, zero gdb cost),
   count digits (`5n` must work), `Esc`. Revised 2026-07-19: `<C-D>`/`<C-U>`
   were survivors at first but are nop'd now, and freeing `j`/`k`/`v` was
   considered and rejected — **no vertical movement works inside the layer**,
   so "does j (or C-d) move?" always answers which side of the layer you're
   on. Layer confusion beats scroll convenience.
5. **Uppercase = UI namespace.** Sticky-shift makes uppercase a two-press =
   cold tier. Lowercase talks to the debugger; uppercase manipulates panels.
6. **Hot keys are prefix-free and `nowait`:** `c n s p t e w q <CR>` — nothing
   else may ever start with these letters. Delay is confined to the prefix
   keys `b f u d r i`, and with no motions behind them, an isolated-press
   delay costs latency on a cold command and nothing else.

## Keymap

### Execution

| Key             | Action                     | Notes                             |
|-----------------|----------------------------|-----------------------------------|
| `c`             | continue                   | instant                           |
| `n`             | step over                  | instant; gdb `next`; count works  |
| `s`             | step into                  | instant; gdb `step`               |
| `fin`           | step out                   | gdb `finish` — the literal keys   |
| `f`             | focus current frame        | gdb `frame`; waits (prefix of `fin`) |
| `u`             | run to cursor              | gdb `until`; cursor placed first  |
| `up` / `do`     | frame up / down            | gdb abbreviations; `<CR>` repeats |
| `r`             | restart / rerun last       | gdb `run`                         |
| `rc` `rs` `rn`  | reverse continue/step/next | gdb abbreviations; see below      |
| `<CR>`          | repeat last debug action   | gdb Enter; thumb key              |

Reverse commands need `record` or an rr-backed adapter. `<CR>` gives the same
n-n-n-Enter hammer rhythm as a real gdb prompt, and Enter is a thumb key.

### Breakpoints

| Key           | Action                  | Notes                                |
|---------------|-------------------------|--------------------------------------|
| `b`           | toggle breakpoint       | gdb `break`; cursor line is the arg  |
| `bc`          | conditional breakpoint  | reads "break, conditional"           |
| `d`           | contextual delete       | line bp if present, else delete-all  |
| `bp` / `bn`   | previous / next bp      | reads "break, previous/next"         |

`bc` is not literal gdb: `condition` would make `c` a prefix, which is
unacceptable. Contextual `d` covers both gdb's bare `delete` and per-bp
deletion (delete-all confirms first). `bp`/`bn` replaced the once-pending
`[b`/`]b`: that pair is nvim's native buffer-nav default (0.11+), so reusing
it with another meaning fights muscle memory, and every bracket command is
three presses on this keyboard anyway — two letters in the existing `b`
chord family cost less and collide with nothing.

### Inspection

| Key         | Action                        | Notes                              |
|-------------|-------------------------------|------------------------------------|
| `p`         | print (hover inspect)         | gdb `print`; cursor word is the arg |
| `bt`        | backtrace (frames float)      | literal gdb — recovered!           |
| `bq`        | backtrace → quickfix          | pushed like `:grep`, `:colder` works |
| `t`         | threads float                 | gdb `thread`; instant today        |
| `w`         | watch cursor word, open panel | gdb `watch`; the fork's normal `dp` |
| `ib` / `is` | breakpoints / sessions widget | gdb `info` group                   |
| `e`         | execute yanked text in REPL   | mnemonic **e**xecute/**e**val      |

`bt` was Design B's biggest loss; with `b` no longer a motion it is free
again. `t` stays instant unless `tb` (tbreak) is ever added. From the `info`
group, `il` is dropped (= `S` scopes), `it` dropped (= `t`), `if` dropped
(= `bt`). `x` stays reserved for gdb `examine` if memory inspection lands.

### Session & layer

| Key    | Action                       | Notes                             |
|--------|------------------------------|-----------------------------------|
| `<BS>` | toggle debug layer           | the most-pressed key of the design |
| `q`    | terminate session, exit layer | gdb `quit`                       |
| `N`    | new session                  | no gdb analog; "N"ew              |

`<BS>` is already the user's entry binding: thumb key, one press, session
keeps running. Stock `q` merely exited the mode; that job moves to `<BS>`.

Planned, not yet designed: a **one-shot entry** (press entry key from normal
mode → exactly one debug command runs → back to normal), mirroring the
keyboard's `&sl` sticky layers — makes "set a breakpoint while editing" a
two-press act. User already has one-shot machinery in their personal config;
key and implementation TBD.

### UI (uppercase family)

| Key                 | Action                      | Notes                     |
|---------------------|-----------------------------|---------------------------|
| `U`                 | toggle sidepanel            | was stock `L`             |
| `F`                 | toggle float layout         | was stock `U`             |
| `S` `T` `R` `H` `W` | scopes/term/REPL/help/watch | `W` unchanged from fork   |
| `M`                 | move terminal into panel    | was stock `dm`            |
| `<` / `>`           | rotate panel                | was `{`/`}`; two-press, cold |
| `-` / `+`           | resize panel                | unchanged; two-press, cold |

Watches-panel-internal keys (`a i d e s c r <CR>`, buffer-local in
Watches.lua) are untouched — inside a panel buffer its own maps rule, the
layer doesn't reach there.

### Visual selections (selected outside, executed inside)

Selection can only happen outside the layer now, but the commands that
consume it stay *inside* the layer as visual-mode maps. The workflow is
pure layer-hopping: leave layer → select → re-enter layer (the entry key
must be mapped in visual mode too) → command. Agreed 2026-07-18; replaces
the earlier session-live outside-the-layer maps.

| Key | Mode   | Action                    | Notes                          |
|-----|--------|---------------------------|--------------------------------|
| `p` | visual | inspect selection         | replaces the fork's visual `I` |
| `w` | visual | add selection to watches  | replaces the fork's visual `dp`; same key as normal-mode watch |

Nothing is mapped outside the layer, so visual `p` (paste-over-selection)
is untouched whenever the layer is off, and no session-lifecycle hooks are
needed.

## Timeout mechanics

Prefix keys: `b` (bt, bc, bq), `f` (fin), `u` (up), `d` (do), `r` (rc/rs/rn),
`i` (ib, is). All cold-tier; hot keys never wait. With motions gone, a delayed
prefix no longer holds anything hostage — the misfire analysis that dominated
Designs A/B is void. Lowering `timeoutlen` inside the layer remains an option,
dialed by feel, but the pressure to do so is far lower now.

## Mode awareness

The whole design bets on always knowing which side of the layer you're on — a
gdb key fired in normal mode edits text; a motion fired in the layer is a nop
(annoying, harmless). The nop-not-passthrough rule makes mistakes cheap in the
dangerous direction is-to-out; mode indication becomes load-bearing. It is
already covered: the user's lualine shows the debug mode via the
`DebugModeChanged` autocmd (configured in their nvim config) — no plugin
work needed.

## Changes from the fork's current keymaps

| From          | To      | From      | To          |
|---------------|---------|-----------|-------------|
| `o`           | `n`     | `dp`      | `w` / vis `w` |
| `m`           | `s`     | `I`       | `p` / vis `p` |
| `O`           | `fin`   | `x`       | `e`         |
| `r` (to csr)  | `u`     | `dn`      | `N`         |
| `dr`          | `r`     | `dq`      | `q`         |
| `t` (togg bp) | `b`     | `q` (exit) | `<BS>`     |
| `dc`          | `bc`    | `dm`      | `M`         |
| `da`          | `d`     | `[s`/`]s` | `do`/`up`   |
| `dj`          | `f`     | `L`       | `U`         |
| `df`          | `bt`    | `U`       | `F`         |
| `dt`          | `t`     | `{`/`}`   | `<`/`>`     |
| `db`          | `ib`    | `ds`      | `is`        |
| `[b`/`]b`     | `bp`/`bn` |         |             |

Unchanged: `c`, `W`, `S` `T` `R` `H`, `-`/`+`,
watches-panel-local keys.

## History

- **Design A** (`keymaps-gdb.md`): literal gdb, but motions kept as the
  argument-passing mechanism. Died because `n` (step) and `b` (break) collide
  with the user's #5 and #6 most-pressed vim keys, and every resolution was
  painful.
- **Design B** (`keymaps-gdb-motion.md`): stock motion contract, gdb only
  where free. Died twice over: key-usage data showed most of the motions it
  protected (`f t e ; ,`) are unused on this keyboard (all punctuation is
  two-press; `f` belongs to leap), while the two it protected for real (`n b`)
  forced non-gdb spellings (`o`, `t`, `if`) — the exact fidelity loss the
  redesign existed to avoid.
- **The pivot (2026-07-17):** both designs were mixing two languages in one
  namespace. Full modal commitment ends the conflict structurally instead of
  trading casualties, and recovers `bt`, `w`=watch, and future `x`=examine for
  free. Old docs kept for the reasoning that still applies (reverse debugging,
  visual-mode machinery, uppercase economics).
