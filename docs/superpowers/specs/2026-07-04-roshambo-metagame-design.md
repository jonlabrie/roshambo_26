# Roshambo Meta-Game — Design (point sinks, personal teahouses, familiars)

**Status:** design approved in brainstorm (2026-07-04); pre-planning. This is a *game-design* spec — systems, economy, and scope — not an implementation plan.
**Branch:** `m4b-zendojo-art-pass` (spec only; implementation will span server + Roblox client + environment build sub-projects)
**Relation to prior work:** builds on the canyon village (paths → teahouses → bridge → interiors), the fireworks plan, and milestone 4a's effect/theme registries. The original `requirements.md` already anticipated a store ("banked points are traded for skins, new characters, and visual/audio upgrades"); this spec defines what the points economy actually buys and why players stay.

## Problem

The core loop (global ~60s rounds vs. the World Throw) and the acceleration layer (3^n staking, Bank vs. Stake) exist. What's missing:

1. **Point sinks** — banked points accumulate with nothing to spend them on. The 3^n progression makes wealth log-distributed *by design*: most players bank 3–27 per session; a 6-streak banks 729. Sinks must serve both populations.
2. **Stickiness** — Roblox's current platform incentives favor experiences that are a player's first landing place and hold them 10+ minutes. Rounds are short and playable from anywhere in the valley, so the environment can add session minutes without competing with the core loop — if there are reasons to be out in it.

## Economy principles

- **Points-only for v1.** Everything in the valley is earned by playing — no Robux purchases yet. Cleanest to tune, and it makes every visible possession proof of play. Future monetization shape (explicitly chosen, explicitly deferred): **dual currency with separate catalogs** — Robux buys a cosmetic-only catalog that never overlaps point items. **Robux-buys-points is ruled out permanently** (a purchased pagoda proves nothing; whales trivialize every sink).
- **Split economies per platform (policy-driven).** The Roblox valley economy is **self-contained**: points earned in Roblox are spent in Roblox. The PWA is a separate product (targeted more at adults) with its own wallet and inventory that evolve independently. Shared *plumbing* (one Node server, one Mongo, one identity record via `resolveUser`) is fine and standard; a shared *wallet* is not, because it survives only while both sides are free — the moment real money touches either side, a shared economy violates Roblox policy from one direction or the other. See "Platform policy constraints" below.
- **Two-tier sink structure.** Cheap consumables (single digits to tens of points: fireworks shells, familiar feed, lanterns) that the median player burns every session, plus large durables (hundreds to thousands: structural teahouse tiers, premium pad unlocks, rare koi) that drain streak-lord wealth.
- **The best cosmetic real estate is the reveal.** Every player watches the RevealTheater every round; purchasable throw/reveal skins get more eyeballs than any avatar item. Milestone 4a's `EffectRegistry`/`EffectSelector`/`ThemeManifest` is already the plumbing — purchasable effects are registry entries gated by inventory.
- **Server-authoritative spending.** Points live in MongoDB in a **Roblox-scoped wallet**. Every spend is a server-side transaction: Roblox client → game server → `/api/v1` spend/inventory endpoints (extending the existing `X-API-Key` surface), mirroring how the PWA's `/store` routes work for the PWA's own wallet. The Roblox client never computes balances.

## Platform policy constraints (researched 2026-07-04)

The rules that force the split-economy decision (Roblox ToU, Commerce Standards, Promo Offers for Virtual Rewards, Creator Third Party App Policy):

- Virtual content may only be sold/exchanged for **Robux**; in-experience items must have **no real-world monetary value**.
- Experiences may not **direct users off-platform to purchase** anything (actively enforced with takedowns).
- The one sanctioned bridge: an off-platform action may grant an in-experience reward **only if** the reward is usable solely in that experience, has no Robux/real-money value, and redemption terms are public ("Promo Offers for Virtual Rewards").
- Third-party apps may not **profile/track Roblox users across platforms** — constrains account-linking design, not just commerce.
- Precedent check found **no shared cross-boundary economy anywhere** on the platform: brand experiences (Nikeland vs. Nike apps) keep fully separate economies; companion apps are read-only; Roblox→Steam ports ship with separate progression. Hard separation is the ecosystem norm.
- Explicitly fine: external backends per se. `HttpService`/Open Cloud calls to our own server for game state are standard and unrestricted — storage location is not "off-platform migration."

