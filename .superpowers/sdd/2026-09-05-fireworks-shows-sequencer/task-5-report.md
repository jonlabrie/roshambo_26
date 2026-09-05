# Task 5 report — Playback in the game server

**Commit:** `c9beca5` — feat(shows): server-owned playback -- RequestShowGo validates, reserves, then
plays a deck show through the shared launch broadcast; boost roll and broadcast extracted

**Status:** complete. Lint clean, Luau suite green (1880/1880). The Studio check (brief Step 6) did
NOT run — no Studio available in this session; it carries forward as the first item of Task 7's gate.

---

## The one deviation from the brief, and why it was forced

The brief asks for three module-level `local function`s (`rollBoost`, `broadcastLaunch`, `playShow`)
plus seven more top-level locals (`RequestShowGo`, `ShowPlan`, `ShowPlayer`, `KNOWN_SHELLS`,
`stageBusyUntilMs`, `nowMs`, `denseCues`) — ten new top-level locals in all.

**`main.server.luau` cannot take ten.** Written exactly as briefed, the file failed
`tests/Compiles.spec.luau`:

```
FAIL  Compiles — every src file passes the Luau compiler > src/server/main.server.luau
      failed to compile: syntax error: 2527: Out of local registers when trying to
      allocate collectShojiRun: exceeded limit 200
```

