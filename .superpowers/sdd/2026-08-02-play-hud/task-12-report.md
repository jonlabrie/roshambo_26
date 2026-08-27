# Task 12 report — `LedgerController`, the maximal takeover panel

**Commit:** `a489c61` feat(roblox): LedgerController — the maximal takeover panel
**Gates:** `stylua --check src tests tools` clean, `selene src tools` 0 errors / **0 warnings**,
`lune run tests/run` **871 passed, 0 failed**. `shared-fixtures/game-rules.json` and both
`GameRules` implementations untouched (`git diff --stat` empty). No `.rbxl(x)` committed.

**Studio verification was deliberately NOT done** — per the plan header it is the controller's job,
batched. Everything below that says "verified" was verified statically, in code, and is flagged as
such.

## Files

| File | Change |
| --- | --- |
| `roblox/src/client/LedgerController.client.luau` | **new** — the panel |
| `roblox/src/client/EventBus.luau` | + `LedgerState`, + `HudPreference` |
| `roblox/src/client/main.client.luau` | fires `LedgerState`; `HudPreference` → `SetHudPreference`; bank line for the feed |
| `roblox/src/server/main.server.luau` | **deviation** — carries the nine counters on `ProfileUpdate` (see below) |

## Control suspension: which mechanism, and how it was verified

**Primary: `PlayerModule:GetControls()` → `Disable()` / `Enable()`.**

I could not run Studio, so the path was verified the only way available without it — statically:

- `roblox/default.project.json` declares `StarterPlayer.StarterPlayerScripts` with exactly one
  child, `RoshamboClient` (`$path: src/client`). The place therefore **does not replace Roblox's
  default control stack**, so `PlayerScripts.PlayerModule` is the stock module and `:GetControls()`
  is its documented accessor.
- `grep -rn "PlayerModule|GetControls|WalkSpeed" roblox/src/` returns **one** pre-existing hit —
  `FateController.client.luau:213`, which only *reads* `humanoid.WalkSpeed` to size an effect.
  Nothing else in the codebase disables controls or writes `WalkSpeed`, so there is no competing
  owner of either mechanism.

**Fallback: `Humanoid.WalkSpeed = 0`, restored on close.** Engaged automatically if `PlayerModule`
does not resolve within 5s, if `require`/`GetControls` raises, **or if `Disable()` itself raises** —
the latch is only set to `"controls"` when the call actually took.

The controller's Studio pass should confirm the primary path is what runs (no
`[LEDGER] PlayerModule …` warning in the output console on first open). If the warning appears, the
fallback is already carrying it and nothing is broken — the freeze is just coarser.

Two deliberate narrowings:

- **Jumping is not touched.** A player who cannot walk cannot travel; hopping in place has never
  walked anyone off a deck. Fewer properties written is fewer ways to hand a character back broken.
  (It also sidesteps the `UseJumpPower` / `JumpHeight` split, where zeroing `JumpPower` is silently
  inert.)
- **A zero is never restored.** If something else had already frozen the character when we captured
  `WalkSpeed`, handing that captured `0` back on exit would strand the player — the exact failure
  the whole mechanism exists to prevent. `restore()` falls back to 16.

## Every exit path, and how each re-enables controls

There are three, and **all three call the same `close()`**, which is the only caller of `restore()`:

| # | Path | Wiring |
| --- | --- | --- |
| 1 | the **✕** | `closeButton.MouseButton1Click:Connect(close)` |
| 2 | **tap outside** the panel | `scrim.MouseButton1Click:Connect(close)` |
| 3 | **Escape** | `UserInputService.InputBegan` → `if isOpen and input.KeyCode == Escape then close()` |

`close()` is: `if not isOpen then return end; isOpen = false; gui.Enabled = false; restore()`.
`restore()` is reached unconditionally — there is no branch inside `close()` that can skip it.

### Can any path leave the player frozen? — what I hardened after the first draft

Four routes to a frozen player existed and were closed:

1. **A throw inside `restore()`.** `close()` hides the panel *before* restoring, so an error
   propagating out of a click handler would have left a frozen player with no ✕ to press. The
   control call is now `pcall`'d (`setControlsEnabled`) and the failure is **warned, not swallowed**.
   The `WalkSpeed` branch cannot throw (a property write).
