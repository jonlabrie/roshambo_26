# Task 13 report — onboarding beats on screen

Commit: `ed2de99` — feat(roblox): four event-triggered onboarding beats

**Note:** round 1 review found real quality issues in this initial pass — see "Round 1 fix"
(commit `e5e8e75`) at the end of this report. In particular, "The duplicated bank copy" section
below describes the original (superseded) approach; the fix section explains what replaced it
and why. Round 2 (commit `76eba76`, also appended at the end) closed three smaller residuals the
re-review found in round 1's own fix.

## What was built

- **`roblox/src/client/OnboardingController.client.luau`** (new) — one dismissable card at a
  time, rendering `OnboardingBeats.next(seenLocal, event)`. Never decides which beat fires.
- **`roblox/src/client/main.client.luau`** — fires `EventBus.Onboard(event, seenBeats)` exactly
  once per event, for the four trigger points in the brief.
- **`roblox/src/shared/OnboardingBeats.luau`** — one-line anchor rename (`choiceOverlay` →
  `potIndicator`), see below.
- **`roblox/src/server/main.server.luau`** — threaded `seenBeats` through `ProfileUpdate` /
  `SetHudPreference`, which nothing did yet (see "Gap found" below).

## The four anchors

1. **`drum`** — the drum is a real object in the world
   (`Workspace.RoshamboStage.ThrowDrum.Drum`, per `DrumController.client.luau`), not a HUD
   element. Rather than guess a fixed screen fraction, the card **live-tracks it via
   `Camera:WorldToViewportPoint`** (a `RunService.Heartbeat` connection, started when the card
   shows and disconnected when it dismisses), rendering as a speech-bubble clamped inside the
   viewport just above the projected point. Falls back to a fixed top-centre position if the
   part hasn't resolved yet (10s `WaitForChild` timeout, defensive) or is off-camera. No
   precedent for `WorldToViewportPoint` existed elsewhere in the codebase — I judged this
   correct rather than over-built because "point at the drum" cannot be done honestly with a
   fixed offset, and Task 13 explicitly leaves Studio verification to the controller, so getting
   the mechanism right mattered more than guessing a number I can't see.
2. **`throwArea`** — fixed screen-space, anchored bottom-right in the same column as the throw
   buttons, sitting **above the whole tape+buttons+slot cluster** (not just above the tape).
3. **`potIndicator`** (was `choiceOverlay`) — same offset as `throwArea`. They're never shown at
   once, so sharing the spot costs nothing and is one fewer number to keep in step.
4. **`plate`** — fixed, centred below the plate, clear of both the plate button and the toast
   strip.

## `choiceOverlay` → `potIndicator`