That spec exists precisely because this ceiling once silently killed the whole play HUD (see its own
header comment, 2026-09-03). I measured the actual headroom by padding the file at HEAD with N dummy
top-level locals and compiling at `optimizationLevel = 0` and `2` (the spec's own bracket):

| padding locals at HEAD (`5823fe5`) | compiles |
|---|---|
| 0, 1, 2 | OK |
| 3 | **out of registers** |

So HEAD had **exactly two** free top-level registers. Ten was never going to fit.

**Resolution:** one namespace table, `local Launch = {}`, declared immediately above the
`RequestFireworkLaunch` handler (`main.server.luau:1534`). Table fields cost no registers. Everything
the brief named lives on it with the brief's own names:

| brief name | as built | line |
|---|---|---|
| `rollBoost` | `Launch.rollBoost` | 1544 |
| `broadcastLaunch` | `Launch.broadcastLaunch` | 1558 |
| `playShow` | `Launch.playShow` | 1701 |
| `denseCues` | `Launch.denseCues` | 1741 |
| `RequestShowGo` | `Launch.RequestShowGo` | 1762–1763 |
| `ShowPlan` / `ShowPlayer` | `Launch.plan` / `Launch.player` | 1681–1682 |
| `KNOWN_SHELLS` | `Launch.knownShells` | 1685 |
| `stageBusyUntilMs` | `Launch.stageBusyUntilMs` | 1693 |
| `nowMs` | `Launch.nowMs` | 1695 |

Two supporting details:

- `ShowPlan.Cue` cannot be referenced as a type without a `local ShowPlan = require(...)` binding, so
  the file declares `type ShowCue = { t_ms: number, slot: string, shellId: string }`
  (`main.server.luau:1538`). Type aliases cost no register. This is the codebase's own precedent —
  `ShowPlayer.luau:9` mirrors the same shape rather than requiring `ShowPlan`.
- Inside `Launch.playShow` and the handler, `local ShowPlayer = Launch.player` / `local ShowPlan =
  Launch.plan` re-bind the modules as *function*-scope locals. Each closure has its own 200-register
  budget, so those are free with respect to the top-level ceiling and the bodies read as briefed.

**Net cost: one top-level register.** Measured after the change: the file still compiles with 1 pad
local and fails at 2 — i.e. headroom went 2 → 1, exactly the one `Launch`.

**Carry to Task 6:** there is ONE top-level register left in this file. `RequestProvingShow` and the
proving-show runner must hang off `Launch` too (`Launch.RequestProvingShow`, `Launch.playProvingShow`),
not new `local`s. Re-measure before assuming otherwise; the probe is three lines of Lune around
`luau.compile(src, { optimizationLevel = 0 })`.

---

## What changed

### `roblox/default.project.json`

Two RemoteEvents after `RequestProvingFire` (lines 39–40): `RequestShowGo` and `RequestProvingShow`
(the latter declared now, wired in Task 6, per the brief).

### `roblox/src/server/main.server.luau`

1. **Lines 1534–1576 — the namespace and the two extracted helpers**, inserted between
   `pushFireworkState`'s definition and the `RequestFireworkLaunch` handler. `Launch.rollBoost` is the
   pity ramp verbatim; `Launch.broadcastLaunch` is the `FireworkLaunched:FireAllClients` shape plus an
   additive `showId`.
2. **Lines 1661–1669 — the single-shell call site**, 22 lines replaced by 9. Behaviour argument below.
3. **Lines 1676–1821 — the shows block**, between the `RequestFireworkLaunch` handler and the proving
   range: the module wiring, `Launch.playShow`, `Launch.denseCues`, and the `RequestShowGo` handler.

Nothing else in `RequestFireworkLaunch` was touched: the site check, the spend-first ordering, the
muzzle/public-tube/fallback origin resolution and the trailing `pushFireworkState` are byte-identical.

---

## Field-by-field: why the single-shell payload is unchanged

Original (was 1611–1632) vs. new (1661–1669). The broadcast is a table constructor handed to
`FireworkLaunched:FireAllClients`; only the values of its seven keys can differ.

**Guard equivalence first.** Original: `local boosted: boolean? = nil` then `if baseChance then …
boosted = verdict end`. New: `Launch.rollBoost` does `if not baseChance then return nil end` and
otherwise returns `verdict`. `baseChance` is `number?`; `if baseChance` and `not baseChance` are exact
complements for every Lua value including `0` (truthy in Lua, so both forms take the roll branch). The
mutation of `boostMisses[uid][shellId]` sits inside the branch in both, unchanged line for line.

| field | original expression | new expression | same? |
|---|---|---|---|
| `shellId` | `shellId` | `fields.shellId`, called with `shellId = shellId` | yes — same string binding |
| `origin` | `origin` | `fields.origin`, called with `origin = origin` | yes — same `Vector3` value, passed by reference |
| `heading` | `heading and { x = heading.X, y = heading.Y, z = heading.Z } or nil` | `fields.heading and { x = fields.heading.X, … } or nil`, called with `heading = heading` | yes — character-for-character the same idiom over the same `Vector3?`. The `and/or` is safe in both: when `heading` is non-nil the constructed table is truthy, so `or nil` never fires |
| `seed` | `math.random(1, 2 ^ 31 - 1)` | `math.random(1, 2 ^ 31 - 1)` inside `broadcastLaunch` | yes — same call, same bounds, and **same position in the RNG stream**: `rollBoost` draws exactly one `math.random()` under exactly the conditions the inline block did, then `seed` draws next, so the sequence of draws per launch is unchanged |
| `by` | `uid` | `fields.by`, called with `by = uid` | yes |
| `boosted` | `boosted` (local set by the inline roll) | `fields.boosted`, called with `boosted = Launch.rollBoost(uid, shellId)` | yes — same `boolean?`, per the guard-equivalence argument above |
| `apexHeight` | `publicApex` | `fields.apexHeight`, called with `apexHeight = publicApex` | yes — the `number?` set by the public-tube branch, untouched |
| `showId` | *(absent)* | `fields.showId`, **not passed at this call site** → `nil` | yes — in Lua a table-constructor field assigned `nil` is simply not created. `{ …, showId = nil }` and `{ … }` are the same table, so the replicated payload has the same key set |

Key *order* in the constructor is irrelevant (a hash part, and the order is unchanged anyway). Call
ordering is unchanged: roll, then broadcast, then `pushFireworkState`.

Conclusion: the hand-launch path is byte-identical, and the extraction is behaviour-preserving.

---

## The densify guard (carried in from Task 2's review)

`ShowPlan.validate` walks with `ipairs`, which stops at the first hole, so a hostile
`{ [1] = cue, [3] = cue }` would have only its prefix validated while the rest rode into playback.
`Launch.denseCues` (1741–1760) runs **before** `ShowPlan.validate`: every key must be a number, an
integer (`k % 1 == 0`) and `>= 1`, and the key count must equal `#t`; otherwise it returns `nil` and
the handler `warn`s and returns. On success it returns a fresh 1..n copy, and that copy — not
`show.cues` — is what goes to `validate`, into the reserve body, and into `playShow`.

Exercised the exact function under Lune:

```
dense 3        ok n=3
hole {1,3}     REFUSED
hole {1,2,4}   REFUSED
string key     REFUSED
zero key       REFUSED
float key      REFUSED
empty          ok n=0      (ShowPlan.validate then rejects it: EMPTY)
not a table    REFUSED
```

A NaN key is not testable and not reachable: Lua refuses `t[0/0] = v` at construction, and remote
deserialization cannot produce one either.

---

## Verification

```
$ cd roblox && stylua --check src tests tools
(clean)
$ selene src tools
Results: 0 errors, 0 warnings, 0 parse errors
$ lune run tests/run 2>&1 | tail -2
1880 passed, 0 failed, 1880 total
```

`tests/Compiles.spec.luau` covers `src/server/main.server.luau` at `optimizationLevel` 0 and 2 — that
is what caught the register overflow, and it is green now.

**Studio check (Step 6): NOT RUN** — no Roblox Studio in this session. Unverified in a live place:
the three-cue timing (0 / 1.5 / 3 s), the HUD counts dropping by the whole show at go, a second go
queueing behind the first's tail, and the hand-launch regression. These are Task 7's gate.

---

## Concerns

1. **The register ceiling is now the binding constraint on this file** (one slot left). Task 6 must
   use `Launch` fields. Beyond that, `main.server.luau` needs real extraction into modules before it
   can grow again; worth a wiki note under `docs/wiki/`.
2. **`os.clock()` is a process-uptime clock, not wall time.** It is monotonic and only ever compared
   against itself here (`stageBusyUntilMs` vs `nowMs`), so scheduling is correct — but the value is
   not comparable with `workspace:GetServerTimeNow()` used elsewhere in this file. Anything that later
   wants to show a client "the show starts at T" must convert, not read `stageBusyUntilMs` directly.
3. **`stageBusyUntilMs` never shrinks.** One entry per `deck:<uid>` that has ever run a show, holding
   a number, for the life of the server process — bounded by distinct players in a session, so small,
   but it is not cleaned on `PlayerRemoving` the way `boostMisses` is. Deliberate: a departing owner's
   show keeps playing (that is the spec), so the busy mark must outlive them. Worth a sweep if show
   stages ever become unbounded (proving stages, teahouse stages).
4. **`playShow` schedules with `task.delay` and never cancels.** A show cannot be stopped once
   reserved — no handle is kept. That matches the spec ("plays to the end"), but if a stop/refund
   story appears later, the `task.delay` handles must be collected first.
5. **The reserve is a blocking HTTP call inside the player's `handlerQueue` lane.** Same as the
   existing spend path, so no new risk, but a slow backend stalls that player's other queued handlers
   for the request's duration.
6. **`title` is forwarded unvalidated** (`show.title` straight into the reserve body). The backend is
   the authority on it; noted only so nobody assumes this side sanitises it.

---

# Task 5 fix round — review findings 1 and 2

**Commit:** `92c3639` — fix(shows): snapshot mortar origins at go so a show outlives its owner
leaving; restore the handler's comment

Only `roblox/src/server/main.server.luau` changed. No new top-level `local` — both edits live
inside `Launch.RequestShowGo`'s handler closure, which has its own 200-register budget.

## Finding 1 (spec gap): mortar origins are now snapshotted at go

Spec §2.4 says a show plays on whether or not its owner is still here. It did not: `originFor`
called `muzzleOriginFor(uid, …)` **inside** the `task.delay` closure, at fire time, and
`muzzleOriginFor` returns `nil, nil` when `playerEconomy[uid]` is nil (`main.server.luau:1442-1445`).
`PlayerRemoving` nils that entry, so every mortar cue after the owner disconnected resolved nil and
was warn-and-skipped — while the reserve had already debited the whole show. Hand cues were
unaffected (they use the `handFrame` CFrame captured at go).

**As built (`main.server.luau:1815-1846`)**, between `local handFrame = root.CFrame` and
`Launch.playShow`:

- A `do` block collects one representative shell id per DISTINCT non-`hand` slot into
  `shellPerSlot`, then calls `muzzleOriginFor(uid, deckPos, deck, shellId)` **once per slot** and
  stores `{ origin, heading }` in `muzzles`. A slot that fails to resolve is simply absent.
  One call per slot is correct because `muzzleOriginFor` keys on the SHELL's required mortar
  (`MortarPlacement.SHELL_MORTAR[shellId]`) and `ShowPlan.validate` guarantees every shell placed in
  a `mortar:X` slot requires exactly `mortar:X`.
- `originFor(cue)` now returns the captured `handFrame` point for `hand`, and the snapshot for a
  mortar slot; a missing snapshot returns `nil, nil, nil`, which `Launch.playShow` already handles
  with the same warn-and-skip as before. The nil path is therefore unchanged in shape — what changed
  is *when* it is decided (at go, while the owner is present, rather than per cue after they left).
- A 7-line comment above the snapshot states why it exists: the owner may leave, and origins do not
  move during a show, so resolving at go is exact rather than an approximation.

Behaviour for a present owner is identical: the same deck, the same `deckCFForUidFn` row and
`MortarPlacement.resolve` result, evaluated a few seconds earlier. No RNG draw moved (the boost roll
and `seed` still happen inside each cue's delayed closure, in the same order).

## Finding 2 (cosmetic): the handler's block comment restored

The four-line comment introducing `RequestShowGo` had been collapsed into a 335-char trailing
comment on `Launch.denseCues`'s closing `end`, with embedded `--` markers. It is now four `--`
lines directly above `Launch.RequestShowGo = …` (`main.server.luau:1763-1766`) and the `end` at
1761 carries no trailing text. The wording was updated in place to match the new behaviour ("Every
origin is snapshotted at go … so a reserved show plays out even if its owner walks away or
disconnects") rather than restoring the now-false "resolved per cue at fire time" sentence.

## Verification

```
$ cd roblox && stylua --check src tests tools
(clean)
$ selene src tools
Results: 0 errors, 0 warnings, 0 parse errors
$ lune run tests/run 2>&1 | tail -3
[QUEUE] handler error for u: .../roblox/tests/HandlerQueue.spec:80: boom   (expected test output)

1880 passed, 0 failed, 1880 total
```

`tests/Compiles.spec.luau` is in that suite and still passes, so the file remains under the
200-top-level-local ceiling: the register headroom is unchanged at ONE free slot (Task 6 must still
hang `RequestProvingShow` and its runner off `Launch`).

## Concerns

1. **Studio check still NOT run** (no Studio in this session). Newly unverified in a live place:
   that a mortar cue fired after the owner disconnects still launches from the right muzzle. The
   cheap manual test is a 3-cue show with a `mortar:S` cue at ~15 s, then quit the client before it
   fires — the shell should still appear, from the deck's S tube. This joins Task 7's gate.
2. **The snapshot is taken after the reserve**, so a slot that is unresolvable at go (tier not owned,
   deck row unresolved) is warn-and-skipped for the whole show while still having been paid for.
   That is the pre-existing behaviour, not a regression — but it is now decided once, so a
   validator/reserve-side check on slot ownership would be the real fix if it ever matters.
3. The prior round's concerns 1-6 (register ceiling, `os.clock` vs server time, `stageBusyUntilMs`
   never shrinking, uncancellable `task.delay`s, blocking reserve in the queue lane, unvalidated
   `title`) all still stand unchanged.