2. **Restoring with the wrong mechanism.** `controls` resolves at script load, but if it had ever
   resolved *late*, a freeze applied via `WalkSpeed` could have been "restored" by
   `controls:Enable()` — leaving `WalkSpeed` at 0 forever. `suspendedVia` is now **latched at
   suspend and read at restore**, so the restore always matches the freeze.
3. **A throw inside `open()` after suspending.** The first draft suspended *before* rendering. If
   `render()` had raised, the player would be frozen with no panel — no ✕, and on touch no Escape
   either. `open()` now paints, shows, sets `isOpen`, and **freezes last**, so the way out always
   exists by the time the legs are gone.
4. **Respawn while open.** `ResetOnSpawn = false` keeps the panel, but a fresh `Humanoid` arrives
   un-frozen on the fallback path. `CharacterAdded` re-applies the suspension **only while
   `isOpen`**, re-capturing from the new humanoid; `close()` clears `isOpen` *before* restoring so
   the handler cannot re-freeze behind it.

Residual, and I do not think it can be closed from here: if `controls:Enable()` itself fails, no
client code can un-disable that stack. It warns, and because `close()` is idempotent rather than
one-shot, **reopening the panel and closing it again retries the restore** — a real recovery path
rather than a dead end.

## Narrow-screen layout

Three columns is a landscape-**tablet** layout. Below `NARROW_PX = 900` viewport width the feed
**collapses to a tab**: a two-tab strip (`STATS` / `FEED`) appears under the hero band, the lifetime
and your-throws cards share the width at ½ each, and the feed takes the full body when its tab is
selected. Above the threshold the strip is hidden and all three cards sit at ⅓.

- The tier is read from `workspace.CurrentCamera.ViewportSize`, **not** `panel.AbsoluteSize`: a
  disabled `ScreenGui` has not laid out, so `AbsoluteSize` is `0` until the frame after the first
  open and would read as the narrowest tier every time.
- Re-evaluated on `ViewportSize` change and on every `open()`.
- `NARROW_PX = 900` is **a placeholder, and commented as one.** The brief says not to hand-tune
  breakpoints against a desktop viewport; Task 15's device-emulator sweep settles the real number.

## Notes on the rest of the panel

- **Nothing is recomputed.** `LedgerModel.view(counters, live, GameRules)` supplies every figure.
  The WIN/SAFE/LOSS segments are laid end to end straight from `view.bar` — they sum to exactly 100
  by the model's largest-remainder apportionment, so **there is no gap and no overrun by
  construction**, not by a fudge here. `winRatePct` is `bar.win`, so headline and bar cannot
  disagree.
- **`Active` discipline, takeover carve-out.** `panel.Active = true` is **required**: a non-Active
  Frame does not consume input, so every tap inside the panel would fall through to the scrim behind
  it and close the thing the player is reading. The scrim is a `TextButton` for the same reason.
  Every label is left non-Active (the default). Interactive objects: scrim, ✕, BANK THESE, the
  preference switch, two tabs.
- **No RISK button anywhere.** The hero band gets a plain **BANK THESE** whenever `live.pot > 0`.
  Riding is throwing again.
- **Glyphs, never characters.** The throw-distribution rows call `Glyphs.render` (gold core, ink
  outline against the dark card).
- **Feed is personal-only.** It is the toast stream, timestamped and kept whether or not the panel
  is open — literally the spec's "transient toasts in minimal, full scrollback in maximal". Capped
  at 60 entries, newest first via negative `LayoutOrder`. **No social lines were invented.**
- **Preferences footer ships exactly one switch**, optimistic on tap, reconciled by the next
  `ProfileUpdate` echo. The row is sized for later additions; nothing else was built.

## Deviations, disclosed

**1. `main.server.luau` was modified — the counters had never been plumbed into the game.**

The brief names "the profile payload's `counters`" as an input, but nothing carried them. Task 5
put `counters` on the REST profile (`buildProfilePayload`); the Roblox server's `fireProfile` builds
from a `PlayerProfiles` row, which has no counter fields, and the plan's only `ProfileUpdate`
additions were `unresolvedWin` (Task 9) and `escalationPrompts` (Task 11). Without this the ledger
renders nine permanent zeros. I judged that worse than a disclosed out-of-file change. What I added,
mirroring exactly how `hudPrefs` was handled one task earlier:

