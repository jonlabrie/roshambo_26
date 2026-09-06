---
shelf: world
updated: 2026-09-06
checked: 2026-08-27
---

# Fireworks

Purchasable/earnable fireworks are a core Roshambo feature and a driver of the world
design: teahouse decks and the high mid-canyon suspension bridge (y≈222, kept
deliberately as a perch) are prime viewing spots. F&F item 3 ([[friends-family-baseline]]):
**the whole loop — economy, referee, spend, director, phase player — was verified
working in game by the owner on 2026-08-13** (bought shells, consumed them at the
Overlook, ishibana gated correctly on the world throwing Rock).

## As built

- 9-task build pushed 2026-08-05 (`a25f0c7..743665d`, one push so server and Roblox
  never disagree); ledger `.superpowers/sdd/2026-08-05-fireworks-core/progress.md`
  records every task and departure. Decisions live in pure modules
  (`src/shared/FireworkDirector.luau`, `FireworkSchedule.luau`, `LaunchSites.luau`,
  `FireworkCatalog.luau`); `FireworkController.client.luau` owns instances and obeys.
- **Launch sites**: a player's own deck, plus three tagged `FireworkLaunchSite` parts
  — `Site_SuspensionBridge`, `Site_FallsDock`, `Site_Overlook` under
  `CanyonWorld.LaunchSites` (verified in the place 2026-08-15).
- Shop front-end: [[hanabiya]].
- **Proving range (2026-09-01, branch `proving-range`, working — owner comments pending)**:
  the authoring loop for new shells. Draft recipes in `src/shared/FireworkDrafts.luau`
  (families of variants, ids `draft:<family>/<variant>`, never in the CI fixture);
  schema `FireworkRecipes.luau` makes the blank-sky trap a test failure; Studio-gated
  `RequestProvingFire` fires any draft/shipped id from five mortar STATIONS SCATTERED
  ACROSS THE CANYON (owner placement 2026-09-06, superseding the bridge line: "north
  arena", "bridge", "upper north", "mid pool", "hi west" — each station's tube
  orientation IS its launch heading, honored by the fire path; positions live-surveyed
  and baked into tools/builders/ProvingGround.luau STATIONS, spec-enforced). ⚠ VANTAGE CORRECTED 2026-09-05 (owner): the range is judged from the SOUTH
  TERMINUS of the suspension bridge, edge-on to the five racks and close -- NOT from
  FallsLanding ("I'm not using FallsLanding AT ALL"). The ~190-stud FallsLanding sightline
  was the design assumption (the plaques were sized to it) and never the practice; tuning
  targets the close, edge-on read. Panel opens
  ANYWHERE in Studio (P key / top-right chip, left-edge rail — a location-bound panel
  was ruled theater and the FiringPost deleted); modes single (rack A–E selector),
  ladder (variants side-by-side), sequence (2s apart); night via `ProvingNightOverride`
  Lighting attribute that DayNightController's tick respects. Mortars are accurate
  2"/4"/6" at ~4–5:1 (owner ruling; **yonshakudama parked as a future premium
  spectacle**). Spec `docs/superpowers/specs/2026-09-01-proving-range-design.md`.
- **The Hanabiya rooftop battery + the MC experience (built/gated/published 2026-09-06 per the
  log; design banked on [[backlog]] § Rooftop MC experience)**: a railed platform over the shop
  ridge (Rojo asset `HanabiyaRooftop`), three CSG tubes on tagged mounts aimed north over the
  arena, the virtual sixth station; public gear launches within 140 studs fire from its nearest
  muzzle. Access deliberately unbuilt so it stays gateable. Owner intent: buy/win access to a
  proving-panel-like console and MC a show for the arena. Public access to the five stations by
  jukebox-style play queueing is banked beside it. Cross-linked 2026-09-05 because neither this
  page nor [[hanabiya]] pointed at either entry.
- ⚠ **Every shipped burst 2026-08-05 → 2026-09-01 rendered as a flat vertical line**:
  the bench's `SpreadAngle (360,360)`, drag and fade curve never made it into
  `FireworkController`'s pool, so particles fired straight up. Invisible from below at
  the Overlook; exposed by the proving range's first eye-level sightline and fixed in
  `adaa1fe`. Reaches players on the next place publish.
