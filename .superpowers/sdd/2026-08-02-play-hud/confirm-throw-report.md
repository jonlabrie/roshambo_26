# Play-HUD punch list, round 2 — implementation report

Date: 2026-08-02 · Branch: `m4b-zendojo-art-pass`
Spec: `docs/superpowers/specs/2026-08-02-play-hud-design.md`
Predecessor: `.superpowers/sdd/2026-08-02-play-hud/gate-punchlist-report.md`

All four items implemented. Four commits:

| SHA | Subject |
| --- | --- |
| `5380b1b` | fix(roblox): grow the winner on the drum, not on the wire |
| `26953ae` | fix(roblox): raise the mobile throw targets to 44px, and reserve the confirm row |
| `b33607a` | feat(server): persist confirmThrows, the second HUD preference |
| `6d1364d` | feat(roblox): confirm a throw when points are riding, and hold the fate for the drum |

Gates, on the committed tree: `stylua --check src tests tools` clean; `selene src tools`
0 errors / 0 warnings; `lune run tests/run` **900 passed / 0 failed** (was 879 — 21 new);
`npm test` in `server/` **209 passed / 13 files**; `npx tsc --noEmit` clean.

---

## 1. The avatar grow

### Which approach, and why

**Delayed server-side**, not moved client-side. The client option is not actually available:
`applyGrow` writes the `BodyHeightScale`/`BodyWidthScale`/`BodyDepthScale`/`HeadScale`
`NumberValue`s under the winner's `Humanoid`, and those replicate **server → client only**. A
client-side trigger would grow the winner's avatar on the winner's own screen and nowhere else,
which is the opposite of what the moment is for — everyone in the arena is supposed to see who
won. Driving it from `drumRest` would therefore mean a new client→server remote, and the brief
rules a new remote out for the preference; adding one here to carry a cosmetic cue that the server
can already time itself would be worse than the problem.

### Where the drum's settle duration is actually defined

It **was not defined anywhere a third party could read**. It lived as two private literals in
`roblox/src/client/DrumController.client.luau` (`SPIN_SEC = 1.0`, `GLIDE_SEC = 2.0`) plus a third
in `roblox/src/client/HammerController.client.luau` — the `0.45` forward-swing tween, which
matters because `gongHit` (and with it the drum's kick) fires at **contact**, at the end of that
swing, not when the swing starts.

So the first thing this change does is *give it a definition*. All three now live in
`roblox/src/shared/DrumStep.luau` — the drum's existing shared, pure, Lune-tested module:

```
DrumStep.STRIKE_SWING_SECONDS = 0.45   -- strike instant -> gongHit (HammerController)
DrumStep.SPIN_SECONDS         = 1.0    -- constant spin  (DrumController)
DrumStep.GLIDE_SECONDS        = 2.0    -- decelerating glide -> drumRest (DrumController)
DrumStep.SETTLE_SECONDS       = 3.45   -- derived, not a literal
```

Both controllers now read those numbers instead of carrying their own, and
`roblox/tests/DrumStep.spec.luau` asserts `SETTLE_SECONDS` as a **derivation** of the three legs,
so a retimed spin or glide cannot leave a stale 3.45 behind on the server.
`DrumController`'s `STALL_MAX` is deliberately *not* in the sum: it is the exception path (waiting
on a late World Throw), and padding every round by it would make every grow late to cover a case
that hardly ever happens.

### The part that is not a constant

`DrumStep.SETTLE_SECONDS` measures from the **strike**, not from the reveal, and the gap between
them varies. Chasing it down: the round result becomes fetchable the instant ACTIVE closes
(`RoundEngine` picks the World Throw at the ACTIVE→TALLY edge and settles there), `RoundCoordinator`
polls every ~1–1.25s, and the strike is at the end of TALLY. So `onReveal` fires somewhere inside
TALLY — anywhere from the strike itself to a whole TALLY (2s) early. A flat `task.delay(3.45)`
would have been up to two seconds out, i.e. still early, i.e. still a spoiler.

