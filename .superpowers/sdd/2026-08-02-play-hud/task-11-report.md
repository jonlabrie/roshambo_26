# Task 11 report — the pot indicator, BANK THESE, the fate prompt; the win gate removed

**Commit:** `8bc5e32` feat(roblox): pot indicator replaces the blocking RISK/BANK overlay
**Gates:** roblox `stylua --check` + `selene` clean (0 errors, 0 warnings), `lune run tests/run`
871/871; server `npm test` 208/208 across 13 files.

---

## 1. TDD evidence — the `HudModel` change

Tests were written first (Step 1) against the not-yet-existing `slot` / `potPulses` and the
not-yet-relaxed `throwsEnabled`. Step 2, `lune run tests/run` from `roblox/`, before touching
`HudModel.luau`:

```
FAIL  HudModel.view — plate and throws > a win no longer blocks throwing — riding IS throwing again
      tests/HudModel.spec:57: expected false to be true
FAIL  HudModel.view — the slot above the throw row > the slot holds the pot whenever points are unbanked
      tests/HudModel.spec:68: expected nil to be pot
FAIL  HudModel.view — the slot above the throw row > the slot holds the fate prompt when fate-bound
      tests/HudModel.spec:72: expected nil to be fate
FAIL  HudModel.view — the slot above the throw row > the slot is empty with no pot and no fate
      tests/HudModel.spec:76: expected nil to be none
FAIL  HudModel.view — the slot above the throw row > fate wins the slot if both are somehow set
      tests/HudModel.spec:83: expected nil to be fate
FAIL  HudModel.view — the slot above the throw row > the pot survives every phase — an unbanked pot does not expire with the round
      tests/HudModel.spec:88: expected nil to be pot
FAIL  HudModel.view — the slot above the throw row > the pot pulses only while the win is unacknowledged
      tests/HudModel.spec:93: expected nil to be true
FAIL  HudModel.view — the slot above the throw row > nothing pulses when there is no pot
      tests/HudModel.spec:102: expected nil to be false
FAIL  HudModel.view — escalation > an unacknowledged win does not silence the escalation
      tests/HudModel.spec:133: expected false to be true

864 passed, 9 failed, 873 total
```

Nine failures — the exact nine new assertions. `expected nil to be …` is the honest signature of a
field that does not exist yet; the two `expected false to be true` are the win gate still refusing.
After Step 3 (`blocked = inputs.fateBound`, the `slot` ternary, `potPulses = slot == "pot" and
inputs.unresolvedWin`, `blocked` in `armed`): **873 passed, 0 failed**. Count later dropped to 871
when the two `postResolveWin` cases were removed from `NetworkClient.spec.luau` with the method.

Deleted, per the brief: the whole `describe("HudModel.view — the choice overlay")` block (three
`choiceUp` tests), and the `unresolvedWin` halves of *"fate-bound and win-bound both disable
throws"* and *"it never fires at a player who cannot throw"*. Every fate-bound assertion was kept
untouched — that gate is unchanged.

Added beyond the brief's list: *"the pot survives every phase"*. The withdrawn overlay had a test
asserting it did not expire with the round; that property carries over to the pot indicator and
deleting its only coverage would have been a silent loss.

## 2. Post-removal grep

```
$ grep -rn "resolveWin\|ResolveWin\|postResolveWin\|resolve-win\|HudResolve\|choiceUp" . \
    --exclude-dir=node_modules --exclude-dir=.git
```

Every hit is prose. Grouped:

| Location | Hits | What it is |
| --- | --- | --- |
| `docs/superpowers/plans/2026-08-02-play-hud.md` | 47 | the plan's own historical record, incl. Task 11's own removal instructions |
| `docs/superpowers/specs/2026-08-02-play-hud-design.md` | 4 | the spec's *What this removes* paragraph and the withdrawn-decision log |
| `server/src/wallet.test.ts:22` | 1 | a comment explaining why three tests moved into `describe('bankPot')` |

**Zero live-code hits.** No `WaitForChild("ResolveWin")` survives anywhere, so the removal of the
`default.project.json` declaration cannot hang a script. (`.superpowers/` is a gitignored symlink and
so is not traversed by `grep -r`; the briefs in it name `ResolveWin` and are prose too.)

## 3. Every element created, with its `Active` state

All in `roblox/src/client/HudController.client.luau`.