- **Vocabulary wave one (2026-09-04, merged)**: five burst styles (peony/ring/palm/
  strobe/kamuro) as a `style` field on burst phases — `BurstStyles.luau` is the one
  source of truth (emitter config, point rules, texture/sound ROLE tables, tail
  voices, completeness test-enforced because pool emitters are shared). Staged
  multi-burst shells work (`points`/`scatter`/`share` validated; `dan` is the
  three-act demo). Glow stack: LightInfluence 0, per-style Brightness ~2-3,
  color-over-life (white ignition → saturated burn → blackbody ember → near-black
  death = additive glow to zero), per-style lightEmission <1 as the stacking law.
  Flights ~3s (owner ruling), apex 60, per-frame bezier ascent (TweenService stepped
  at ~15Hz — measured — and was replaced), 2.4s fading trail, muzzle flash. Audio:
  owner-picked kingsrow launch thump, SILENT ascents (owner ruling), 4-variant
  seeded aerial burst pool, speed-of-sound delay per listener (1125 studs/s),
  startup preload, volume 2 / rolloff 45-400. Hotaru carries the owner's own
  canyon-echoed sizzle as a phase-bound TAIL VOICE (second Sound per slot, engine
  fade at duration). Families: kiku, wa, yashi, hotaru (+tail), kamuro, ao (blue),
  midori (green), murasaki (violet) — the last three as shape/hue ladders; willow
  re-authored gold. Spec docs/superpowers/specs/2026-09-02-fireworks-vocabulary-design.md.
- **Deck mortars (2026-09-04, merged `bc82000..31dcd6f`, dev-deployed, GATED
  2026-09-04 — gate fixes `9d3cd3c..9aa660a`)**: owned mortars render as tubes ON
  the owner's deck and gear shells
  launch from the required tier's MUZZLE (kiku/peony → S, willow → M);
  `firecracker` stays hand-launched; public sites unchanged. Default-first (owner
  ruling): S/M/L auto-stagger along the canyon-facing front edge, movable (never
  removable) through the decoration drag flow — `SetMortarPlacement` remote, gear
  exempt from the 24-decoration cap. Decisions in pure
  `src/shared/MortarPlacement.luau` (defaults/clamp/teahouse-nudge/muzzle math);
  tubes are SERVER-built in `TreatmentApplier:_buildMortars` so visitors see every
  deck's arsenal (a mid-plan correction — the plan assumed client-side render, which
  would have been owner-only; spec's "visible to every visitor" won). Muzzle-truth
  is structural: `BuildingPlacer.resolveFit` feeds both the rendered tube and
  `muzzleOriginFor`, so the shell leaves the tube you see, nudge included.
  Persistence mirrors `deckDecorations` (`User.mortarPlacements`, validated PUT,
  Mixed + `markModified`). Final review caught pre-ship: a rejoin-invisibility
  fingerprint bug (fresh Play sessions can't surface it — the gate must include a
  same-server rejoin) and a muzzle deck-size mismatch on display-shrunk decks.
  `SHELL_MORTAR` is fixture-enforced in both suites (see promotion pipeline
  amendment in the proving-range spec §5). The owner gate found six more (all fixed
  same-day, see log): front edge is local MINZ not maxZ (verified against the live
  place: Nobori on −Z, back-door PortalControl on +Z — the plan's +Z premise was
  wrong), PivotTo un-rolled the stood-up tube (rolled-cylinder PrimaryPart), tubes
  drew 3× fat (bore is the INNER diameter — owner ruling), a mortar is an EMPTY tube
  (real CSG hollow, one SubtractAsync per tier at boot, cloned after; two fake-disc
  attempts rejected), the boot-time CSG yield made the server MISS the joining
  player (PlayerAdded handlers have no catch-up loop — deferred via task.spawn), and
  join-time replication fired the tag signal before the padId attribute applied so
  no Move prompts bound (decorations included — a latent shipped bug). Firecracker
  now launches from HAND height, not 6 studs overhead. The same-server-rejoin
  fingerprint fix was LIVE-VERIFIED 2026-09-05 on the published place (two-device
  hold-open, leave/rejoin: tubes present at their placements). Spec
  docs/superpowers/specs/2026-09-04-deck-mortars-design.md; ledger
  `.superpowers/sdd/2026-09-04-deck-mortars/progress.md`.