## Personal teahouses

**A teahouse is data, not geography.** Each player's teahouse is a saved loadout — structural tier + placed catalog items + garden choices — persisted in our Mongo via `/api/v1` (not Roblox DataStores, so any game server can load it), scoped as **Roblox-platform data** under the shared identity record. On joining a server the player claims a **pad** and their teahouse materializes onto it for the session; the pad frees when they leave. With pad count ≈ server capacity, everyone present has their teahouse standing — scarcity evaporates rather than being managed.

- **Customization = catalog + structural tiers.** A curated ZenDojo-kit furniture/decor catalog placed freely within the pad, plus discrete purchasable structure upgrades as the aspirational ladder. **No free-form building** (serialization weight, moderation exposure, aesthetic clash). The structural-tier catalog is **site-class-aware** (below): same price ladder, different luxury vocabulary per pad class.
- **Pad classes.** Two classes with class-specific structural vocabularies:
  - **Valley-floor pads** (the new valleys) get the *ground* vocabulary: larger floorplans, walled gardens, courtyards, excavated ponds. The new valleys are designed **pad-first** — footprints, garden aprons, and pond basins sized before any dressing goes in — so this class carries the roomy-garden fantasy natively.
  - **Cliff-perch pads** (the original ~18) get the *air* vocabulary, kake-zukuri style (Kiyomizu-dera stage construction): cantilevered moon-viewing decks, hanging lantern gardens on extended stages, deck-mounted pond basins, second engawa rings on longer stilts. Expansion is **built structure, not terrain** — the locked teahouse form is already stilted and raycast-down-the-cliff, so premium growth needs air and anchorage, not ground. The premium story: cliff houses trade the walled garden for the view, and hang their gardens in the air.
  - Buildings are builder-stamped and regenerable (per the teahouse builder spec); terrain is the only non-regenerable asset. **No global valley rescale, ever** — any cliff-site footprint growth is per-site, data-driven, and local.
- **Hard per-pad furniture cap** (~40–80 placed items) so 50+ furnished teahouses hold per-server perf.
- **Claiming is walk-up.** Pads have a gate post; touch a vacant one and the teahouse builds in with a flourish. The server remembers the player's usual pad and may offer "claim my usual spot?" at spawn. Claiming-as-ritual shows off the valleys and opens the session.
- **Pad tiers, one-time unlocks.** Pads are tiered by location prestige (the original ~18 cliff perches are the top tier; new valleys hold standard tiers). Spending banked points permanently unlocks *eligibility* for a tier — the economy's big-denomination sink. No rent, no leases, no eviction.

## Valley expansion

Two new residential valleys radiating from the existing clearing, bringing total pads to **50+**.

- **Hub-and-spoke:** all paths converge on the clearing (shrine, bell engine, festivals). Canyon walls give natural occlusion between valleys; `StreamingEnabled` handles the rest. From the clearing you see valley mouths, not depths.
- **Each valley has a distinct character** (e.g., bamboo / mist / waterfall) and anchors a pad tier; valley identity also drives familiar species rosters (below).
- **Side valleys are compact, recipe-built, and pad-first** — residential streets, not a second grand descent. Pad footprints (including top-tier garden/pond envelopes) are laid out *before* terrain dressing, so valley-floor pads never face the retrofit problem. They lean on the established builders and recipes (ishidan steps, cobble paths, railings, teahouse kit) that exist precisely to make this cheap. The original canyon remains the premium, dramatic tier.

## Familiars

Flying companions — birds, butterflies, dragonflies, fireflies; a crane as the top prestige tier. The *mobile* status display complementing the teahouse's *static* one, and the system that pulls players out to walk the space.

