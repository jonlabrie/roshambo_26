# Task 6 report — Hand-authored show drafts and the Studio-only proving verb

Commit: `ea71393` — feat(shows): hand-authored show drafts (warmup, finale_v1) and a Studio-only Play verb on the proving panel; proving origin resolution shared

## Implemented

| File | What |
| --- | --- |
| `roblox/src/shared/FireworkShows.luau` (new) | Pure drafts: `DRAFTS` (`warmup`, `finale_v1`), `ORDER`, `Cue`/`Draft` types, `walk`/`volley`/`concat` builders. Verbatim from the brief. |
| `roblox/tests/FireworkShows.spec.luau` (new) | The brief's spec verbatim. |
| `roblox/src/server/main.server.luau` | `Launch.provingOriginFor` extracted; `RequestProvingFire` refactored onto it + `Launch.broadcastLaunch`; `RequestProvingShow` handler added. |
| `roblox/src/client/ProvingController.client.luau` | `-- Shows --` header + one row (title + `Play`) per `FireworkShows.ORDER` entry. |

## RED / GREEN

**RED** (spec written, module absent):

```
error requiring module "../src/shared/FireworkShows": could not resolve child component "FireworkShows"
    Script '.../roblox/tests/FireworkShows.spec', Line 4
```

**GREEN** after writing the drafts: `1887 passed, 0 failed, 1887 total`.

Draft shape, measured (throwaway Lune probe, not committed):

```
warmup     5 cues   last_ms=4000    densest-in-300ms=1
finale_v1  109 cues last_ms=71300   densest-in-300ms=6
```

109 = 15+6+20+6+5+8+20+6+5+6+12, exactly the brief's count check. Under `LIMITS.maxCues` 120
and far under `maxDurationS` 300. No walk needed adjusting; no limit was touched.
Every shell id used (`peony kiku wa rai willow hotaru banrai yashi kamuro janken`) is in
`shared-fixtures/firework-shells.json`, and every slot is one of `ProvingPlan.RACKS` — the spec
asserts both, against the fixture rather than a transcription.

## The `RequestProvingFire` refactor: why each broadcast field is unchanged

The handler had TWO inline `FireworkLaunched:FireAllClients` calls (rooftop branch, station
branch). Both are now one `Launch.broadcastLaunch` call fed by `Launch.provingOriginFor`.
Field by field:

- **`shellId`** — the handler's own parameter, passed through in both the old branches and the
  new single call. Untouched, and still unvalidated beyond `typeof == "string"`, so the panel's
  `draft:family/variant` ids still ride through exactly as before.
- **`origin`** — the two expressions moved verbatim into `provingOriginFor`:
  `mount.CFrame:PointToWorldSpace(Vector3.new(0, muzzle + 0.2, 0))` (rooftop, with the same
  `mount.Size.Y / 2 + MortarPlacement.TUBE["mortar:L"].length` muzzle) and
  `rack.Position + axis * (rack.Size.X / 2 + 0.1)` (station, same `rack.CFrame.RightVector` axis).
  Character-identical arithmetic; only the return path changed.
- **`heading`** — the old code hand-built `{ x = up.X, y = up.Y, z = up.Z }` / `{ x = axis.X, … }`
  at each site. `provingOriginFor` now returns the raw `Vector3` (`mount.CFrame.UpVector`,
  `axis`) and `broadcastLaunch` performs the identical `{ x = h.X, y = h.Y, z = h.Z }`
  destructuring. `broadcastLaunch`'s `fields.heading and {…} or nil` guard never fires here:
  both proving branches always produce a heading whenever they produce an origin.
- **`seed`** — was `math.random(1, 2 ^ 31 - 1)` inline in both branches; `broadcastLaunch` makes
  the same call. The rooftop branch's *other* draw, `math.random(1, #mounts)` for the mount, still
  happens first and only in that branch, so the RNG consumption order per shot is unchanged.
- **`by`** — the string literal `"proving"`, unchanged.
- **`boosted`** — the expression `if forceBoost == true then true else nil` moved intact to the
  call site. Note it is still the *forced* verdict, NOT `Launch.rollBoost`: the proving path
  deliberately does not touch the pity ramp, and the refactor did not quietly enrol it.
- **`apexHeight`** — was `mount:GetAttribute("LaunchApex")` / `rack:GetAttribute("LaunchApex")`;
  now returned as the third value of `provingOriginFor` and passed through. Same attribute, same
  instance, nil when absent.
- **`showId`** — new optional field on the shared shape, left nil for the fire path. In Luau a
  nil-valued key is an absent key, so the serialized payload is byte-identical to before.