| Element | Class | `Active` | Sinks touch? |
| --- | --- | --- | --- |
| `Slot` (`slotRow`) | `Frame` | `false` (explicit) | no |
| `Slot.Pot` (`potGroup`) | `Frame` | `false` (explicit) | no |
| `Slot.Pot.BankThese` (`bankButton`) | **`TextButton`** | n/a | **yes — intended** |
| `Slot.Pot.Disc` (`potDisc`) | `Frame` | `false` (explicit) | no |
| `Slot.Pot.Disc.Figure` (`potFigure`) | `TextLabel` | `false` (explicit) | no |
| `Slot.AcceptFate` (`fateButton`) | **`TextButton`** | n/a | **yes — intended** |
| `Escalation` (`escalation`) | `Frame` (was a `TextLabel`) | `false` (explicit) | no |
| `Escalation.Count` | `TextLabel` | `false` (explicit) | no |
| `Escalation.Prompt` | `TextLabel` | `false` (explicit) | no |

Post-task interactive budget, as required: **three throw buttons + the plate + exactly one slot
button.** Never four.

**"Exactly one" is true by construction, not by discipline.** `setSlot(kind, pulses)` is the only
place either tenant's `Visible` is written, and it writes *both* from the same `kind` on every call:

```luau
potGroup.Visible = kind == "pot"
fateButton.Visible = kind == "fate"
```

There is no assignment that can raise one without clearing the other, and a `Visible = false`
GuiObject receives no input at all. The upstream guarantee is separate and additional: `HudModel`
returns a single `slot` string, with fate taking precedence defensively (a LOSS forfeits the pot, so
the two can never really coexist — but the wrong tenant there would hide the only way out of a fate).

The **pot disc is a `Frame`**, as specified. It states how many points are unbanked; it carries no
action. Making it a button would have added a second live control to the slot *and* punched another
hole in the camera-drag surface.

## 4. What was removed, end to end

| Layer | Removed |
| --- | --- |
| `roblox/src/shared/HudModel.luau` | `choiceUp`; `unresolvedWin` from the `bound`/`blocked` term |
| `roblox/src/server/main.server.luau` | the `unresolvedWin` check in `SubmitPick`; the whole `ResolveWin.OnServerEvent` handler; the `ResolveWin` `WaitForChild` |
| `roblox/src/server/NetworkClient.luau` | `postResolveWin` |
| `roblox/tests/NetworkClient.spec.luau` | `describe("NetworkClient.postResolveWin")` (2 cases) — not in the brief's file list, but it tested the method that went |
| `roblox/default.project.json` | the `ResolveWin` RemoteEvent declaration |
| `roblox/src/client/EventBus.luau` | `HudResolve` → `HudBank` |
| `server/src/wallet.ts` | `resolveWin` |
| `server/src/routes/apiV1.ts` | `POST /resolve-win` and `resolveWin` from the import |
| `server/src/wallet.test.ts` | `describe('resolveWin')` |

**Kept, verified by grep:** `unresolvedWin` on `IUser` + the schema, `Settlement.ts:53` setting it,
`bankPot` byte-for-byte unchanged (its `unresolvedWin: false` and `lifetimeBanked` `$inc` intact),
`PlayerProfiles.Row.unresolvedWin` + `applyServer` + `applyLocalResult`, all nine ledger counters,
`buildProfilePayload` exposing them, and `SubmitPick`'s `fates:isBound` refusal.

**Coverage preserved rather than deleted.** Three of the six `resolveWin` tests were the *only*
assertions anywhere that `bankPot` clears `unresolvedWin`, accrues `lifetimeBanked`, and is
idempotent under a double tap — all three behaviours the brief explicitly says are still needed.
They were always assertions about `bankPot` reached through a wrapper, so they moved into
`describe('bankPot')` calling it directly. The three genuinely gate-specific cases (`RISK` clears
and leaves the pot riding; `RISK` when unbound is a no-op; `BANK` with nothing staked still clears
the gate) went with the gate.

## 5. Steps 4, 5, 7 and 7b

**Step 4 — the slot.** A `Frame` one `ROW_GAP` above the throw row, same right edge, same
`JUMP_CLEARANCE` inboard hold. Pot: `POT_RED` disc (`UICorner` at `UDim.new(1, 0)`) with a
`TextScaled` figure — 3^n runs long fast, so the figure shrinks rather than clipping — and
**BANK THESE** beside it firing `EventBus.HudBank`. Fate: one **ACCEPT YOUR FATE** button firing
`EventBus.Cue:Fire({ kind = "acceptFate" })`, the cue `FateController.client.luau:153` already
listens for (verified; it is a safe no-op when the local player has no flight). While `potPulses`,
a repeating reversing `TweenService` tween drives the disc's `BackgroundTransparency` 0 → 0.55; it
is `Cancel`led and the property restored to 0 the moment the pulse clears, since `Cancel` otherwise
leaves it mid-tween.

**Step 5 — the escalation.** The Task 10 stub `TextLabel` became a `Frame` holding a large centred
count (`TextSize` 84, `GothamBlack`) and a `CHOOSE A THROW` line, both stroked against the canyon.
The bottom hairline now turns `LOSS_RED` and thickens 3 → 7 px on `view.escalate`.

