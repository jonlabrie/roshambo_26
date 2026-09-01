---
shelf: world
updated: 2026-09-01
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
  `RequestProvingFire` fires any draft/shipped id from five mortar racks ON THE
  SUSPENSION BRIDGE (owner siting; surveyed catenary — per-station height + inward
  tilt), judged from FallsLanding ~190 studs west at burst eye level. Panel opens
  ANYWHERE in Studio (P key / top-right chip, left-edge rail — a location-bound panel
  was ruled theater and the FiringPost deleted); modes single (rack A–E selector),
  ladder (variants side-by-side), sequence (2s apart); night via `ProvingNightOverride`
  Lighting attribute that DayNightController's tick respects. Mortars are accurate
  2"/4"/6" at ~4–5:1 (owner ruling; **yonshakudama parked as a future premium
  spectacle**). Spec `docs/superpowers/specs/2026-09-01-proving-range-design.md`.
- ⚠ **Every shipped burst 2026-08-05 → 2026-09-01 rendered as a flat vertical line**:
  the bench's `SpreadAngle (360,360)`, drag and fade curve never made it into
  `FireworkController`'s pool, so particles fired straight up. Invisible from below at
  the Overlook; exposed by the proving range's first eye-level sightline and fixed in
  `adaa1fe`. Reaches players on the next place publish.
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

## Raw layer

- ledger: `.superpowers/sdd/2026-08-05-fireworks-core/progress.md`; device floor
  note `docs/superpowers/canyon/fireworks-mobile-floor-2026-08-05.md`
- key commits: `a25f0c7` shell ledger · `743665d` picker · `322d948` cursor ·
  `22bcf2e` shop depth
- bench: `roblox/tools/studio/buildFireworkBench.luau` (lessons in header);
  site tagger `tools/studio/tagLaunchSites.luau`
