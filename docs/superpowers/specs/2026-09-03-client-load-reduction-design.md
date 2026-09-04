# Client load reduction, phase 1 — work nobody has to look at differently

**Date:** 2026-09-03
**Status:** approved in brainstorm (owner + Claude)
**Driver:** the owner's phones. An iPhone 15 holds good frame rates but runs hot
and drains hard; a Samsung A13 clears the place only at Roblox's lowest quality
setting, and only just. Unparks the "Low-end device tier" backlog item
(`docs/wiki/program/backlog.md`), parked 2026-09-03 with "hold on this for the
moment".
**Scope ruling (owner):** this spec covers **only** changes that help every
device with no visual change on any device. The device tier itself — detection,
persistence, and anything a player could see the difference in — is phase 2 and
has its own spec.

## 1. Why this is not a tier

The parked backlog item assumed the wins come from tiering: deciding at join
what a weak phone may skip. A survey of every client loop, every authored VFX
source and every instance count says otherwise. **The largest continuous costs
are work the client does unconditionally, for everyone, whether or not it is
visible.**

- `ChochinSway.client.luau:81` does a `PivotTo` on **every lantern tagged
  `ChochinSwing` in the map, every frame**, with no distance or visibility
  check. `PathLanterns` alone is 2,599 descendants
  (`docs/wiki/world/place-state.md`, verified 2026-08-15).
- `NorenSway.client.luau:81` does the same, walking each noren panel's segment
  chain and writing a `CFrame` per segment per frame.
- `HammerController.client.luau` holds **three** stacked `Heartbeat`
  connections (`:355`, `:398`, `:457`) doing `CFrame` math on the bonshō drive
  continuously, every round, regardless of where the player is or what they are
  looking at.
- `WheelController.client.luau:147` spins every waterwheel paddle every frame on
  the same terms.
- `ShopController.client.luau:434` and `AccessGateController.client.luau:92`
  run proximity tests at full frame rate for triggers a walking player crosses
  in a quarter-second.

None of that checks whether the player can see it. On a phone that is heat with
no picture attached. Removing it costs nobody anything, needs no rulings, and
helps the iPhone 15's battery and the A13's headroom by the same mechanism.

Three structural facts found alongside, none of them tier-shaped either:

- **Streaming radii have never been set.** No `StreamingMinRadius` or
  `StreamingTargetRadius` exists anywhere in git and no script reads or writes
  them; the place runs on engine defaults. This is the broadest untouched lever
  in the game and the one that speaks to the A13's memory ceiling.
- **Every materialized teahouse is forced `Persistent`**
  (`TreatmentApplier.luau:154-156`), so it never streams out for any client.
  Cost scales with occupied pads across the whole server, for everyone. Unlike
  the stage persistence at `main.server.luau:141-143`, no comment justifies it.
- **The stats-room flap boards set no `MaxDistance`**, so ~8,400 GUI instances
  (`docs/wiki/log.md` 2026-08-17, owner-measured on the A13) render from outside
  the room.

## 2. The rule, and where it lives

**A client should not spend a frame on something the player cannot see.**
Nothing enforces that today outside foliage.

`FoliageImpostorController` + `ImpostorFade` are the house pattern for exactly
this: a `.client.luau` file owns the Roblox-side vector math and the
`CollectionService` bookkeeping, and a pure `src/shared` module owns the policy
so Lune can test it (no harness in this repo loads a `.client.luau` — see
`NorenSway.client.luau:14`). Phase 1 follows that pattern rather than inventing
one.

**New: `roblox/src/shared/AmbientBudget.luau`** — pure, no Roblox globals, three
functions and a config:

```
export type Config = {
    radius: number,     -- studs; beyond this, do not animate
    behindDot: number,  -- normalized forward dot below this = behind the camera
    interval: number,   -- seconds between updates while visible
}

AmbientBudget.DEFAULT: Config = { radius = 180, behindDot = -0.15, interval = 1 / 30 }

AmbientBudget.inRange(distSq: number, cfg: Config): boolean
AmbientBudget.inView(forwardDot: number, cfg: Config): boolean
AmbientBudget.step(acc: number, dt: number, interval: number): (boolean, number)
```