**Step 7 — `escalationPrompts` on `ProfileUpdate`.** HUD preferences are not wallet fields, so they
do not belong on a `PlayerProfiles.Row`; a small `hudPrefs` table in `main.server.luau` holds them
instead, seeded from `getPlayer`'s payload (which already carried the field) and cleared on
`PlayerRemoving`. `fireProfile` emits `escalationPrompts` beside `unresolvedWin`; the client reads it
in the `ProfileUpdate` handler instead of hard-defaulting. One addition beyond the letter of the
step: `SetHudPreference` also updates the cache, because otherwise the very next `fireProfile` would
echo the pre-write value back and the Task 12 switch would appear to undo itself.

**Step 7b.1 — the lying hairline.** `main.client.luau` now publishes `timerKnown = lockoutAt ~= nil`
in `aux` (render-only, so `HudModel` stays untouched); `HudController` hides the hairline entirely
when it is false rather than depleting against a faked 30 s span. Throws stay enabled, as before.
The `span` reset also moved out of the `ACTIVE` branch so a nil-lockout round cannot carry a stale
span into the next one.

**Step 7b.2 — the whiffed pick.** `myPick = nil` in the whiff branch, so the tapped tile stops
illuminating through REVEAL as though it had counted.

The other two deferred Minors (toast-queue backlog, aged-tape glyph contrast) were left for the
Task 15 sweep, as instructed.

## 6. Beyond the brief — three comment-only edits, and one behaviour change

Flagging these explicitly since the brief drew a tight boundary.

1. **Behaviour:** the Roblox `BankRequest` handler passed `unresolvedWin` *through* on a successful
   bank, on the reasoning that `/bank` "is not the win-gate endpoint". `wallet.bankPot` sets
   `unresolvedWin: false` in the same atomic update, so the cache was left holding a value the DB no
   longer had. Now `false`. (Visibly harmless either way — `potPulses` requires `slot == "pot"` and
   the pot is 0 after banking — but the cache should not diverge from the row.)
2. `PlayerProfiles.applyLocalResult`'s comment said a WIN "binds the player until they answer" and
   raises "the choice overlay". Rewritten: it gates nothing, it makes the pot pulse.
3. `IUser.unresolvedWin`'s comment justified the field by "after choosing RISK the pot still rides".
   Rewritten around the surviving justification (a pot ridden through a SAFE is identical in figure
   to one just won).
4. `onReconciled`'s comment said defaulting to false would "silently unbind a bound player".
   Rewritten: it would drop the pulse.

A stale comment describing a gate that no longer exists is exactly the half-removed state the brief
warned against, so these were fixed rather than left.

## 7. Self-review

- **Did I delete anything still needed?** No — §4's keep-list was grepped after the fact and every
  entry survives. The one real risk, `bankPot`'s test coverage riding inside the deleted
  `resolveWin` block, was caught and the three surviving assertions rehomed.
- **Did any non-interactive element become a button?** No. Nine new elements, two of them
  `TextButton`s by design, and never both live: see §3. Everything else is a `Frame` or `TextLabel`
  with `Active = false` set explicitly. The `Escalation` element went the *other* way — it was a
  `TextLabel` and is now a `Frame` container, still `Active = false`, still centred on the
  camera-drag surface.
- **YAGNI:** no Task 12–14 feature was built. `HudController` gained one self-contained `setSlot`
  and two new render lines; `main.client.luau` gained one `EventBus` binding. The ledger, the
  preference switch and onboarding remain untouched.
- **Structure for Tasks 12–14:** `EventBus.OpenLedger` still fires from the plate, `HudModel` still
  owns every rule and `HudController` still only paints it, and the `aux` bag now has a precedent
  (`timerKnown`) for render-only facts that should not enter the pure model.

## 8. Concerns for the controller

1. **Studio verification was not done — by instruction.** Nothing here has been seen on a screen.
   Specifically unverified: the pulse tween's read at 0.7 s / 0.55 transparency, whether **BANK
   THESE** at 128 px and **ACCEPT YOUR FATE** at 190 px hold their text at `TextSize` 15, and
   whether the 40 px slot clears the tape row cleanly. All are geometry Task 15 settles; no pixel
   offsets were hand-tuned, and everything is anchored off the existing `JUMP_CLEARANCE` /
   `AREA_W` / `ROW_GAP` constants.
2. **`ResolveWin` disappears from `ReplicatedStorage` on the next Rojo sync.** No code waits for it
   (§2), but a Studio session left open across the sync will still have the orphaned instance.
3. **`getPlayer` failure leaves `escalationPrompts` defaulting to ON.** The `hudPrefs` seed sits
   inside `if res.ok`, matching how the wallet itself already behaves on a failed sync. A player
   who turned prompts off and hits a failed sync gets them back for that session only.