- seeded at join from `net:getPlayer(...).data.counters`, defaulted key by key;
- carried on `ProfileUpdate` as `counters`;
- **advanced optimistically** in `onReveal` (`bumpCounters`), mirroring `Settlement.ts`'s
  `buildCounterUpdate` — one round, one throw, one result, `bestPot` as a maximum against the
  post-round pot — and in the bank handler (`lifetimeBanked += the banked pot`, which is what
  `wallet.bankPot` accrues on the same atomic write);
- cleared on `PlayerRemoving`.

Two things I checked rather than assumed: whiffed players are **excluded** from
`reveal.results` (`RoundCoordinator.luau:146`), so the local participant set matches the backend's;
and `existing.pointsAtStake` is read **before** `applyServer` overwrites it.

*Known limitation, deliberate:* there is no per-round authoritative source for these —
`/instances/.../results` carries round results, not lifetime totals. So the in-session figures are
optimistic and re-seed from the database on the next join, exactly like `PlayerProfiles`' wallet
before reconciliation. Refetching the profile per round would be a per-player HTTP call every
minute, which is not worth it for a panel opened occasionally.

**2. A bank line was added to the toast stream** (`main.client.luau`, on `ProfileUpdate` with
`source == "banked"`, using the pre-update pot). The feed is specified to carry "your own banks",
and no bank event existed anywhere on the client. It also gives banking its first piece of feedback
beyond numbers silently changing.

**3. `bestStreak` rides `LedgerState` separately.** The lifetime card's five figures include best
streak, which is **not** in `LedgerModel.Counters` — it is a wallet field already on `ProfileUpdate`.
It is passed alongside rather than smuggled into the counters table, so `LedgerModel` was not
touched.

**4. Two `EventBus` names, not one.** The brief asked for `HudPreference`; `LedgerState` was also
needed to carry the profile to the panel, because `main.client.luau` is the wiring seam and
`HudState` is a 10 Hz heartbeat that has no business carrying lifetime counters.

## For the controller's Studio pass

Beyond the brief's Step 5 list:

1. Confirm no `[LEDGER] PlayerModule …` warning on first open (i.e. the primary path resolved).
2. Confirm the **third** exit path specifically — tap outside — restores movement on touch, since
   that is the one with no keyboard equivalent.
3. Confirm the panel does not close when tapping *inside* it (the `panel.Active` case).
4. The narrow tier will not trigger on a desktop viewport; it needs the emulator.

---

# Fix report — round 1 of 5

**Commit:** `6676545` fix(roblox): ledger counters are authoritative at open, not accumulated
**Gates (re-run after the fix):**

```
$ cd roblox && stylua --check src tests tools && selene src tools && lune run tests/run
Results:
0 errors
0 warnings
0 parse errors

871 passed, 0 failed, 871 total
```

All three Importants addressed; the three Minors were **recorded and deliberately not touched**
(bank-toast copy vs onboarding beat 4 → Task 13; `PlayerModule` resolving ~700 lines before
`OpenLedger` is connected; card offsets with no `ClipsDescendants` on a short screen → Task 15).

## Important 1 — respawn race could silently undo a `close()`

The reviewer is right, and my original report's claim was wrong: `close()` clearing `isOpen` before
restoring only protects the *pre-yield* check. `CharacterAdded` parked on
`char:WaitForChild("Humanoid", 10)`, and a ✕ pressed inside that window restored control before the
handler resumed and re-froze — with no panel on screen.

**Fix:** `isOpen` is now tested **twice**, before and after the yield, and `savedWalk = nil` moved
below the second test so a stale capture cannot be cleared on a path that then returns.

```luau
player.CharacterAdded:Connect(function(char)
    if not isOpen then return end
    char:WaitForChild("Humanoid", 10)
    if not isOpen then return end      -- the one that matters
    savedWalk = nil
    suspend()
end)
```