Two deliberate shapes here:

- **The module takes scalars, not `Vector3`s.** It holds policy; callers hold
  vector math. That is what keeps it loadable under Lune, and it matches
  `ImpostorFade`, whose `planeNormal` returns a plain `{x, z}` for the same
  reason.
- **Range and view are separate calls, in that order.** `inRange` needs no
  square root; `inView` needs a normalized dot and therefore does. For lanterns
  strung the length of a canyon most candidates fail range, so the cheap test
  must be able to run first and short-circuit.

`step` returns `(fire, nextAcc)` rather than mutating an accumulator, so the
throttle is testable as a pure function.

**Live-tuning:** `AmbientRadius`, `AmbientBehindDot` and `AmbientHz` on
`Workspace`, defaulting to `AmbientBudget.DEFAULT` — the same convention
`FoliageImpostorController` uses for `ImpostorCapFadeLo` and its neighbours, so
the owner can tune during the walk without a rebuild.

### Why culling is free for time-derived animation

`ChochinSway` and `NorenSway` compute their pose as a pure function of
`os.clock()` — they do not integrate state frame to frame. A culled lantern
therefore resumes at exactly the correct phase the instant it re-enters view.
There is no drift to accumulate, no pose to reset, and no re-entry pop. This is
a property of the existing code, and it is what makes phase 1 free rather than a
trade.

Anything that *does* integrate is called out individually below and keeps
integrating while culled.

## 3. The loops

### 3.1 `ChochinSway.client.luau`

Throttle to `interval` and gate per lantern on range then view. The entry table
already caches `base` (a `CFrame`), so the position is in hand with no instance
read. Expected shape change: from *every tagged lantern in the map at frame
rate* to *the lanterns on screen at 30 Hz*.

### 3.2 `NorenSway.client.luau`

Same treatment, gated per panel on the cached `panel.hinge`. Noren are doorway
props on the machiya row; most are behind the player or out of range whenever
they are not being looked at directly.

### 3.3 `WheelController.client.luau`

`angle += dt * driveOmega * wheelDir` **integrates**, so:

- Keep accumulating `angle` every frame while culled — one multiply-add, and
  the wheel must be in the right place when it comes back rather than resuming
  from a frozen phase.
- Gate only the `CFrame` writes (the hub, and every paddle) on visibility.
- The splash `:Emit(3)` boundary counter must keep updating `lastStrike[side]`
  while culled and simply not emit. Letting `k` advance without updating
  `lastStrike` would fire a burst on re-entry for a strike the player never saw.

### 3.4 `HammerController.client.luau` — split, do not simply gate

⚠ **The middle loop (`:398`) is load-bearing and must keep running every
frame.** It is not decorative:

- it detects the bell strike (`metronome:strikesBetween(lastMetroNow, nowSt)`,
  using `lastMetroNow` as the previous sample) and calls `strike()` — throttling
  it delays the bonshō, and culling it silences it;
- it publishes `DriveOmega`, which `WheelController` reads as its rate;
- it carries the self-healing backstop for a dropped `RoundUpdate` broadcast
  (spec: the machine never stops);
- it retries `captureSpinners()` until parts replicate.

So the work is a **split**, not a gate. The timing half — metronome read, strike
detection, `lastMetroNow`, the `striking` backstop, the `DriveOmega` write — is
a handful of scalar operations and stays unconditional at frame rate. The
expensive half — the `CFrame.Angles` construction and the three
`camSpinners` / `driverSpinners` / `jackSpinners` write loops — is what gets
range/view gating.

The other two loops are safe to gate as they stand: `:355` (the draw) poses one
part from `r.drawP`, time-derived and free-resuming; `:457`
(`updateSuspension`) recomputes chains and dowels from the log's live `CFrame`
every frame, so it self-corrects on its first frame back and needs no reset.

**Honest expectation:** players spend much of their time in the arena square
looking at this machine, so stage gating pays off mainly when they are away —
on the teahouse tour, at the shops, in the stats room, or up on a deck watching
fireworks. The lantern sway is the larger and more reliable win, because most
lanterns are off-camera almost all the time.