**The one behavioural difference, stated plainly:** the old handler looked up the ProvingGround
rack FIRST and only fell through to the `"hanabiya roof"` branch when that lookup failed to yield
a `BasePart`. `provingOriginFor` checks the roof name first. These diverge only if a `BasePart`
literally named `hanabiya roof` existed under `RoshamboStage.ProvingGround` — and `ProvingPlan`
documents that station as VIRTUAL ("not a ProvingGround rack but the rooftop battery's tagged
public tube mounts"), so no such part is supposed to exist. If one is ever added, the roof
battery would win where the rack used to. Flagged rather than hidden.

The other visible change is that a failed station lookup now returns early from the handler
instead of falling into a nested branch — same outcome (no broadcast), one less level of nesting.

## Controller rulings honoured

1. **Register ceiling.** Zero top-level `local`s added. Everything hangs off `Launch`:
   `Launch.provingOriginFor`, `Launch.FireworkShows`, `Launch.RequestProvingShow`. Verified
   directly rather than assumed — compiling the file with one extra appended top-level local
   still succeeds, with two it fails:

   ```
   as-is compiles: true
   with +1 top-level local: true
   with +2 top-level locals: false — "Out of local registers when trying to allocate __b: exceeded limit 200"
   ```

   So the single remaining slot the brief reserved is still there, unspent. `tests/Compiles.spec`
   is green at O0 and O2.
2. **Remote handle with a timeout.** `remotes:WaitForChild("RequestProvingShow", 10)`; nil ⇒
   `warn` and skip wiring, no `error`, and no stall of the rest of the script.
3. **No empty cue list reaches `playShow`.** The handler only plays `FireworkShows.DRAFTS[name]`,
   and the spec asserts every draft validates — `ShowPlan.validate` fails `EMPTY` on a zero-cue
   list — so `delays[1]` is always present.

## Notes on the show handler

- Studio gate is the *first* statement, identical in form and comment to `RequestProvingFire`'s.
- Stage key is the literal `"proving"`, so a second Play queues behind the first through
  `Launch.stageBusyUntilMs` — the same one-show-per-stage scheduler decks use. Deck shows key on
  `deck:{uid}`, so proving shows and deck shows never contend.
- `ownerUid`/`byLabel` are both `"proving"`. `Launch.rollBoost` therefore keeps a boost-miss
  streak under the fake uid `"proving"`, which is session-lived and shared by all proving shows —
  intentional, and it means show cues get the natural ramped odds rather than the panel's forced
  Boost.
- `showId` is `proving:{name}`, so the client can group a show's shells.
- No validation call on the server for drafts: they are repo data, not wire data, and the spec
  validates them in CI against `PROVING_SLOTS` + the shell fixture. The wire carries only a name,
  which is checked for `typeof == "string"` and then used purely as a table lookup.

## Client panel

Section appended after Shipped, using only the file's own `makeHeader` / `makeRow` / `makeButton`.
Rack toggles are deliberately ignored — every cue names its own station, so a show is a timeline
rather than a shot.

One layout adjustment beyond the brief's text: the finale's title is 36 characters, ~281px at
Code/13, which overflowed the 232px label I first sized and would have painted under the Play
button. The label is now 286px with `TextTruncate.AtEnd` and Play sits at x=290 (ends at 334,
inside the 340px scroll frame — the shipped rows' widest button ends at 284). `TextTruncate` is a
plain TextLabel property, not a new UI primitive.

## Gates

```
$ cd roblox && stylua --check src tests tools && selene src tools && lune run tests/run 2>&1 | tail -3
Results:
0 errors
0 warnings
0 parse errors
[QUEUE] handler error for u: .../tests/HandlerQueue.spec:80: boom      <- pre-existing, an intentional
1887 passed, 0 failed, 1887 total                                          negative-path print
```

## Concerns

1. **Roof-first ordering** in `provingOriginFor` (detailed above). Behaviourally inert given the
   documented virtual station, but it is a real reordering and deserves the owner's eye.
2. **Untested in Studio.** Everything here is verified by Lune tests, the Luau compiler, stylua
   and selene. The pieces that only exist at runtime — the rooftop `FireworkTubeMount` tags
   resolving, 109 cues actually landing inside the director's concurrent-shell budget, the panel
   row rendering at the widths I computed — need a Rojo sync and a Play. `finale_v1` exists
   precisely to be watched, and putting six heavies in the sky at t=62s is the first real test of
   the budget; I would not claim it holds until someone sees it.
3. **`math.random` on the server for mount choice** means each roof cue in a show picks a
   different mount. That matches the fire verb's per-shot behaviour, and reads as a battery rather
   than one tube, but it is a choice worth confirming against the owner's intent for shows.
4. **Boost streak under a fake uid.** `rollBoost("proving", …)` shares one miss-streak table
   across every proving show. Harmless in Studio; noted because it is a synthetic identity in a
   table otherwise keyed by real UserIds.
