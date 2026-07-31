# Friends & Family Baseline — Program Design

**Date:** 2026-07-30
**Status:** Approved direction (program-level). Each numbered item below gets its own
brainstorm → spec → plan cycle when taken up; this document fixes scope and order, not
implementation.

## Goal

Get every system and area of the Roblox experience working at a bare minimum — not for an
official demo, but showable to family and friends who want to see what's being built.

## The bar

- **Audience:** kid-first (that's where the money is). Assume **phones and tablets**,
  hopefully a lot of tablets. Everything touch-first with big, readable targets.
- **Guided:** the owner is present and narrating, so onboarding needs bones, not a
  self-teaching tutorial. But one early viewer is a serious gamer (19) who will judge
  harshly on game-feel: input responsiveness, HUD clarity, finish. Polish where visible
  beats explanation.
- **Roblox only.** The PWA is showable as-is and out of scope. (Parked idea for later: a
  working throw-drum replica rendered on the PWA.)
- **Design intent everywhere.** Standing observation from the canyon work: every place
  examined with clear design intent turns out better. No more "drop it in and move on" —
  each pass runs through a deliberate composition or design step, even at bare-minimum
  scope.
- **Avatar controls are Roblox's problem.** The stock mobile joystick is what it is. Our
  constraint: never require deft avatar control anywhere — wide paths, generous prompts,
  no precision jumps.

## Game-shape context (why the HUD splits in two)

The core Roshambo loop is an **ambient game**: one throw against the World roughly per
minute, rounds skippable without penalty. Between rounds players hang out, socialize,
explore, buy and decorate teahouses, and (once this program lands) launch and watch
fireworks. Some players will be frenetic stats-optimizers managing streak risk/reward;
many will just chill with friends and buy flexy swag. The UI must serve both without
either mode intruding on the other.

## The program, in build order

### 1. Foliage finish — waterline + upcanyon trees (promoted: momentum + paid assets)

The vendor assets (sugi, niwaki, iris, muhly) cost real money and should be doing visual
work in the canyon, even if not final. Current water plants read scraggly; earlier tree
drops read as a mess.

- **Muhly triage + prep**: the untouched 234 MB vendor FBX
  (`foliage/muhly_grass/BC_PM_P013_Muhly_grass_01_FBX.FBX`). It ships real opacity maps,
  so likely card geometry → the petal-patch prep path, not ribboning. Verify
  `ReedClump`/`FernClump` actually exist before trusting the old
  `foliageZoneRecipes.luau` WaterMargin mix.
- **Waterline replant** under a **composition-first rule**: arrangements and hand-siting
  govern composed sites and visible reaches; weighted scatter is demoted to background
  fill only. This settles the flagged governance conflict (hand-composed iris vs.
  50%-weighted scatter recipe claiming the same waterline).
- **Upcanyon tree re-pass**: pull the thoughtlessly-placed trees and replant through the
  `foliageArrangements.luau` site grammar (odd counts, one dominant + attendants,
  ground-draped groups). Green-first palette (~4:1 green over jewel tones); sugi spent as
  hero accents only (A13 bench: no headroom for double-sided alpha foliage in mass
  scatter).
- **Exit bar:** reads intentional at a walk-through. Explicitly **not final** — this item
  is the one most prone to infinite polish, so it gates and we move on.

### 2. Play HUD, minimal + maximal, with onboarding bones folded in

Replace the provisional `roblox/src/client/main.client.luau` UI (raw Instance.new labels
and buttons, pick cluster provisionally shoved top-right) with a designed, touch-first
HUD system.

- **Minimal (hangout default):** a small, good-looking RPS hub — current round state,
  last-few-rounds tape (the ugly history tiles reborn), tap-to-throw, pot/streak shown
  only when one is riding. Everything else hidden.
- **Maximal (opt-in / playing seriously):** expanded panel — personal stats, streak/
  risk-reward info, scrolling ticker for announcements, updates, and alerts.
- **Onboarding:** a one-time first-join sequence of 3–4 dismissable beats (here's the
  drum / tap to throw / here's your pot / bank or ride) riding the same UI system, with a
  has-seen flag persisted server-side. Bones, not a tutorial.
- Size tiers (tablet vs phone layout) may fall out of the design; not a separate
  deliverable.

*Why before everything but foliage: every later item (stats-local view, shop feedback,
fireworks prompts) renders through this surface, and it's what a critical gamer judges in
the first thirty seconds.*

### 3. Fireworks core

The hangout fantasy — chill on your deck watching other people's fireworks — requires
other people to have fireworks. Feature does not exist today (only perf knowledge from
the deleted bench).

- **Scope:** 2–3 good shell types; purchase into owned inventory; launch from your own
  deck; client-side VFX obeying the established perf rules (concurrent-shell cap, no
  per-shell lights, pooled emitters, client-emitted bursts).
- Purchases go through the existing panel/prompt spine until the shop (item 4) exists.
- **Out:** handheld launching, big catalogs, the low-end Android perf floor test.

### 4. Merchant row — shells + one working fireworks shop

Five machiya shopfronts with noren + real kanji signage (花火屋 fireworks, 植木屋
garden/decorations, 提灯屋 lanterns, 茶屋 tea, 面屋 masks) enclosing the karesansui
square's NW flank, built against the reserved `shopCorridor`/`eastCorridor` in
ArenaLayout. Massing references live in `ServerStorage.Sandbox_PARKED.MerchantMassing`.

- Four shops are **closed façades** (art shells).
- The **fireworks shop opens**: interior, browse, buy at the counter — wired to item 3's
  inventory. This proves the physical-store pattern the rest of the row adopts later.
- Machiya is a **new structure archetype** (≠ teahouse) and still needs its own
  brainstorm → spec before build.

### 5. Shoji screens — interactive + swappable

Teahouses come in three sizes but the shoji are static panels. Make them real:

- **Open / half-open / close** per screen; ideally **grab a handle and slide** (fallback:
  prompt-cycled states if grab-drag proves hostile on touch).
- Built as a **swappable variant slot in the loadout from day one**, so better screens
  become an earnable/buyable item later. The slot ships now; the catalog can wait.
- All three prefabs already carry tagged Bay models (S=6, M=10, L=14) and the
  `wallBays`/`applyBays` spine is live — this extends that system, not a new one.

### 6. Statistics — aggregates, the Overlook Statistics room, HUD-local view

Split by kind (decided): **personal** stats live in the maximal HUD; **global/social**
stats get a physical place where geeks collect.

- **Backend:** new aggregation on the existing round/streak persistence (records, streak
  leaders, round history) surfaced via `/api/v1`.
- **The Statistics room**: dug into the hillside beneath/beside the western Overlook at
  (73, 110, 19) — per the canyon-destinations spec ("the strongest idea in the
  programme": walk out to read the leaderboards, get paid in the canyon's best view).
  Needs its own spec (explicitly deferred there).
- **Local access:** global stats also reachable in a few taps from the maximal HUD.

*Ordered last of the big items because it needs backend + the largest new construction,
and the game demos fine before leaderboards exist. If the serious-gamer visit comes
early, promote this item.*

### 7. World finish & hygiene

- Perch teahouse placed at the lantern-stair summit (placement decision, existing
  builders).
- Access-control + portal placeholder art pass (noren perimeter, beacons, portal
  fixture).
- Pre-publish hygiene: clear dev knobs (`DayNightStartT`, `DayNightLockT`), run
  `tools/studio/verifyWorkspaceConvention.luau`, save/publish.
- Mass foliage scatter is largely absorbed into item 1; anything left lands here.

## Explicitly out of scope

PWA work of any kind (incl. the throw-drum replica idea) · low-end Android perf floor ·
full store economy beyond the fireworks shop · guest passes and teahouse floors · bridge
sway · Water Striker nits (the Lantern/Throw/Bell assembly is production-ready as-is) ·
mobile avatar-control remediation (Roblox core).

## Process

Work each item through the standard cycle: brainstorm → spec → plan → subagent-driven or
inline execution → user visual gate. Standing rules apply (recipes doc first, one visual
attempt then stop-and-ask, save/publish after place-only work).

Meta-note: a better system for tracking this work is wanted; the owner has thoughts to
share and that conversation is pending.