- **Acquired by befriending in the world.** The store sells feed/offerings (the sink). Species appear at specific places and times — kingfishers along the creek, fireflies at lantern-dusk, the crane at the viewing platform in morning mist. Rarity = encounter difficulty, not just price. Acquisition *is* the walk; per-valley rosters reinforce valley identity. No gacha (see Deferred).
- **Owned collection unbounded; displayed flight capped at ~5–7.** The cap is perf protection *and* curation gameplay (choosing a flight loadout).
- **Rendering is client-side and Humanoid-free:** CFrame-lerped flock points around each player; aggressive LOD — distant players' swarms collapse toward billboards/particles (butterflies and fireflies are already particle-shaped).
- **Tied to the core loop:** familiars react to the owner's reveal (rise and circle on WIN, perch on SAFE, scatter-regroup on LOSS). A familiar flying with you when you bank a milestone pot gains visible plumage/glow — creatures carry your history.

## V1 spectacle sinks

1. **Fireworks** — offered at the peak moment ("You banked 243 — launch a three-shell salute?") plus store-bought stock. Uses the existing fireworks plan (client-side VFX, concurrent-shell cap, no per-shell lights, pooling; teahouses + high bridge as viewing spots). Drone swarms reserved as a later prestige tier.
2. **Floating lanterns** — buy a named lantern released into the watercourse at a dusk moment, drifting the pool chain. Names pass through Roblox text filtering.
3. **Koi** — persistent named koi in the clearing pool, rarity tiers for larger spends. Needs pooled-render plumbing: per server, render the koi of players present (plus a sampled backfill) since owners will outnumber sensible fish slots.

## New shared dependency: the dusk cycle

A day/night or scheduled-dusk cycle is now load-bearing for **three** systems — lantern release, fireflies, and dawn/dusk-only familiar species — which justifies building it. Design choice (real clock vs. accelerated cycle vs. scheduled "dusk events" every N rounds) is deferred to planning; note that a scheduled dusk event doubles as an appointment mechanic ("stay until the lanterns go out").

## Retention story (vs. the 10-minute target)

Rounds are playable from anywhere, so every meta-system *adds* minutes without competing with the core loop: the claim-walk opens the session; decorating fills between-round gaps; befriending walks players to the valley edges at specific times; dusk and fireworks are appointment spectacles; and the swarm/teahouse flexes give veterans a reason to be visible in the clearing.

## Explicitly deferred

- **Houses/factions** — a social layer (clubs, pooled upgrades, house championships) that can sit on top of personal teahouses later; scoped out of v1.
- **Bell ring as a purchasable flex** — the water-bell engine stays a sacred ambient centerpiece, not a player-spammable horn.
- **Fortune eggs / gacha acquisition** — paid randomness invites gambling optics and odds-disclosure obligations; ruled out at least for v1.
- **Robux catalogs** (dual-currency structure reserved), **drone swarms**, **ema plaques / omikuji**, **statue-of-the-day**, **gifting**.
- **PWA→Roblox promo bridge** — at most a one-way "play the PWA, unlock a valley cosmetic" promo, and only under the Promo Offers conditions (reward usable only in the experience, no monetary value, public terms). Never the reverse; never anything money-touched.

## Open questions for planning

- Pricing pass: tier unlock costs, catalog price bands, feed costs — tuned against real banked-pot distributions from the live PWA.
- Pad counts per tier and per valley; behavior when a tier is full in a server.
- Teahouse loadout schema + wallet/inventory namespacing: extend the Mongo user model with per-platform wallets (`roblox` vs `pwa`) under the single `resolveUser` identity — decide whether existing PWA lifetime points seed the Roblox wallet at launch or the valley starts everyone fresh.
- Account-linking UX between PWA and Roblox accounts, designed within the Third Party App Policy's no-cross-platform-profiling constraint.
- `/api/v1` additions: spend, inventory, teahouse loadout read/write, familiar collection state.
- Dusk cycle mechanism (see above).
- Koi pooled-render sampling rules.
- Furniture cap number — validate 40–80 against real part counts from the teahouse kit.
- **Cliff-site expansion-envelope audit**: a Lune/Studio tool that occupancy-sweeps each perch site's surrounding volume (outward, along-wall, up — same technique as the tunnel-bore verification) and emits a per-site envelope table grading which sites support which structural tiers. Replaces guessing with data; any resulting terrain edits are per-site and follow the standing registration rules.