- **Rail mounts (2026-09-05, merged `24c6da9..8e1a61b` + gate fixes `27b410d..dcdffed`,
  GATED)**: mortars are aimable hardware — `{mount: floor|rail, offset, aim: L|C|R}` records
  (legacy reads floor/C at the saved spot, never relocated), three aims in a 60° arc anchored
  to deck-front, elevations rail 25°/floor 12° (owner-tuned constants in
  `MortarPlacement.ELEVATION`). One pose, two consumers: `MortarPlacement.axisLocal/pose/launch`
  is the only source of tilt — render (`TreatmentApplier`), launch heading
  (`FireworkLaunched.heading`), and the editor ghost all read it, so aim/render/trajectory
  cannot drift. Flight generalized from vertical: BALLISTIC apex (peak `2h·tan θ` downrange,
  bezier control where the tube-axis line reaches apex height — leaves true to the tube,
  arrives flat at the break; nil heading = byte-identical old flight, so public sites/proving/
  firecrackers untouched). Editor: the DROP decides the mount (1.25-stud rail snap band —
  includes the floor-default spot, owner-accepted), R cycles L→C→R with a leaning ghost.
  **DEFAULT_MOUNT = rail** (owner lever, pulled at gate): record-less tubes saddle the rail out
  of the box. Gate finds: (1) tilted flights unfolded the comet Trail into the OLD wide band —
  the attachment pair's local-Y offset is only thin when parallel to motion; the shell part now
  orients its Y along the heading (`07ab0fa`; the owner's elimination set — public fine,
  proving fine point-blank, deck wrong — cornered it after two wrong diagnoses); (2) the
  prompt-binding saga ended in TWO root causes + a convergence belt: DecorationController can
  miss the join echo (RemoteEvents don't queue for late listeners; idle players get no
  reveal-time push — it's gated on having picked) → it now pulls its own `RequestSync` re-echo,
  plus a 3s rescan heartbeat that makes binding converge from ANY join interleaving
  (`27b410d`, `862568c` — five orderings were patched before instrumentation found the truth);
  (3) the lever's fall-through would have swept legacy records onto the rail — guarded
  (`dcdffed`). Same-server rejoin verification PASSED live 2026-09-05. Spec
  docs/superpowers/specs/2026-09-04-rail-mounts-design.md; ledger
  `.superpowers/sdd/2026-09-04-rail-mounts/progress.md`.
- **Promotion worksheet (as of 2026-09-06)**: shipped through the five guarded steps —
  **wa** (red double-ring, M tube, 5; boost 30% = structural second ring via the first
  `boostOnly` phase, no kicker — "the double ring IS the tell") and **yashi** (palm,
  M tube, 10; boost 30% = fifth arm via `boost.points` + violet `kickerStreaks` rain,
  `e791ebd`). **Colorway ruling (owner, 2026-09-06): signature hues sell in the shop,
  colorways live in collections** — ao/midori/murasaki reframed as collection palette
  material, drafts pruned (archived at `2cd90b4`). **kamuro** shipped 2026-09-06
  (`3115d8d`): the L tube's "cheap round to show off the big gun" (owner), price 10,
  mortar:L — the first `heavy` shell (double sprites under weighted admission, spread
  60, the eardeer boom on every break, 30% salvo kicker of 3-4 aerial salutes with
  purpose-made flare art). **hotaru** shipped 2026-09-06 (`439aae1`: v3 floor, second-shimmer structural boost,
  M tube, 8 -- plus the strobe re-pop machinery and rotated burst voices the audition
  surfaced). **janken** shipped 2026-09-06 (`559c850`, born as "dan": THE SIGNATURE SHELL -- four
  color-dealt mini-peonies, then the triple palm bloom carrying the three CANONICAL
  throw glyphs, spun and re-dealt per shell in one dealt color, falling long and
  flickering out under the owner's sizzle; 30% salute-salvo encore; L + heavy, 12 --
  "right above kamuro... there's some Roshambo promo built in"). New vocabulary built
  for it: colorPool decks, per-point texture pins, the point-rotation fix for
  overlapping phases, the star-size floor; the whizzer style + wild point rule wait
  unused for a future shell; the random BONUS shell was removed. **rai** and **banrai** shipped 2026-09-06 (`dd0d1ce`, the first NO-AUDITION
  promotion, owner-delegated): the salute class standalone -- 雷 rai (S, 4; 3-4 bangs)
  and 万雷 banrai (M, 7; 6-8 bangs), a small pop carrying an always-on salvo
  (chance = 1). **THE WORKSHEET IS EMPTY** -- all judged families shipped or moved to
  collections. Twelve shells on the shelf.
  Launch audio: thumps are a 3-clip seeded rotation (launch-deck-1/2/3) with
  launch-deck-4 as the **L tube's grunt** (`292e978`, live via kamuro); per-clip head
  trims measured from source WAVs (peak−35ms).
- **The comet look is PINNED** (owner, 2026-09-06: "yes, these are the ones. Let's not
  lose this place!"): tag `trails-approved` (= `8232c98`) is the approved ascent-trail
  behavior for every style. Three widening strategies for a fatter L trail all failed
  (see log 2026-09-06 "clean retreat" -- the thin comet IS the collapse of a
  span-parallel Trail; widening un-collapses it into the band). The one untried avenue
  for a bigger heavy ascent was a LAYERED particle comet on heavy shells, leaving the
  Trail untouched -- BUILT and owner-approved same day (`7c96c43` + tuning `6a0974b`):
  a dedicated Rate-driven emitter streams glow sparks behind the rising L shell
  (rate 90, ~50 alive, ~6% of the heavy budget), colored from the ascent, doused at
  the break. The pinned Trail is byte-untouched.
- VFX recipe (proven on device): rising Trail comet → flash core → radial burst →
  glitter/willow, glow via LightEmission + the one global Bloom, ~500–700
  particles/shell, client-side emission (server `Emit()` does not replicate).

## Performance rules (binding)

- Client-side VFX only; the server sends a tiny launch event.
- No per-shell dynamic PointLights (the #1 killer); pooled emitters and sounds; no
  instance churn; distance LOD.
- A global **fireworks director with a concurrent-shell budget** (~12–16 nearest
  bursts rendered, the rest staggered 100–300 ms) decouples perf from player count.
- **Measured floor** (A13, 2026-08-05, bench v2): 10 shells/sec at quality 5 and on
  Automatic — impacted but usable, at 30–100× single-player rates, with fill-rate
  worst-cased (launches within 18 studs). The particle budget is validated on the
  weakest device owned.
- ⚠ unverified: **the global concurrent-shell director has never been exercised at
  scale** — the bench is one launcher at the local player's feet, so a 50-player
  battle remains the untested load-bearing case. The measured floor does not make
  the cap optional.
- Mandatory bench hygiene: park a perf bench the instant its reading is taken (the
  v1 bench left enabled in StarterPlayerScripts caused a full session of false
  "world is too heavy" diagnosis). Bench v2 is parked at
  `ServerStorage.FireworkBench_PARKED` (verified 2026-08-15); its HUD version is not
  folded back into the committed `buildFireworkBench.luau`.

## Gates & decisions

- 2026-08-13 owner gate in Play closed both live bugs: the first-person shop-panel
  cursor trap (`322d948`) and the cramped interior (`22bcf2e`) — details on
  [[hanabiya]].
- **Monetization = Lens B** (owner, 2026-07-20): fireworks pilot real money on the
  Roblox side — points buy everyday shells (the points sink), Robux buys
  premium/finale packs; cosmetic + consumable + never touches the RPS loop.
  Developer Products, grant only in server `ProcessReceipt` (idempotency via
  PurchaseId; `PromptProductPurchaseFinished` is a trap). A "shared show" SKU (buy
  the whole server a finale) is a planted design idea.
- **Owner emphasis**: a large number of DIFFERENT firework types is critical to the
  game's financial success — shell taxonomy is a first-class design goal.
- Eyeline analysis kept the bridge: western teahouses sit at ~bridge height and look
  down past it; only pillars-to-water would block.

## Shows and the sequencer (sub-project B, built 2026-09-05)

Spec `docs/superpowers/specs/2026-09-05-fireworks-show-system-design.md` §1–§3; plan
`docs/superpowers/plans/2026-09-05-fireworks-shows-sequencer.md`.

⚠ In every cue, log line and API body the Bottle Rocket is `firecracker` — the id predates the
player-facing rename and stays (it keys the win grant, the Mongo inventory field and the shared
fixture); ids are for the machine, names are for the kid.

**A show is data**: cues of `{ t_ms, slot, shellId }`, validated by twins held to
`shared-fixtures/shows.json` (`server/src/shows.ts`, `roblox/src/shared/ShowPlan.luau`). Limits
are config (`SHOW_LIMITS` / `ShowPlan.LIMITS`: read them, do not quote them). A hostile cue table
with holes is refused before validation ever runs — `ShowPlan.dense` accepts only keys that are
positive integers running 1..n with no gap (`#t` is a border, not the largest key, so the count is
checked against the largest key), and projects every entry down to exactly `t_ms` / `slot` /
`shellId`, so extra fields never reach validation, the wire or playback; anything else is refused
outright. The guard exists because the validator walks with `ipairs`, which stops at the first gap
and would have validated only the prefix. Condition shells (`ishibana`) validate like any other:
their condition is a client-side `launchable` gate today, on every launch path, and the per-cue
fire-time re-check belongs to sub-project C. **Reserve, then play**:
`POST /api/v1/players/:id/shows/reserve` debits every shell in ONE conditional update or nothing
(inventory fuel only — powder is sub-project A; deck stage only — the rooftop and stations arrive
with consoles in C). The game server plays a reserved show on its own clock
(`roblox/src/shared/ShowPlayer.luau` timing; one show per stage, a second queues behind through
`Launch.stageBusyUntilMs`), emitting each cue through the same `FireworkLaunched` broadcast as a
hand launch, with `showId` added and the pity ramp applied per cue. **Origins are snapshotted at
go, BEFORE the reserve** — one muzzle resolve per distinct mortar slot, plus the hand frame — so a
show outlives its owner leaving, which otherwise nils their economy record and leaves every
remaining cue with no origin to fire from. Resolving first also means a refusal never costs a
shell: if any mortar slot the show uses has no muzzle on that deck, the whole show is refused with
nothing debited, rather than debited and then played as its hand cues alone. Origins do not move
during a show, so the snapshot is exact, not an approximation.

⚠ **`main.server.luau` is at Luau's 200-local-register ceiling**, so every server-side addition
in this build hangs off a single `Launch` namespace table rather than taking top-level locals;
`roblox/tests/Compiles.spec.luau` is what makes the ceiling fail in CI instead of as a dead script
in Studio. Exactly one top-level slot remained after this work. Further server work in that file
needs real module extraction first — count the slots by compiling, not by trusting this line.

**Studio-only proving verb**: the proving panel's *Shows* section plays `FireworkShows.DRAFTS`
(`warmup`, `finale_v1`) from the five stations and the rooftop battery. `warmup` is a five-cue
timing check by eye. `finale_v1` is the stress program — volleys that put six bursts in the sky
inside 300 ms and a finale that stacks heavies — authored to exercise the director's
concurrent-shell budget at scale for the first time. Its size is authored, not fixed: read
`roblox/src/shared/FireworkShows.luau` for the current program and
`roblox/tests/FireworkShows.spec.luau` for the floor it must clear (both drafts validate against
the proving slots, shipped shells only). As authored 2026-09-05 it is 109 cues, the last at
71.3 s, with its densest window six cues inside 300 ms.

**The A13 gate — measure, don't assume.** The plan first said "run `finale_v1` from the panel
with the A13 joined" — impossible: the panel and both proving verbs are Studio-only (2026-09-01
ruling, "everything Studio-gated, nothing allowlisted"), a phone can only join the PUBLISHED place,
and there is one place. **Decided 2026-09-06 (owner: "sure, start on 1"): a server-only door.**
`main.server.luau` creates a `BindableEvent` named `PlayProvingShow` in `ServerStorage` at boot and
routes it to the same `Launch.playDraft` the panel uses, minus the Studio check. A BindableEvent can
be fired only by SERVER code, and the only way to run server code in a live place is the Developer
Console's server command bar, which Roblox grants to edit-permission holders — so reachability is
"can edit the experience", Roblox's own permission model, not a userId list; the 2026-09-01 ruling
stands. Cues fired this way carry `by = "console"`. The gate is post-merge and post-PUBLISH; from
the desktop client in the published place, `/console` → Server tab:

```lua
game:GetService("ServerStorage").PlayProvingShow:Fire("finale_v1")
```

Whatever the path, record: frame-rate behaviour during the 15 s, 32–33 s and 62–65 s volleys;
whether bursts are visibly staggered (expected: yes, by a few hundred ms) or dropped (never
expected); audio reach; and whether the owner's camera hunts — every show cue carries
`by = owner`, so each one fires the own-launch look; gating that to cues without `showId` is the
fix if it does. Park the bench per the standing rule. Result: **not yet run** — this line is the
live fact, and the Studio-only proving verb remains the right tool for judging a show's SHAPE on
the desktop before any of the above.

## Powder and drops (sub-project A, built 2026-09-06)

Spec §7; plan `docs/superpowers/plans/2026-09-06-powder-and-drops.md`. **Powder buys only things
that burn.** Flows: `POST …/powder/topup` (points → powder, one way, positive integers only);
`POST …/fireworks/melt` (shells → powder at list price, `powderEligible` shells only — the list of
ineligible shells is `shared-fixtures/firework-shells.json` `powderIneligible`, EMPTY today);
`POST …/powder/grant` (external: Robux receipts, gifts, ops — idempotent by `receiptId` via the
`PowderGrant` collection); `shows/reserve` accepts `fuel: "powder"` (summed list price, one
conditional update). Every move is a conditional `$inc`, or on the grant path a plain `$inc`
guarded by the receipt row's unique index. `powder` rides on `/economy` and
`/fireworks`; `ShellState` carries `powderEligible`.

**Drops by streak tier** replace the flat firecracker-per-WIN: `shared-fixtures/firework-drops.json`
(default `firecracker`, tiers at 3 → `peony`, 5 → `wa`, a golden ticket at 6 with the default shell
beside it; one ticket per crossing) — starting values, re-read the fixture rather than this line.
Awarded on the WIN event inside settlement's single atomic write, so neutral to Bank vs Stake.
Tickets are minted by `$push` with a random UUID (`server/src/engine/Settlement.ts`), which is
idempotent only because settlement has exactly one caller — if sub-project C ever re-settles a
round it would mint twice, and a deterministic id `${roundId}:${userId}` with `$addToSet` closes
that in one line. ⚠ Until the Hanabiya melt verb ships, a tier drop REPLACES that round's
firecracker, so a player without the matching mortar receives a shell they can neither fire nor
melt (peony needs `mortar:S`, wa `mortar:M`); the melt verb closes the window — weigh it before
the dev redeploy.

**Not here:** the Hanabiya's melt UI (a client change once `main.server.luau` is split — the
`NetworkClient` calls exist), ticket redemption/gifting/booking (C), Robux product ids.

## Raw layer

- ledger: `.superpowers/sdd/2026-08-05-fireworks-core/progress.md`; device floor
  note `docs/superpowers/canyon/fireworks-mobile-floor-2026-08-05.md`
- key commits: `a25f0c7` shell ledger · `743665d` picker · `322d948` cursor ·
  `22bcf2e` shop depth
- bench: `roblox/tools/studio/buildFireworkBench.luau` (lessons in header);
  site tagger `tools/studio/tagLaunchSites.luau`