The server already knows the answer, because it publishes the absolute strike instant for the
client metronome. `growDelaySeconds()` in `roblox/src/server/main.server.luau` reads
`RoundScheduleConfig.StrikeAtServerTime` back and returns
`clamp(strikeAt - now + SETTLE_SECONDS, 0, SETTLE_SECONDS + TallySec)`.

The clamp is load-bearing: once a round reaches REVEAL the coordinator republishes that attribute
as the **next** round's strike, a whole period away, so an unusually late result fetch would
otherwise schedule the grow ~25s out. The upper bound is the longest honest wait (a reveal that
arrived at the very start of TALLY) and `TallySec` is published beside the strike, so even the
bound is derived rather than guessed. The failure direction under the clamp is *late*, never early.

### Nothing can strand it

This is the strongest argument for the server-side option: **there is no cue to miss.** A
`task.delay` always runs. An absent or non-numeric attribute falls back to the bare settle span.
The clamp's floor is 0, i.e. "fire now". `applyGrow` re-checks the character and humanoid, so a
player who leaves or respawns inside the wait simply does not grow. The delay is measured **once**
per reveal, before the per-player loop, so every winner in the instance grows on the same beat.

---

## 2. ACCEPT YOUR FATE

`main.client.luau`'s `RevealTheater` handler no longer sets `fateBound` on arrival. It sets
`pendingFate`, and `maybeShowReveal` — the file's existing drum-rest gate — applies it, with the
same `REVEAL_SAFETY = 3` fallback the headline and the tape tile use. No parallel mechanism.

Three details worth flagging:

- **`pendingFate` is held separately from `pendingReveal`, not folded into it.** They arrive on
  different remotes — `RevealTheater` is arena-wide, `RevealResult` is per-player — with no
  ordering guarantee between them. A fate parked inside `pendingReveal` would be dropped on any
  round where the arena-wide event lost the race, and a fate that never lands leaves a player with
  no ACCEPT YOUR FATE button and no way out. It is likewise **not** cleared by `RoundUpdate`
  ACTIVE, for the same reason the predecessor left `pendingReveal` uncleared: the safety always
  consumes it within 3s.
- **`roundCouldThrow` now counts a pending fate as bound.** The drum rests a moment *into* the next
  ACTIVE, so reading `fateBound` alone at the round boundary would have marked a round the player
  is about to be held out of as one they could have thrown in — and the escalation's backoff would
  have scored it as an ignored round.
- **The known residual.** As the brief anticipated, the server's fate gate is not client-timed, so
  for the sliver between the round reopening and the drum settling a fate-bound player can tap a
  throw the server silently refuses. When the fate lands, `myPick` (and any pending selection) is
  cleared, so the tile stops lighting as though it had counted — the same treatment the whiff
  branch already gives. Splitting the visual from the gate (disabling throws early while hiding the
  prompt) was considered and rejected: "your throws are dead and we won't say why" is itself a
  loss spoiler.

`BoardController:160` was not touched, per the brief.

---

## 3. Mobile throw targets

`HudLayout.THROW_TOUCH_SCALE` 0.5 → **0.58**.

### Resulting touch-target size: **44 × 44 px** (76 × 0.58 = 44.08, rounded)

Everything downstream re-derives from that one lever: the cluster width
(3 × 44 + 2 × 8 = **148**), `AREA_H_TOUCH` (24 + 10 + 44 = **78**), and the onboarding safe band.
The tape tiles stay at 24px as the last pass left them.

`roblox/tests/HudLayout.spec.luau` gains an assertion that `BTN_H_TOUCH >= 44` as a **floor**, not
an equality — raising the scale later is not a test failure, dropping back under 44 is.

### The onboarding safe band still clears the cluster — confirmed

`OnboardingController` derives `safeYBounds`'s `maxY` and its static anchors from
`HudLayout.CLUSTER_TOP_FROM_BOTTOM(_TOUCH)`; nothing in it carries a literal, so the band tracked
the resize automatically. The specs assert the derivation rather than the value, so a future tweak
to `BTN_H` or the scale cannot re-freeze one and not the other.

