# Task 9 report: the ledger's LAST ROUND band

**Status:** complete.

**Commit:** `45cd23a` — "feat(roblox): the ledger remembers the round you just played"

**Suites:**
- `roblox/`: `lune run tests/run` — 962 passed, 0 failed (958 baseline + 4 new `LedgerModel.shares`
  tests).
- `stylua --check src tests tools` — clean. `selene src tools` — 0 errors, 0 warnings.
- `server/`: `npm test` — 211 passed (unchanged; this task touched no server code).
- `rojo build` also sanity-checked locally (not one of the listed gates, but in CI) — succeeds.

**The three numbers for a 1/1/1 split:** `LedgerModel.shares({1,1,1})` → **34, 33, 33** (sums to
100). Also verified against the actual wire shape the band receives — the server's own
`buildDistribution` naively rounds to `{33,33,33}` (itself summing to 99) — and re-apportioning
that through `shares` still lands on **34, 33, 33**. Both cases are asserted in
`roblox/tests/LedgerModel.spec.luau`.

**Both carryovers from Task 7's review, closed:**
1. `pendingReveal` → `lastRound`: a new persistent local in `main.client.luau`, declared *before*
   `publishLedger` (Luau closures need the local already in scope). Set in `maybeShowReveal`
   (surviving that function's `pendingReveal = nil`), included in `publishLedger`'s payload, and
   `publishLedger()` is now also called from `maybeShowReveal` itself — without that call the
   ledger would show the *previous* round's detail until the next ProfileUpdate happened to fire
   (which for a spectator round might never come).
2. `pick`: the server already sent it (`RoundCoordinator.luau:154`/`main.server.luau:354`) but the
   client dropped it. Added to `pendingReveal`'s type and the `RevealResult` handler.

**The band:** `LedgerController.client.luau` gained a `lastRoundBand` above the hero band —
world/player glyphs (pre-built R/P/S per side, toggled by `.Visible`, the same pattern the ring and
tape badges use), the result (coloured via the WIN/SAFE/LOSS triad, reused rather than inventing a
new palette), a player count, and a crowd-split bar. `heroTop()` returns `HEADER_H` when
`lastRound` is nil or `HEADER_H + LAST_ROUND_H + GAP` when present; `bodyTop()` (replacing the old
`BODY_TOP` literal) derives from it. Both the hero band and `tabs` reposition from these functions
inside `applyLayout()`, which now also sets `lastRoundBand.Visible`. `EventBus.LedgerState`'s
handler calls `applyLayout()` before `render()` (previously just `render()`) so a reveal landing
while the panel is open shifts the hero live.

**The bar's math:** `LedgerModel.shares` (the win-rate bar's largest-remainder apportionment) is
now `LedgerModel.shares` — exported — and both the lifetime bar and the new round bar call the one
implementation. `barSegment` was generalized to take its track as a parameter and relocated next to
`corner`/`stroke`/`label` so both bars share it too.

**Verification performed (no gate covers these):**
- Fresh join: `lastRound` starts nil in both files; `lastRoundBand.Visible=false`, `hero.Position`
  = `HEADER_H` at construction and after the initial `applyLayout()` call — same value either way.
- Scroll canvas: `body.Size`'s `-(top+FOOTER_H+GAP)` formula already re-derives through `bodyTop()`
  → `heroTop()`, so the footer (anchored to the panel's bottom, untouched by any of this) stays
  reachable regardless of band visibility.
- Survives close/reopen: `lastRound` in `LedgerController` is set unconditionally in the
  `LedgerState` handler (outside the `if isOpen` guard), and `close()` never touches it — reopening
  just re-renders from the same persisted value.

**Concerns:** `main.client.luau` still has no `Instance.new`; `UIStroke` is only ever applied to
`Frame`s (never the new `TextLabel`s), matching the project rule. One deliberate, unforced design
call: the crowd-split bar reuses the WIN_GREEN/GOLD/LOSS_RED triad for R/P/S since no R/P/S colour
palette exists yet anywhere in the codebase — visual borrowing, not semantic (documented inline).
