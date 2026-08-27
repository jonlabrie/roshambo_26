# Final review fix wave — 2026-08-02 play HUD

One pass over all eight code findings from the whole-branch review. Docs (spec/plan) untouched —
already handled by the caller. Both gates green after every commit.

Commits (branch `m4b-zendojo-art-pass`, on top of `70eef6c`):

| SHA | Subject |
| --- | --- |
| `db6e0b9` | fix(roblox): rate-limit SetHudPreference; the ledger refresh takes only counters |
| `7721170` | fix(roblox): onboarding cards live in gui space; one source for the HUD skeleton |
| `3842e01` | fix(roblox): the ledger clips and scrolls its cards; the PlayerScripts wait is timed |
| `c305b5e` | fix(roblox): don't fire the join beat before the profile has answered |
| `1cebe95` | docs: retire the win-gate vocabulary from comments and test names |

---

## 1. `SetHudPreference` unrated + fire-and-forget PUT — FIXED (`db6e0b9`)

`roblox/src/server/main.server.luau`.

The handler body now runs inside `handlerQueue:run(uid, ...)`, exactly like `SetPadPreference`,
`SetBackDoor`, `RequestPurchase` and `BankRequest`. That gives it the same two properties every
sibling already had: one player's writes are serialized (no overlapping PUTs even across the HTTP
yield), and the lane is bounded at `HandlerQueue.MAX_PENDING = 8`, so a scripted client looping the
remote gets its overflow dropped with a `[QUEUE]` warn instead of spawning unbounded concurrent
requests against the ~500/min per-server HttpService budget. I chose the queue over a per-uid
debounce because a debounce would silently swallow *legitimate* rapid writes — dismissing a beat
and flicking the escalation switch in the same second are two different payloads that both need to
persist — whereas the lane runs both, in order.

Paired minor, same handler: the write is no longer fire-and-forget. `net:putHudPreference`'s
`Result` is captured; on `not persisted.ok` the previous `hudPrefs[uid]` / `hudSeenBeats[uid]` are
restored from locals captured before the mutation and `fireProfile(player, "hudPrefRevert")` re-fires
state, so the ledger's optimistic switch flips back rather than leaving the player poking a control
that silently did nothing. Cache-before-PUT is kept (an intervening `fireProfile` would otherwise
echo the pre-write value and appear to undo the switch) — this is `SetPadPreference`'s exact shape:
mutate, persist, revert + re-echo on failure.

Not changed, per the explicit do-not-fix list: the post-yield cache repopulation after
`handlerQueue:clear` on leave.

## 2. `RequestLedger` overwriting `hudPrefs`/`hudSeenBeats` — FIXED (`db6e0b9`)

Dropped the four lines. `seedCounters` stays; the comment above the handler ("Only the counters are
taken from the response") is now true. The comment at the drop site records *why*: the GET was
already in flight when it was read, so a `SetHudPreference` write landing inside its latency window
would be overwritten by the pre-write value and echoed to the client. Both caches are now owned by
`SetHudPreference` for the life of the session and seeded once, at join.

## 3. Drum card projected in the wrong coordinate space — FIXED (`7721170`)

**Coordinate space chosen: GUI SPACE — this ScreenGui's own, i.e. inset space.**

Rationale: `HudController`'s ScreenGui leaves `IgnoreGuiInset` at its default `false`, and the
onboarding card's whole job is to sit beside what HudController placed. The static anchors (`plate`,
`throwArea`, `potIndicator`) are literally HudController's numbers. Flipping the onboarding gui to
`IgnoreGuiInset = true` would have made the projection agree while putting *those* anchors out of
step by the same inset — one bug traded for three. So the gui stays in inset space and the *world
projection* is converted into it.

`OnboardingController.client.luau` now has `guiCanvas()`, returning `(canvas, inset)`:

- `canvas` = `gui.AbsoluteSize` (the layout area by definition), falling back to
  `ViewportSize - inset` when it reads `(0,0)` before the first layout pass.
- `inset` = `GuiService:GetGuiInset()`.

