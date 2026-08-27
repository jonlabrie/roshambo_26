# Round four — final fix wave

Two commits:

- `339d0dd` — fix(roblox): the wallet arrives on join, it does not count in
- `a3da900` — fix(roblox): the drum's kick lives with its other timings, and the header tells the truth

Gates, from `roblox/`: `lune run tests/run` → **982 passed, 0 failed**;
`stylua --check src tests tools` → clean; `selene src tools` → **0 errors, 0 warnings,
0 parse errors**. Run once after each commit's content was in place.

---

## 1. CRITICAL — every join opened with a gold celebration of nothing

### How the profile-known fact is carried, and where it went

`main.client.luau`'s `publish()` now puts `profileSeen = profileSeen` into the **`aux`**
table on `EventBus.HudState:Fire(inputs, aux)`. No new channel, no second flag in the
controller's own scope — it travels the same path `session`, `tape`, `timerKnown` and
`worldThrow` already travel.

**Why `aux` and not `HudModel.Inputs`.** `HudModel.view` derives nothing from it. The model
is the pure view-model of the *game* — phase, wallet, pick, escalation — and `profileSeen`
is not a fact about the game, it is a fact about the **wiring**: whether the numbers in
`inputs` are the server's answer or main.client's placeholder zeros. `aux` already holds
exactly that class of fact, and `timerKnown` is its precedent (also a "the wire has not told
us yet" boolean, also render-only, also deliberately kept out of the model). Putting it in
`Inputs` would have widened an exported type — and every fixture and test that constructs
one — for a field the model never reads.

### The fix in `HudController.client.luau`

- A file-scope `countersSeeded` latch, declared beside `lastPlatePoints`/`lastPlateStreak`,
  above `render` (its only reader).
- `render` seeds on the first pass where `not countersSeeded and aux.profileSeen == true`,
  and sets a local `seededNow` for that one pass.
- The plate's change-guard gained `not seededNow`. On the seeding render `view.plate.points`
  legitimately differs from the previous (zero) value, so without this the plate would still
  reveal itself unprompted on join — the "normally hidden" rule broken on arrival, which the
  defect report names explicitly alongside the count.
- `seedCounter`'s header rewritten: it no longer says "the first `render` seeds", because that
  was the whole error. It now names the 10Hz-from-script-load publish, the HTTP round trip
  the real profile waits on, and `aux.profileSeen` as the actual test.
- The file header's `aux` contract updated to list `profileSeen`.

`lastPlatePoints == nil` stays as the guard for the genuine first render; it is no longer
doing double duty as a "profile has answered" test.

### Result on join

No count and no celebration, for any balance or pot. On the seeding render `seedCounter` sets
`displayed = target = from` and `startedAt = nil`; `paintCounters` then finds the target
unchanged, so `tickCounter` does not re-key, `pointsCounter.startedAt` stays nil, and
`setCelebrating(false)` hits its early-return latch (already false). The bank button shows the
real pot immediately rather than counting up to it. The plate stays hidden.

### A real first bank still celebrates

The seed happens once and only once — `countersSeeded` latches, and `aux.profileSeen` staying
true forever afterwards cannot re-seed. Every subsequent `render` runs exactly the code it ran
before this change: a bank moves `view.plate.points`, `tickCounter` re-keys off the changed
target, `startedAt` is set, `pointsCounter.target > pointsCounter.from` is true, and
`setCelebrating(true)` lifts the rim and takes the figure gold while the bank button's figure
drains. The plate reveals (its guard sees `seededNow == false` and a genuine change) and holds
for `plateHoldSeconds()`. Nothing on that path was touched.

### If the profile never arrives

`profileSeen` is set in exactly one place — the `type(p.seenBeats) == "table"` branch of
main.client's `ProfileUpdate` handler — and on the server `hudSeenBeats` is populated only
inside the join fetch's `if res.ok`, the **same block** that calls `profiles:applyServer` with
the real wallet. The two facts are co-extensive: a failed fetch means no seenBeats *and* no
wallet.

So on a failed fetch the flag stays false, nothing is ever seeded — and that is correct rather
than stuck:

- The counters are not gated on the seed. `tickCounter` runs unconditionally from
  `paintCounters` every render; seeding only pre-sets where a count would start *from*.
- The wallet in that state is genuinely zero, because the fetch is what fills it. Every later
  move (a reveal's locally-computed result, a bank) is therefore a real move from a real base
  of zero, and *should* count and *should* celebrate.
- `seededNow` is false on every render in that path, so the plate's change-guard behaves
  exactly as it does today — reveals on every genuine change, first render excepted.

The HUD is never left refusing to count; it simply never gets the one-time "you arrived with
this much" shortcut, which in that state would be a lie anyway.

---

## 2. `DrumStep.SPLASH_LEAD_SECONDS` — the comment now describes the curve that exists

Corrected to: a **Hermite** — smoothstep plus the spin's exit velocity carried in — covering
**83–88%** of travel at 0.7s from rest, the spread being the travel `landTargetFor` picks
(D ∈ [ω·G/2, ω·G/2 + π/2), the largest D being the worst case because the fixed velocity term
is then the smallest share of it). The 72% a bare smoothstep reads is called out as the wrong
way to reason about the lead, with a pointer to the spec that computes both terms.

Added, per the review: **fraction of angular travel is not the same criterion as "the correct
symbol is in the window."** At this lead the residual angle is 28° (best) to 53° (worst) with
facets 30° apart, so the window still shows a neighbouring facet for 0.19–0.34s after the cue.
Recorded as a known owner-facing trade, explicitly not a defect to fix here, with the
instruction not to "improve" the lead without pricing it in.

`SPLASH_LEAD_SECONDS`'s value is untouched.

## 3. `DRUM_KICK` moved to `DrumStep`

Now `DrumStep.KICK_OMEGA = 4`, declared beside `SPIN_SECONDS`/`GLIDE_SECONDS` with a comment
giving the reason (the glide carries this velocity, so travel-fraction — the thing the lead is
chosen against — cannot be computed without it) and the inversion that made the hardcoded copy
dangerous rather than merely stale.

- `DrumController.client.luau`: `local DRUM_KICK = DrumStep.KICK_OMEGA`. Value unchanged at 4;
  the `stage:GetAttribute("DrumKick") or DRUM_KICK` override at `gongHit` is untouched and
  still works exactly as before.
- `tests/DrumStep.spec.luau`: `local carried = DrumStep.KICK_OMEGA * G`, and the comment now
  records that the **stage-attribute override remains an untested path** — nothing in the spec
  can see it, so setting `DrumKick` in Studio moves the splash's timing with no failure here.

`DrumStep` still holds no Roblox globals and remains Lune-testable (the module is loaded by the
passing suite).

## 4. The 185-character comment

`main.client.luau`'s `pendingReveal` header line re-wrapped to two lines of 96/92 characters,
in line with its neighbours. No other content change.

---

## Constraints checked

- `setCelebrating`'s `if active == celebrating then return end` latch is untouched and still
  the first statement in the function.
- The `RenderStepped` driver is untouched: still `if countersAnimating() then paintCounters()`,
  check before paint.
- `render` remains the sole writer of `counterPoints`/`counterStreak`/`counterPot`/`counterPulses`.
- Every new local (`countersSeeded`, `seededNow`) is declared above its first use.
- No `UIStroke` added to any `TextLabel`; no `Active` assignment anywhere; `undoPill` still has
  none.
- Untouched as instructed: `SPLASH_LEAD_SECONDS`'s value, `plateHoldSeconds`'s streak
  asymmetry, `RollingNumber.luau`'s header, `render`'s ordering comment, `bankButton.Text`'s
  per-frame rebuild.