### 3.5 `ShopController.client.luau:434` and `AccessGateController.client.luau:92`

Convert both per-frame proximity `Heartbeat`s to the 0.25 s poll
`TourBeamController.client.luau:102` already uses. At walking speed the
difference is imperceptible, and `AccessGateController`'s fade already
interpolates independently of the test rate.

### 3.6 `AuraController.client.luau:363`

Wire the simultaneous-glow cap the file's own comment anticipates but never
implemented ("too many players glow at once on a phone"). Cap the number of
enabled `Highlight`s, preferring the nearest; the rest keep their row and get no
highlight. This changes nothing on a normally-populated server and bounds the
worst case.

### 3.7 Explicitly not touched

`BirdController.client.luau:572` already has working `DRAW_DISTANCE` (90) and
`DETAIL_DISTANCE` (45) gating. Tightening those constants trades visible bird
behaviour for frames, which makes it a phase-2 tier judgement, not an
unconditional fix.

`DayNightController` (10 Hz, accumulator), `TourBeamController` (4 Hz),
`FoliageImpostorController` (10 Hz) and the reveal-window HUD loops are already
gated and stay as they are.

## 4. The structural three

### 4.1 Streaming radii

Set `Workspace.StreamingMinRadius` and `Workspace.StreamingTargetRadius` from
the server at boot, beside the existing `StagePersistence` block in
`main.server.luau`, and publish both as `Workspace` attributes for live tuning.
Code-owned and in git, self-healing on every boot — the same treatment
`ArenaSpawn` and stage persistence already get, and the reason this is not left
as place data.

Starting values: min at the engine default, target **512** (down from the engine
default 1024). The stage and the horizon backdrop are `Persistent` and therefore
unaffected; what tightens is the far canyon — `PathRailings` (5,186
descendants), `PathLanterns` (2,599), foliage — which is precisely the bulk the
A13 is carrying.

⚠ **This value needs the owner's eyes, not a test.** The canyon has long
sightlines, and the failure mode is content popping in at the edge of view.
Tune live on the walk; record what lands in `docs/wiki/world/place-state.md`.

### 4.2 Teahouse persistence — an investigation with a decision rule

`TreatmentApplier.luau:154-156` marks every materialized teahouse `Persistent`.
The stage does this for a documented reason (spawn-watchers 200 studs out, and
controllers that capture parts once at startup); teahouses are built at runtime,
after those controllers have started, so that specific justification does not
transfer. Nothing in the file or the wiki says why it is here.

This is the largest potential A13 memory win and the only change in phase 1 that
could break something, so it is scoped as an investigation, gets its own commit,
and resolves by rule rather than by preference:

1. Establish what depends on a **distant** teahouse's parts existing —
   `TeahouseController`, `DecorationController`, `EconomyController`'s prompts,
   `ShojiRun`, and anything doing `WaitForChild` against a structure it does not
   own.
2. If nothing does, remove the line and let teahouses stream like the rest of
   the far canyon.
3. If something does, narrow persistence to the viewer's own claimed pad rather
   than removing it, and record what forced that.
4. If neither can be established with confidence, change nothing and ledger the
   finding for phase 2. **A guess here is worse than the status quo** — the
   status quo is merely expensive, and a wrong guess breaks other people's
   teahouses.

### 4.3 Stats-room GUI `MaxDistance`

Set `MaxDistance` on the flap boards' `SurfaceGui`s. A flap cell costs about
seven GUI instances (`FlapBoard.luau:215-218`) and the room holds roughly 8,400;
none of them are legible from outside the room, and today none of them stop
rendering.

Per board class, not one global number: the vestibule `fuda` and the three wall
boards are read from within a few studs, while the cavern round display is read
from across the cavern and needs a value that reaches. `StatusBarController.client.luau:49-50`
is the in-repo precedent for the property.

## 5. Risks

- **Shadows.** A prop frozen while off-camera can still cast a shadow that is on
  camera. At 3.2° of lantern sway this is invisible; the waterwheel is the one
  to look at directly on the walk. If it reads badly, the wheel keeps its
  `CFrame` writes and loses only the throttle.