Covering check — `grep -n "if not isOpen then" LedgerController.client.luau` returns lines 176, 180
(the two in this handler) and 779 (`close()`'s idempotence guard). Close-then-reopen inside the
window still re-freezes correctly, which is right: the new character does need freezing.

## Important 2 — a transient join-sync failure blanked the whole panel

**Fix, both halves:**

- **Server:** `seedCounters(uid, nil)` now runs **unconditionally in `PlayerAdded`, before** the
  `task.spawn`'d fetch. `seedCounters` already defaults key by key, so passing `nil` yields the nine
  zeros. The success branch overwrites them.
- **Client:** the `if not counters then return end` early-return is **deleted** from
  `publishLedger`. That gate was the mechanism by which a counters problem took down the live hero
  band, best streak and the preference switch, none of which are counters. `LedgerState` now always
  fires; `LedgerController` already guards with `if state.counters then counters = state.counters end`,
  so a nil simply leaves the renderer's zeros in place.

Covering checks: `grep -n "if not counters then"` in `main.client.luau` → **no matches**.
`grep -rn "seedCounters" roblox/src/` → definition plus **three** call sites (unconditional join
seed, join-success re-seed, open re-seed).

## Important 3 — re-seed at open, not accumulate

`bumpCounters`, `THROW_COUNTER` and the `lifetimeBanked +=` bank accrual are **deleted**.
`grep -rn "bumpCounters\|THROW_COUNTER\|lifetimeBanked +=" roblox/src/` → **no matches**.

### `RequestSync` was checked first, as instructed — it is the wrong hook

Not a close call, for two independent reasons visible in the existing code:

1. **It makes no network call.** `RequestSync.OnServerEvent` (`main.server.luau:997`) re-echoes
   state already cached *on this server* — `echoEconomy`, `PreferenceState`, back door, access. It
   is the late-listener recovery path, not a fetch.
2. **It is fired on a retry loop.** `EconomySync.client.luau:21-29` fires it **once a second, up to
   twenty times, every join**, until `EconomyState` lands. Hanging a `GET /players` off it would
   mean up to twenty HTTP fetches per player per join.

So a new `RequestLedger` `RemoteEvent` was added to `default.project.json` (same precedent as Task
9's `SetHudPreference`).

### The flow

- `EventBus.OpenLedger` now has **two** listeners: `LedgerController` shows the panel, and
  `main.client.luau` fires `RequestLedger:FireServer()`. No new client channel; one event, one
  meaning.
- Server: per-uid **3s debounce**, then `task.spawn` → `net:getPlayer(uid)` → `seedCounters` +
  refresh `hudPrefs` → `fireProfile(player, "ledger")`. Cleared in `PlayerRemoving` alongside
  `hudPrefs` and `ledgerCounters`.
- **Only the counters (and the preference) are taken from the response.** The wallet is deliberately
  *not* re-applied: the reconciliation loop already owns it authoritatively, and a mid-round fetch
  could stomp a fresher local reveal with a settlement that has not happened yet.
- **On fetch failure the panel keeps its last figures** rather than blanking — stale, not wrong —
  and warns.

The panel paints last-known figures immediately on open and snaps to authoritative ones when the
`ProfileUpdate` echo lands, because `LedgerController` re-renders on `LedgerState` while open.

### Known staleness, accepted and recorded

Banking **from inside the open panel** does not move the BANKED figure until the panel is reopened
(the bank's own `fireProfile` carries the unchanged cached counters). This is the direct consequence
of the ruling — no local accumulation — and closing and reopening is two taps. Adding a second HTTP
fetch on every bank to close it would trade a correct-but-briefly-stale number for per-bank network
cost, which is the trade the ruling just went the other way on. Not fixed; recorded.

## Correction to the original report

The original report's Deviation 1 said the counters "advanced optimistically… mirroring
`Settlement.ts`", and its residual-limitation paragraph rejected "refetching the profile per round".
The reviewer is right that nobody proposed per-round refetching, and that per-**open** refetching is
both cheaper and authoritative. That paragraph is superseded by this section.

## For the controller's Studio pass — one addition

`default.project.json` gained a remote, so **Studio needs a Rojo re-sync before this can be tested**
(`RequestLedger` will not exist in an already-open place otherwise, and `main.client.luau`'s
`WaitForChild` for it would hang the whole play-HUD wiring script). Worth confirming first: the
counters should snap to authoritative figures a moment after the panel opens, and the output console
should show no `[LEDGER] refresh failed` warning.