`place()` subtracts the inset from `WorldToViewportPoint`'s result before clamping, and
`safeYBounds` takes the canvas rather than the viewport, so `maxY` is measured against the space the
card actually lives in. I converted explicitly rather than swapping in `WorldToScreenPoint` so the
correctness does not rest on which of the two API names is the inset-aware one — the subtraction is
verifiable in the file. Two consequences fixed: the bubble now lands on the drum instead of ~36px
below it, and the safe band's bottom bound is no longer an inset too permissive over the
throw/slot cluster.

## 4. Ledger cards overflow on a landscape phone — FIXED (`3842e01`)

Structural, as instructed. **No breakpoint touched** — `NARROW_PX = 900` is byte-identical, left for
the device-emulator sweep.

- `panel.ClipsDescendants = true` — the backstop, so the panel's outline means something and nothing
  draws over the scrim or the world.
- `makeCard` now returns a third value: a `ScrollingFrame` body (`Content`) below the card's heading
  strip (`CARD_HEADING_H = 20`), with `ScrollingDirection = Y` and a 4px bar. `card.ClipsDescendants`
  set too.
- All three cards' content reparented into their body and rebased to body-relative offsets:
  Lifetime (`LIFETIME_TOP = 4`, `LIFETIME_ROW_H = 30`, bar and legend derived, canvas stated as
  `LEGEND_TOP + LEGEND_H + 4` = 199), Your Throws (`MIX_TOP = 8`, `MIX_ROW_H = 46`, canvas 146), Feed
  (its pre-existing `AutomaticCanvasSize = Y` moved onto the shared body — it grows a line at a time,
  so its canvas is measured, not stated). Fixed-width rows shortened by 6px to clear the scrollbar.

Result: on a short body band the figures scroll instead of spilling through the footer, and no
figure becomes unreachable on a small screen.

**`Active` discipline preserved.** `.Active = true` still appears exactly once in the branch
(`panel.Active`, the takeover carve-out) — verified with `grep -rn "\.Active = true" roblox/src`. A
`ScrollingFrame` drags to scroll without it, and the file's pre-existing feed scroller was already
built that way.

## 5. First `Onboard("join")` racing the profile fetch — FIXED (`c305b5e`)

`main.client.luau`: new `profileSeen` latch, set unconditionally in the `ProfileUpdate` handler (an
answer of "no beats seen" is a real answer — a genuine first-timer), and the join fire is now
`if not resolved.join and profileSeen then`. Because `join` re-fires on every `RoundUpdate` until
resolved, the very next round tick after the profile lands shows the card — nothing else needed
wiring. If the join fetch fails outright the card is skipped for that session, which is the right
trade and is written into the comment: a first-timer missing one card beats a returning player being
re-taught all four, latched.

Only `join` is gated, per the finding. The other three beats fire from events that are themselves
downstream of a reveal or a bank, and gating them would have been scope the review did not ask for.

## 6. Stale win-gate comments — FIXED (`1cebe95`)

Prose only; no assertion or behaviour changed.