I did add one thing to the band: **the confirm strip's row is now reserved in
`CLUSTER_TOP_FROM_BOTTOM`**, on exactly the principle the slot already follows ("the slot's frame
occupies its space whether or not its tenant is visible"). This was not cosmetic bookkeeping — the
strip appears when `pointsAtStake > 0`, and the onboarding "win" beat's card fires on the same
win that creates the first pot, so a card landing on the strip was a live collision, not a
hypothetical.

Net numbers, both tiers, on the 375px-tall landscape phone the spec targets:

| | before this pass | after |
| --- | --- | --- |
| `CLUSTER_TOP_FROM_BOTTOM` (desktop) | 182 | 218 |
| `CLUSTER_TOP_FROM_BOTTOM_TOUCH` | 182 | **176** |
| usable onboarding band, touch, 375px viewport | 135 | **141** |

The touch band is still larger than it was before the last pass's shrink *and* larger than the
desktop band, so no card is squeezed. The reservation costs 36px of the 48 the touch tier gave back.

---

## 4. Confirming a throw

### The rule as I read it — please correct if wrong

> **Confirmation is required only when `pointsAtStake > 0`.**

I read the owner's "especially if there's points riding on the throw" as the **condition**, not as
emphasis on a rule that otherwise always applies. Roshambo is an ambient hangout and most throws in
the canyon cost nothing; making every one of those a two-tap ritual would tax the calm case to
protect the rare one, and a mis-tap only costs something when there is something to lose. So: no
pot, one tap throws.

The rest, as specified: first tap selects, second tap on the **same** glyph commits, a tap on a
**different** glyph moves the selection (a correction must not itself count as the confirmation),
an unconfirmed selection auto-commits at lockout, and `confirmThrows` (default on) turns it off.

### Where it lives

`roblox/src/shared/HudModel.luau`, pure and Lune-tested, with three additions:

- `HudModel.confirmRequired(inputs)` — `confirmThrows and pointsAtStake > 0`.
- `HudModel.tapAction(inputs, symbol)` → `"commit"` / `"select"` / `"ignore"`.
- `HudModel.autoCommit(inputs)` → the symbol that must be thrown now, or nil.
- View fields `selected` (the glyph to light) and `confirmPending` (whether to ask).

`Inputs` gains `confirmThrows: boolean` and `selectedThrow: string?`.

Two deliberate asymmetries, both tested:

- **`selected` and `confirmPending` are separate**, because they come apart. Banking mid-selection
  ends the *requirement* to confirm without ending the *selection*: the tile stays lit, the strip
  drops, and the next tap commits.
- **`autoCommit` is not gated on `confirmRequired`**, for the same reason. Dropping a selection
  because the player banked would silently cost them exactly the round they were mid-decision on.
  A fate arriving mid-round *does* drop it — the server will refuse that pick whatever the client
  does, and lighting a tile the server threw away is a lie.

`AUTO_COMMIT_AT = 0.5` seconds remaining, not zero: `secondsLeft` reaching zero **is** the lockout,
and the pick still has to travel client → `SubmitPick` → `ThrowBuffer` and be flushed. The
half-second is that slack. There is also a phase-exit branch: if ACTIVE ends with a selection still
pending (the unsynced-clock path reports a constant nominal countdown that never reaches the
boundary), it is committed anyway as a last resort — the server may refuse it as `PICKS_CLOSED`
and the existing whiff toast then says so honestly, which beats never trying.

`main.client.luau` acts on the answers and owns nothing of the rule: it holds `selectedThrow`,
builds the model's `Inputs` in one place (`buildInputs`), routes every accepted tap through
`HudModel.tapAction`, and runs `HudModel.autoCommit` in its existing 10Hz heartbeat. `commitPick`
is the single place a pick leaves the client, so neither path can forget to clear the selection.
**No new EventBus channel and no new remote** — `HudController` still fires `EventBus.HudPick` on
every accepted tap and the model decides what that tap means; a "select" is just a publish with
`selectedThrow` set.

**20 new `HudModel` tests**, covering every case the brief asked for plus the boundary
(0.6s → hold, 0.5s → commit), the fate drop, the bank-mid-round case and the ignore cases.

### The affordance: the transient strip — and why

I took **the strip**, not the on-button line.

The deciding number is the one item 3 just set: the touch button is **44px wide**. "TAP AGAIN" is
nine characters; across 44px that is roughly 9px type, on a phone, at arm's length, for a
kid-first audience, during the one moment in this HUD that has to be unmistakable — points are
riding, they have tapped, and nothing has been thrown. A hint the player cannot read converts the
confirm from a safety net into a fresh instance of the "I tapped and nothing happened" report the
last gate was about, which is a strictly worse outcome than having no confirm at all. It also
gives the owner's "don't ask me this again" a home at the moment it is actually wanted, instead of
only three taps away inside the ledger.

What it costs, and how each cost is contained:

- **Geometry.** It sits one row *above* the slot (which the pot indicator occupies precisely when
  confirmation is active), so it covers neither the throws, the tape nor the slot. Right-aligned
  with the cluster, inboard of the jump button, 288 × 28.
- **The onboarding band.** Its row is reserved permanently in `HudLayout` (see item 3), so a card
  can never be clamped on top of it.
- **`.Active`.** Untouched. The strip and its labels are Frames/TextLabels at the default false;
  the "don't ask again" control is a `TextButton`, which takes input by being a button rather than
  by being made Active. `grep '\.Active = true' src/` still returns exactly one line —
  `LedgerController.client.luau:247`, the ledger panel.
- **The dead zone** exists only between a player's first and second tap, and vanishes the instant
  they commit.

One behavioural choice inside it: tapping "don't ask again" turns the preference off but does
**not** throw the pending selection. The tile stays lit, the strip drops, and one more tap commits.
Doing both on one press would be a control that quietly threw a throw.

### Persistence

- `server/src/models/User.ts` — `confirmThrows: boolean`, `default: true`, beside
  `escalationPrompts`/`seenBeats`.
- `buildProfilePayload` exposes it defaulted with `?? true` (no migration was run).
- `PUT /players/:id/preferences-hud` accepts it and returns it. Three server tests added/updated,
  including one asserting that writing one preference leaves the other untouched.
- Roblox: it rides `ProfileUpdate` beside `escalationPrompts`, and the existing `SetHudPreference`
  remote writes it. **No new remote.** The instance cache became one **row** per player rather than
  a bare boolean, so the two preferences cannot drift apart on leave or on the ledger refresh, and
  a body naming only one of them merges rather than resetting the other to its default. The write
  path clones before mutating — the failure-revert holds the pre-write row, and an in-place edit
  would have rewritten its own undo.
- `LedgerController`'s footer gains its **second switch** ("Confirm big throws"). Both are built by
  one factory rather than copied, so a third cannot drift into looking or behaving differently.
  `FOOTER_H` was already sized for it; no re-layout was needed.

---

## Self-review notes

- `.Active = true` count across the branch: still exactly 1 (`LedgerController:247`).
- Every glyph still renders through `Glyphs`; no Unicode R/P/S character introduced.
- `src/shared/HudLayout.luau` still holds only plain numbers, no Roblox globals — the guard test
  that iterates it passes. `HudModel` and `DrumStep` stay pure and dependency-free.
- `shared-fixtures/game-rules.json`, both `GameRules`, `DayNightLockT` and `PreNightTestLockT` were
  not touched. No `.rbxl`/`.rbxlx` committed.
- The `growDelaySeconds` clamp fails **late**, never early: if a result fetch is late enough that
  the published strike has already rolled to the next round, the grow lands up to ~2.5s after the
  drum rests instead of before it. Late is a beat that misses; early is a spoiler.
- The unsynced-clock auto-commit path (phase leaves ACTIVE with a selection pending) will light the
  tile for a pick the server may refuse as `PICKS_CLOSED`; the whiff toast clears it on the next
  reveal. Rare, and the alternative is silently losing a round the player meant to throw in.
- Studio verification is the controller's. Nothing here has been looked at in-engine.