Per the brief, I anchored the win beat at the pot indicator (the slot above the throw row, which
took over the withdrawn RISK/BANK overlay's job). Rather than silently mapping the stale
`choiceOverlay` string to that spot inside my own file, I renamed it in `OnboardingBeats.luau`
itself with a comment explaining why — `OnboardingBeats.spec.luau`'s tests only assert
`#b.anchor > 0`, never the literal string, so nothing broke. `lune run tests/run` confirms
(871/871 pass).

## Overlap bug caught in self-review

My first pass gave `throwArea` an offset that only cleared `ROW_GAP + SLOT_GAP` above the tape,
not the slot's own height. The slot Frame occupies that space in the layout **whether or not
its pot/fate tenant is visible** — HudController only toggles children, never repositions the
row. Since beats don't queue, a card can outlive a later dropped event: if a player ignores
"Tap a throw" long enough to win on their first throw, the pot slot (with a live BANK THESE
button) turns on **while the throwArea card is still up**, and my card — ZIndex 5, above the
slot's default — would have sat on top of it and stolen its taps. Fixed by giving `throwArea`
the same full-cluster offset as `potIndicator`.

## The duplicated bank copy

The bank toast (`💰 BANKED {n} — that's yours to keep`) says almost exactly what beat 4's card
says, and — worse — both would have rendered in the *same screen slot* below the plate on a
first bank. I suppressed the toast only on the one occasion the beat will actually appear
(`OnboardingBeats.next(knownSeenBeats, "bank") ~= nil` and not already fired this session,
computed in `main.client.luau`, reusing `OnboardingBeats.next` as the single source of truth
rather than re-deriving the decision). Every later bank keeps the toast unchanged — it's the
only place the banked *amount* is said.

**Superseded in round 1** — this synchronous prediction was the root cause of the review's two
Important findings. See "Round 1 fix" below.

## Gap found: `seenBeats` never reached the client

The brief's "Consumes" line lists "the profile's `seenBeats` list," but grepping the server found
`ProfileUpdate`'s payload (`fireProfile` in `main.server.luau`) never carried `seenBeats` —
Task 9 wired `unresolvedWin` through but not this. I added a `hudSeenBeats` per-instance cache
mirroring the existing `hudPrefs` pattern exactly: seeded on join and on ledger refresh from
`net:getPlayer`'s response (the Node backend, tasks 2/5, already returns `seenBeats`), included
in every `fireProfile` call, and kept in step (add-only) inside `SetHudPreference`'s handler so
an intervening `ProfileUpdate` can't echo a stale list back. This wasn't in the brief's file list
but is required for the stated interface to actually work; flagging it here rather than having
silently expanded scope.

`seenBeats` rides alongside every `EventBus.Onboard:Fire(event, seenBeats)` call rather than a
new bus channel — `OnboardingController` merges it into its local `seenLocal` on every fire
(each of the four events fires at most once per session, so this is cheap and self-correcting
regardless of whether `ProfileUpdate` or the triggering event lands first).

## Elements created and their `Active` state

- `RoshamboOnboarding` ScreenGui (DisplayOrder 10 — above the HUD's 0, below the ledger's 20).
- `Card` `TextButton` — the one interactive element; buttons always sink input regardless of
  `Active`, and it's the dismiss target (`MouseButton1Click`).
- `Copy` `TextLabel` (child) — `Active = false`, explicit.
- `Hint` `TextLabel` (child, "TAP TO DISMISS") — `Active = false`, explicit.
- `UICorner`, `UIStroke`, `UIPadding`, `UIListLayout` on the card — non-interactive layout/decor.

Nothing else. One button total, matching the "exactly one slot button" discipline the rest of
the HUD holds itself to.

## Self-review answers

- **Can two cards ever be up at once?** No — `currentBeat ~= nil` is checked before any new beat
  is even looked up in `OnboardingBeats.next`; a qualifying second event is dropped, not queued,
  by construction (one reused `Card` instance, not a list).
- **Can a card cover the control it points at?** No, after the fix above — `throwArea` and
  `potIndicator` both clear the full slot footprint (buttons + tape + slot), and `plate`'s card
  sits below the plate. One residual soft risk: the `plate` card and the toast strip both live in
  roughly the same vertical band below the plate; toast is non-`Active` so it can never steal
  input, but a very long wrapped toast could visually brush the card's top edge. Cosmetic only,
  worth a look in the Studio pass.

## Gates

`stylua --check src tests tools && selene src tools` — clean (0 errors, 0 warnings, after fixing
4 `UDim2.new` → `UDim2.fromOffset`/`fromScale` selene warnings).
`lune run tests/run` — 871/871 pass (no regressions; `OnboardingBeats.luau`'s own tests don't
hardcode the renamed anchor string).
`server/` Vitest suite untouched (no files under `server/` changed).

## Not done (explicitly out of scope)

Studio verification (Step 3) — per the brief, that's the controller's job.

---

## Round 1 fix (commit `e5e8e75`)

Review verdict: spec ✅, quality: needs work. Two Important findings shared one root cause, plus
a second Important and three Minors. All addressed below.

### Root cause: latching on FIRE, not on SHOWN

`main.client.luau` set `seenXEvent = true` (and, for bank, pre-emptively suppressed the toast)
at the moment it *called* `EventBus.Onboard:Fire`, before `OnboardingController`'s never-stack
guard had run at all. So a beat dropped for stacking was marked consumed forever, having taught
the player nothing:

- **Bank with no toast and no card.** Win → beat 3's card comes up in the slot column → player
  taps BANK THESE without dismissing it (the card deliberately doesn't cover that button, so this
  is the expected flow) → `ProfileUpdate` lands, toast suppressed (predicted the card would cover
  it), `Onboard("bank")` fired → dropped, because beat 3's card is still up. `seenBankEvent` was
  already latched, so it never retried. The player's first bank told them nothing — not even the
  amount, which is said nowhere else.
- **Beat 2 usually never fires on a first session.** `join` fires, then `publish()` fires
  `throwsUnlocked` in the same call if the round is ACTIVE. The join card is up, so "Tap a
  throw." is dropped — and `seenThrowsUnlockedEvent` was already latched, so it moved to the
  player's *second* visit instead of their first.

**Fix — the controller now reports what actually happened.** Added `EventBus.OnboardShown`
(`roblox/src/client/EventBus.luau`), fired by `OnboardingController` with
`(event, outcome)` where `outcome` is `"shown"` | `"alreadySeen"` | `"dropped"`:

```lua
EventBus.Onboard.Event:Connect(function(event, serverSeenBeats)
    adoptServerSeen(serverSeenBeats)
    if currentBeat then
        EventBus.OnboardShown:Fire(event, "dropped")   -- retry later, never latch
        return
    end
    local beat = OnboardingBeats.next(seenLocal, event)
    if beat then
        showCard(beat)
        EventBus.OnboardShown:Fire(event, "shown")
    else
        EventBus.OnboardShown:Fire(event, "alreadySeen") -- nothing left to teach, stop asking
    end
end)
```

`main.client.luau` replaced its four one-shot `seenXEvent` booleans with a `resolved` table
(`join`/`throwsUnlocked`/`win`/`bank`), set `true` only by the `OnboardShown` listener, and only
on `"shown"`/`"alreadySeen"` — never on `"dropped"`. Each event now fires on **every natural
occurrence** while unresolved, not once ever:

- `join` — every `RoundUpdate` (in practice always resolves on the first call; nothing can be up
  before this client's first `Onboard` fire ever, so this is defensive consistency, not a real
  retry path).
- `throwsUnlocked` — a **rising edge** of `HudModel.view(...).throwsEnabled` (`wasThrowsEnabled`
  tracker), i.e. once per round, not once per 10Hz `publish()` tick. If dropped, retries next
  round.
- `win` — every `RevealResult` with `result == "WIN"` (still gated on drum-rest, unchanged). If
  dropped, retries next win.
- `bank` — every successful bank echo, but see below for the toast.

**Bank toast, redone.** Predicting "will the card show" synchronously no longer works once the
decision is genuinely asynchronous: `BindableEvent:Fire` is deferred in this engine, so there is
nothing to read back at the point `ProfileUpdate` lands. Once `resolved.bank` is true (the common
case — every returning player, every bank after the first) the toast is immediate and
unconditional. Otherwise the toast line is stashed in `pendingBankToast` and `Onboard("bank",
...)` is fired; the `OnboardShown` listener resolves it once the answer is in — showing the toast
unless the outcome was `"shown"`:

```lua
EventBus.OnboardShown.Event:Connect(function(event, outcome)
    if outcome ~= "dropped" then
        resolved[event] = true
    end
    if event == "bank" and pendingBankToast then
        local line = pendingBankToast
        pendingBankToast = nil
        if outcome ~= "shown" then
            toast(line)
        end
    end
end)
```

This also removed the need for `main.client.luau` to `require(OnboardingBeats)` at all — deleted
that require, since the only use was the now-gone synchronous prediction.

**Dedup nit.** `adoptServerSeen` in `OnboardingController` now checks membership before
inserting, since `seenLocal` is the re-fire guard `OnboardingBeats.next` reads and was growing an
unbounded duplicate every time an event fired for the whole session.

### Important 2: the drum card could track into live HUD controls

The join card is the first thing a new player sees, stays up until tapped, and the camera is
theirs to swing for as long as it's up — so `WorldToViewportPoint`'s raw projection could put the
card directly over the throw buttons, the slot, or the plate, and the `DisplayOrder 10` onboarding
`ScreenGui` would win every tap in the overlap unconditionally.

**Chose to keep live tracking, not fall back to a fixed anchor** — a fixed position can't
actually point at a real 3D object regardless of camera orientation, and the geometry problem was
fully fixable without giving that up. Fixed by clamping into the band the HUD does not own,
computed from the same layout constants the static anchors already use:

```lua
local PLATE_BOTTOM = EDGE + PLATE_H                                  -- 58
local CLUSTER_TOP_FROM_BOTTOM = EDGE + AREA_H + ROW_GAP + SLOT_H     -- 182
local SAFE_MARGIN = 16
```

`minY = PLATE_BOTTOM + SAFE_MARGIN + cardH` and `maxY = max(minY, vp.Y - CLUSTER_TOP_FROM_BOTTOM
- SAFE_MARGIN)` (the latter `max` guards a degenerate tiny viewport where the two bounds would
otherwise invert), and `y` is clamped into `[minY, maxY]` before being used.

**Minor 1 (`AbsoluteSize.Y`).** `AnchorPoint` is `(0.5, 1)`, so the clamped `y` is the card's
*bottom* — the top is `y - cardHeight`, and that's the edge that actually has to clear the plate.
`minY` now adds `math.max(card.AbsoluteSize.Y, MIN_CARD_H)` (a 60px floor for the first frame or
two, before `AutomaticSize` has laid out even once) rather than a bare margin.

**Minor 2 (teleport-on-pan).** Introduced a `drumEverTracked` flag: the fixed fallback position
is shown only *before* the very first successful on-screen projection. Once the drum has been
tracked for real even once, going off-camera holds the last clamped position instead of snapping
to the fallback and back every frame as the camera pans through the edge.

### Minor 3: `hudSeenBeats` not cleared on `PlayerRemoving`

`hudPrefs`, `ledgerCounters` and `lastLedgerFetch` are all cleared in the existing
`Players.PlayerRemoving` handler in `main.server.luau`; `hudSeenBeats` was not, despite the
comment introduced in round 1 claiming it mirrors `hudPrefs` exactly. Added
`hudSeenBeats[tostring(player.UserId)] = nil` alongside the other three.

### Checks run

```
cd roblox
stylua --check src tests tools && selene src tools
lune run tests/run
```

Output: `stylua` — clean. `selene` — `0 errors, 0 warnings, 0 parse errors`. `lune run tests/run`
— `871 passed, 0 failed, 871 total` (unchanged from round 1; none of these files are Lune-tested
directly, only `src/shared` modules are, and none of those changed this round). `server/` Vitest
suite untouched — no files under `server/` changed.

### Files touched this round

- `roblox/src/client/EventBus.luau` — added `"OnboardShown"` to the bus.
- `roblox/src/client/OnboardingController.client.luau` — three-outcome `OnboardShown` ack,
  dedup in `adoptServerSeen`, drum clamp into the HUD's dead zone, hold-last-position on pan-off.
- `roblox/src/client/main.client.luau` — `resolved` table replacing the four one-shot latches,
  rising-edge detector for `throwsUnlocked`, deferred bank-toast decision, removed the now-unused
  `OnboardingBeats` require.
- `roblox/src/server/main.server.luau` — `hudSeenBeats` cleared on `PlayerRemoving`.

---

## Round 2 fix (commit `76eba76`)

Re-review verdict: every round-1 finding ADDRESSED, and specifically endorsed — the clamp band
was checked constant-by-constant against `HudController`'s real geometry, the inversion guard
was confirmed to also prevent a `math.clamp` error that would otherwise throw every `Heartbeat`,
and the `OnboardShown` protocol was walked for double-fires/unbounded retries and found clean on
all three paths. Three smaller findings remained, all in files already open; all fixed.

### 1. `DRUM_FALLBACK` was still un-clamped

Round 1's clamp fix only ran on the LIVE-PROJECTION path (`onScreen == true`). The NOT-YET-TRACKED
fallback — reachable in ordinary play, since `join` fires on the first `RoundUpdate`, which can
beat the `RoshamboStage → ThrowDrum → Drum` replication chain `drumPart` waits on — still used the
old fixed, unclamped `(0.5, 0)` at `y = 140`. On a phone-height viewport that overlaps the slot
row, reproducing the exact failure Important 2 already fixed for the tracked case, through a
slower door.

Fixed by extracting `safeYBounds(vp): (minY, maxY)` — the same computation round 1 built for the
live-projection branch — and running the not-yet-tracked fallback through it too, resting at
`minY` (closest to the plate, horizontally centred). Renamed the old constant `DRUM_LAST_RESORT`
and narrowed its meaning to what's actually left: no `workspace.CurrentCamera` at all, which does
not happen in a live game. There is now exactly one code path that can place a card un-safe-banded,
and it requires the absence of a camera to reach.

### 2. Bank toast had a hard liveness dependency on the ack

Round 1 made the toast decision asynchronous (deferred to `EventBus.OnboardShown`), which
introduced a new failure mode round 1 hadn't considered: if the ack never arrives —
`OnboardingController` dead, not yet connected, or erroring somewhere in its
`require`/`WaitForChild` block before it ever reaches `EventBus.Onboard:Connect` —
`pendingBankToast` strands forever, and since `resolved.bank` also never latches without the ack,
*every subsequent bank* goes silent too, not just the first.

Fixed with a `task.delay(BANK_TOAST_FAILOPEN_SECONDS, ...)` (1s) fail-open flush, captured by the
exact toast line and compared by value against the current `pendingBankToast` so it can't clobber
a newer pending toast the delay wasn't scheduled for. Under normal operation this is a no-op —
`BindableEvent` acks land on the next resumption, well under a second — and only fires if the
controller is genuinely gone. A missing onboarding controller must never silence banking; now it
can't.

### 3. `resolved[event] = true` was a dynamic index into a fixed-shape record

Under `--!strict`, the table literal `{ join = false, throwsUnlocked = false, win = false, bank =
false }` has no `[string]` indexer, so `resolved[event]` — indexed by whatever string
`EventBus.OnboardShown` echoes back — would silently create a new field for any typo or future
event name rather than being caught. Annotated `local resolved: { [string]: boolean } = { ... }`.

### Nits (fixed — genuinely trivial)

- `MIN_CARD_H`: 60 → 90, matching the card's real measured height (~80-90px) rather than
  under-clamping the very first `place()` call by a frame or two before `AutomaticSize` lays out.
- `SAFE_MARGIN`: 16 → 24, giving the drum card's minimum resting position (`minY`) more clearance
  from the toast strip. Noted as a one-line, low-confidence mitigation rather than a full fix:
  toast height is unbounded (`AutomaticSize.Y` + `TextWrapped`), so no fixed margin fully
  eliminates the visual-only overlap risk already logged in the original report's self-review —
  toast is non-`Active`, so this was never an input-stealing risk, only cosmetic.

### Checks run

```
cd roblox
stylua --check src tests tools && selene src tools
lune run tests/run
```

Output: `stylua` — clean. `selene` — `0 errors, 0 warnings, 0 parse errors`. `lune run tests/run`
— `871 passed, 0 failed, 871 total` (unchanged; no `src/shared` modules touched this round).
`server/` Vitest suite untouched — no files under `server/` changed this round.

### Files touched this round

- `roblox/src/client/OnboardingController.client.luau` — `safeYBounds` extracted and applied to
  the not-yet-tracked fallback; `DRUM_FALLBACK` renamed `DRUM_LAST_RESORT` and narrowed to the
  no-camera case; `MIN_CARD_H`/`SAFE_MARGIN` bumped.
- `roblox/src/client/main.client.luau` — `resolved` strictly typed `{ [string]: boolean }`;
  `BANK_TOAST_FAILOPEN_SECONDS` fail-open flush added around the deferred bank-toast decision.