- `server/src/engine/Settlement.ts` — the `buildCounterUpdate` comment now states what
  `unresolvedWin` means today ("the last scored round was a WIN and the player has not banked
  since"), that nothing is blocked by it, that riding is throwing again, and that it drives the pot
  indicator's pulse — which is why it must clear on SAFE, LOSS and bank.
- `server/src/models/models.test.ts` — the "after choosing RISK the pot still rides" note rewritten
  around the real reason the field is independent of `pointsAtStake`: a pot rides after a WIN and
  equally after a SAFE.
- `roblox/tests/PlayerProfiles.spec.luau` — `describe("PlayerProfiles — the win gate")` →
  `describe("PlayerProfiles — unresolvedWin, the pot indicator's pulse")`, with a header comment
  recording the withdrawal; test names "raises the gate" → "sets it optimistically", "clears it —
  nothing left to decide" → "clears it — the pot is forfeit, there is nothing to pulse for",
  "defaults to unbound" → "defaults to no unresolved win".

## 7. `AREA_H = 120` duplicated — FIXED, single-sourced (`7721170`)

New `roblox/src/shared/HudLayout.luau` is the source of truth. It is a `src/shared` module and obeys
that folder's contract: plain numbers, no Roblox globals, no `require` of a sibling, Lune-testable —
a *constants* module, never a UI one.

It holds only the skeleton both files need: `JUMP_CLEARANCE`, `EDGE`, `PLATE_H`, `TILE`, `ROW_GAP`,
`BTN_H`, `SLOT_H`, `SLOT_GAP`, plus the three derived numbers `AREA_H`, `PLATE_BOTTOM` and
`CLUSTER_TOP_FROM_BOTTOM` — the last two being the safe band itself, so the band is now derived from
the layout rather than restated beside it. Numbers only one file uses (`PLATE_W`, `BTN_W`/`BTN_GAP`,
`TILE_GAP`, timer/toast sizes, card widths) stayed local to that file.

`HudController.client.luau` now assigns its locals from `HudLayout` (so its existing body is
untouched) and `OnboardingController.client.luau` does the same, including its `plate` anchor which
reads `HudLayout.PLATE_BOTTOM + 60`. The hand-computed `120` and the mirrored `PLATE_H`/`EDGE` are
gone.

New `roblox/tests/HudLayout.spec.luau` (5 tests) asserts the derived values are *derived* —
`AREA_H == TILE + ROW_GAP + BTN_H`, and likewise for the two band constants — so re-freezing one as
a literal fails CI. It also checks the band is non-degenerate at 375px and that the module holds
nothing but numbers (the Lune-safety contract).

## 8. Untimed `WaitForChild("PlayerScripts")` — FIXED (`3842e01`)

`LedgerController.client.luau`: `player:WaitForChild("PlayerScripts", 10)`, with
`playerScripts and playerScripts:WaitForChild("PlayerModule", 5)` after it, and a third warn branch
for the "PlayerScripts never arrived" case. Degrades to the existing WalkSpeed freeze, and — the
point of the finding — execution reaches the `EventBus.OpenLedger` connection at the bottom of the
file, so the plate never becomes a dead button. A comment above the block records that every
`WaitForChild` here must stay timed and why.

---

## Verification

Roblox, from `roblox/`:

```
stylua --check src tests tools   # clean
selene src tools                 # 0 errors, 0 warnings, 0 parse errors
lune run tests/run               # 876 passed, 0 failed, 876 total  (871 before; +5 HudLayout)
rojo build -o <scratch>/skeleton.rbxl   # builds (written outside the repo; no place file committed)
```

Server, from `server/`:

```
npm test          # 13 files, 208 passed
npx tsc --noEmit  # clean
```

`git status` clean; no `.rbxl`/`.rbxlx` anywhere in the tree; `docs/superpowers/`,
`shared-fixtures/game-rules.json`, both `GameRules` implementations, `DayNightLockT` and
`PreNightTestLockT` untouched.

## Untouched by design

Everything on the do-not-fix list: the `View.slot` string type, `aux.timerKnown ~= false`, the
toast-queue FIFO backlog, aged-tape-tile glyph contrast, `pendingBankToast`'s single slot, the
post-yield cache repopulation, `RequestLedger`'s per-player-only debounce, and the close button's
`"X"`.

## Concerns

Two things want eyes in Studio during the device-emulator sweep, neither blocking:

1. **#3 is a live-projection change and has no test** — the harness cannot construct a `Camera` or a
   `GuiService` inset. The arithmetic is straightforward and the constants it depends on are now
   tested, but "the bubble sits on the drum" is a look-at-it check.
2. **#4's card canvases are stated, not measured** (199px Lifetime / 146px Your Throws). They match
   the layout as written, but if a future edit adds a row without updating the canvas the new row
   scrolls out of reach rather than overflowing visibly — a quieter failure than the one just fixed.
   Deriving them from an actual `UIListLayout` would remove that class of bug and is a reasonable
   follow-up during the sweep, when the rows are being looked at anyway.

---

# Addendum — re-review wave (`ccf8525`)

The re-review passed seven of eight and rejected **finding 5**, correctly. My rationale for it was
factually wrong, and my fix for **finding 2** had introduced a regression on top. Both are now
closed by one commit, `ccf8525` — *fix(roblox): the ledger refresh repairs the HUD caches again, and
no beat fires blind*.

## What I got wrong

I wrote that "if the join fetch fails the server never fires ProfileUpdate at all". It does.
`fireProfile` is called from `main.server.luau` on every reveal (`"local"`) and every reconciliation
(`"reconciled"`), neither of which depends on the join GET. After a failed join fetch
`hudSeenBeats[uid]` is nil, and `fireProfile` was sending `seenBeats = hudSeenBeats[uid] or {}` — so
the first reveal handed the client an empty list, my `profileSeen` latch flipped on it, `join` fired,
`OnboardShown` latched, and all four beats re-showed. My latch closed the timing race and nothing
else.

Underneath both mistakes is one modelling error: **"the profile has not answered" and "the profile
says nothing was seen" were the same value.** They are different answers and the client must act on
them differently.

## The two fixes

**Server — `nil` is now a distinct answer.** `fireProfile` sends `seenBeats = hudSeenBeats[uid]`,
without the `or {}`. An empty list still means what it should (a genuine first-timer, teach them);
absent means the server does not know, and the client teaches nothing.

**Server — the ledger refresh repairs the caches again, under a write-sequence guard.** Finding 2's
diagnosis was right (a blind overwrite from a stale in-flight GET flipped the switch back) but
discarding the response wholesale deleted the only self-heal `hudPrefs`/`hudSeenBeats` had: they are
otherwise written once, by the join fetch inside its `if res.ok`. New `hudWriteSeq: {[string]:
number}`:

- `SetHudPreference` bumps it on every accepted fire — *before* the `handlerQueue` wait and before
  the PUT, both of which yield, so the guarded window covers the write's whole life rather than just
  the cache mutation.
- `RequestLedger` reads it into `seqAtFetch` before the GET and compares after. Equal → apply
  `escalationPrompts` and `seenBeats` from the response. Changed → skip those two fields (the write
  is what the database now holds) while still seeding the counters and firing `ProfileUpdate`.
- Cleared in `PlayerRemoving` alongside the other per-uid caches.

A raced refresh now yields to the write instead of clobbering it *or* throwing the response away.
The handler's comment block was rewritten to describe exactly this — the stale comment is what got
it flagged the first time, and I had left the new one describing a policy ("only the counters") that
was itself the regression.

**Client — all four beats wait on `profileSeen`, which now means "answered".** `profileSeen` is set
only inside the `type(p.seenBeats) == "table"` branch. The `throwsUnlocked` and `win` fires got the
same guard `join` had; every beat fires on a repeating occasion (join on each RoundUpdate,
throwsUnlocked on each round's rising edge, win on each win), so the first occurrence after the
profile lands still shows the card. The `bank` path takes the **immediate-toast** branch when
`not profileSeen` — `if resolved.bank or not profileSeen then toast(...)`. That is load-bearing:
with the beat suppressed there is no ack coming, so routing the line through `pendingBankToast`
would have banked in silence. The `seenBeats` block runs before the `bankedNow` block in the same
handler, so a payload carrying a real list has already latched by then.

Recovery story, end to end: join GET fails → server knows nothing → client teaches nothing and
asserts nothing → the player opens the ledger → the refresh repairs both caches from the
authoritative profile → the next `ProfileUpdate` carries a real list → beats and the preference
switch resume correctly, no rejoin needed.

## Left alone, as instructed

- New issue #2 (revert path writes caches after an HTTP yield; a player leaving mid-PUT leaks one
  entry). The `player:IsDescendantOf(Players)` guard on the `fireProfile` re-echo was already there
  and stayed; I did not restructure the cache writes around it.
- New issue #3 (~28px scroll window over the 199px Lifetime canvas on an 812×375 phone). Untouched,
  and no threshold moved — `NARROW_PX` is still byte-identical. It goes to the device-emulator sweep.
- Trivia taken: `guiCanvas` now carries a comment noting `GetGuiInset` returns `(topLeft,
  bottomRight)` and that only the topLeft is used. The feed's 2px content shift stands.

## Verification (addendum)

From `roblox/`: `stylua --check src tests tools` clean, `selene src tools` 0 errors / 0 warnings /
0 parse errors, `lune run tests/run` **876 passed, 0 failed**.
From `server/`: `npm test` **13 files, 208 passed**.

One caveat worth recording: the first `npm test` run of this wave reported 1 failure out of 208, and
three consecutive re-runs were fully green (the failing run also took 23.8s against a normal 4.1s,
which reads as a timing-sensitive test rather than a logic failure). No server TypeScript was touched
in this wave — the only server changes on the branch are the two comment edits in `1cebe95` — so this
is a pre-existing flake, not a regression. It is worth someone identifying if it recurs in CI.