- **Water reflections** have the same shape as the shadow risk and want the same
  check.
- **`behindDot` is a margin, not a frustum.** −0.15 culls only what is clearly
  behind the camera, deliberately leaving slack for wide FOV and fast turns
  rather than computing a true frustum test per instance per tick.
- **No new benches.** Per `docs/wiki/practice/perf-harness-contamination.md`, any measurement
  harness written during this work is parked in the same session it reports, and
  nothing profiling-related goes near `StarterPlayerScripts`.

## 6. Testing

- **New:** `roblox/tests/AmbientBudget.spec.luau` — range boundary, view
  boundary, the accumulator's fire/carry behaviour across a frame slower than
  the interval, and defaults. `ImpostorFade.spec.luau` is the model.
- **Unchanged and load-bearing:** the existing 129 spec files must stay green;
  `Compiles.spec.luau` covers the edited client files automatically.
- **No new coverage is claimed for the `.client.luau` edits.** The harness
  cannot load them. Their correctness rests on the pure module plus the owner's
  walk, and this spec says so rather than implying otherwise.
- **`TreatmentApplier` has no spec today.** If §4.2 changes it, the change is
  verified by a Studio part-count check before and after, plus the walk.
- **House gates:** `stylua src tests tools && selene src tools && lune run tests/run`,
  then `rojo build`.
- **The real gate:** the owner's walk on both phones — arena, the machiya row,
  the teahouse pads, the stats room, and a fireworks launch — watching for
  frozen shadows, popping content, a silent bell, and a stalled waterwheel.

## 7. Build order

1. `AmbientBudget` + spec (pure, no callers yet).
2. `ChochinSway`, `NorenSway` — the biggest win, and the simplest proof the
   module is shaped right.
3. `WheelController` (integration preserved), then `HammerController` (the
   split).
4. `ShopController`, `AccessGateController`, `AuraController`.
5. Streaming radii, published as attributes.
6. Stats-room `MaxDistance`.
7. Teahouse persistence investigation, own commit, per §4.2's rule.
8. Owner's walk on both phones; tune `AmbientRadius` / `AmbientHz` /
   `StreamingTargetRadius` live; record landed values in `docs/wiki/world/place-state.md`.

## 8. Phase 2, and the rulings it inherits

Out of scope here, carried forward with the owner's rulings already attached:

- **The tier itself:** a `DeviceTier` shared module, auto-detect at join (the
  `TouchEnabled and not KeyboardEnabled` test is currently duplicated inline in
  `HudController`, `OnboardingController` and `SplashController` and wants the
  same home), `UserGameSettings.SavedQualityLevel`, memory, an early frame-time
  sample.
- **A persisted player override** (owner ruling: auto-detect *plus* an override,
  because auto-detect misreads tablets and gaming phones both ways). Costs a
  `HudPrefs.luau` field, a matching field on the Node `User` model, the
  `preferences-hud` route, and a settings row — the preference plumbing already
  exists and is tested, so this is an extension rather than new machinery. Note
  the ordering problem for whoever designs it: the stored preference arrives on
  the `ProfileUpdate` round-trip, *after* join, so a detected default must apply
  immediately and yield to the stored value when it lands.
- **Owner ruling on what a low tier may cut: ambient only.** World dressing —
  static lanterns, thinner foliage, no backdrop, quieter water — is fair game.
  The arena square, the drum, the fireworks and anything a player reads during a
  round keep their full look on every device.
- The four backlog gates that follow from that ruling: fireworks star counts,
  water motion, lantern and glyph glow, backdrop.
- Widening `OffstageCull`'s impostor swap set; `BirdController`'s distance
  constants; the `FireworkDirector` budget at low tier.
- The post-demo day/night default (open question stays open).

## 9. Out of scope entirely

- Anything that changes how the place looks on any device.
- Geometry rebuilds, foliage re-scatters, prop simplification.
- The PWA (`src/`) and the Node server, except the phase-2 preference field.
- Roblox's own frame-rate cap, which belongs to the player and is the single
  biggest battery lever either of us has.
