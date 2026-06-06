# Dojo Arena — Milestone 4 Design

**Date:** 2026-06-06
**Status:** Approved pending final review
**Parent spec:** `2026-06-05-roblox-client-design.md` (§6 arena experience; this document supersedes its arena/effects sketch where they differ — notably pedestals, see §10)

## 1. Goals & KPIs

- **≥10-minute average session** — the Creator Rewards engagement threshold is the design KPI; every feature is judged by "does this make someone stay another round?"
- **R15 avatars pinned** (Game Settings → Avatar Type = R15, never PlayerChoice): eligibility condition for the +42% DevEx rate on US 18+ spend effective 2026-06-08. The grow effect already requires R15 scale NumberValues, so this also de-risks the marquee effect.
- **China-portable theming** — Roblox/Tencent plan to relaunch LuoBu in 2026. The arena must re-skin to a Chinese theme as assets + data, with zero code changes.
- Ships the M3 carry-over: a visible whiff signal ("LATE" paddle, §6).

## 2. Three-layer architecture

| Layer | Lives in | Changes when |
|---|---|---|
| **Structure** | Luau code + place geometry slots | Never (per theme) — terraced bowl, alcoves, floor, dais, jumbotron, Water Hammer machine, choreography state machine. Code names are culture-neutral: `drumroll`, `gate`, `alcove`, `waterHammer`. |
| **ArenaTheme manifest** | Data module (`themes/ZenDojo.luau`) | Per theme — materials, colors, prop model refs, sound asset ids, particle params, display label strings |
| **EffectRegistry** | Data module | Per content drop — each slot (REVEAL, WIN, SAFE, LOSS, BANK) maps to a pool of effect variants; a selection policy picks per round |

M4 ships exactly one theme (`ZenDojo`) and 1–2 variants per effect slot, but every visual/audio touchpoint goes through these seams. `JadeCourt` (Chinese skin) is a planned future data file — the element mapping is recorded in §11 so asset work can proceed without design re-litigation.

**Selection policy:** M4 ships `random` (uniform over the slot's pool). The policy interface takes `(slot, context)` where context includes the player's pot size — `potTierEscalation` (bigger pots get bigger effects) is an intended future policy; only the hook ships now.

## 3. Arena layout (structure)

A terraced garden hillside descending to a central play floor (the hybrid of the three explored layouts):

- **Central floor**: circular tatami area ringed by a raised engawa walkway. The **gong dais** is at center, standing over the **reactive basin** (§5).
- **Terraces**: 2–3 hangout tiers rising around the floor (cushions, tea tables, lanterns); natural amphitheater sightlines down to the floor.
- **Teahouse alcoves**: small rooms dotted along the terraces. Each has: a porch with sightline to floor + jumbotron; **native proximity voice** (automatic); a **private `TextChatService` channel** scoped to occupants (join/leave on enter/exit region). Doorways hung with plain noren (no branding).
- **Periphery**: torii entrance gate, koi pond with bridge, **terrace streams** that visibly drain downhill into the basin (these power the Water Hammer narratively and provide the ambient soundscape).
- **Scale**: feels alive at 15 players, uncrowded at 100. Ship with `MaxPlayers = 60`; Roblox allows 200 standard / 700 beta if data ever justifies it. Per-server count is social density only — rounds are global across all servers + the PWA.

## 4. The split-flap system

### 4.1 Jumbotron (two-sided, floating above the floor)

Ivory **mahjong-tile** split-flap board in a dark lacquered frame with gold trim, hung sports-arena style, identical content on both faces. Header: `世界 · THE WORLD` (same hanzi in Japanese and Chinese — never the wordmark).

Rows (labels are engraved frame plaques; ALL data content is tiles, including names letter-by-letter):

1. `LAST 5` — the tape; throw glyphs, newest tile glowing
2. `WORLD REC` — cross-platform record + holder name + country tile. **This row absorbs the parent spec's "World Record holo"** — same narrative job, same rules: names TextService-filtered, updates asynchronous off `/leaderboards` polling, never in the reveal critical path, fallback epithet on filter failure/redaction
3. `HOT STREAK` — best live streak + name (glowing tiles) + origin flourish when it's this server
4. `PLAYING NOW` — global live player count + round number
5. **Two transient ticker lines** (amber-tinted tiles): round countdowns ("THE WORLD CHOOSES IN 8"), social hype ("2,341 RIDING 27+ POTS"), reveal flashes ("WORLD THREW ∧ — 31% SAFE"), bank shoutouts ("BLOXSAN BANKED 243")

### 4.2 Flap mechanics

- **2D SurfaceGui simulation**: every cell is split at the midline (visible seam); change = top-flap squash (scaleY 1→0) → character swap → bottom unsquash — cycling through the character drum at ~12 steps/sec until landing on target
- Cascade: columns staggered ~60ms left-to-right
- Audio: clack sample pool, max ~6 concurrent, synced to flap steps
- During TALLY the ticker lines cascade-flip continuously — **the board is part of the drumroll**

### 4.3 Hero tile

One giant **true-3D physical split-flap tile** mounted above the gong: two hinged half-tile parts, genuinely rotating. Idle face: the winking-face glyph arrangement from the brand icon. During TALLY it flips through its drum (○ ─ ∧ …) with accelerating clacks; at REVEAL it lands on the World Throw with a final heavy clack. The only true-3D flap in the arena (perf budget spent where players look).

### 4.4 Glyph canon

- Rock = **Ring ○** (single circle, outline style — NEVER a double-ring ◎), red engraving
- Paper = **Macron ─**, blue engraving
- Scissors = **Caret ∧ (up-pointing)**, green engraving — matches the PWA `Symbols.tsx` vectors and the wordmark's circumflex
- The icon's down-pointing ∨ is the **mascot face's smile only** — it never represents scissors in gameplay surfaces

## 5. The Water Hammer (reveal machine & diegetic timer)

Terrace streams → waterwheel → ratchet chain → hammer arm on a pivot beside the gong.

| Phase | Machine behavior |
|---|---|
| ACTIVE (20s) | Wheel turns; chain cranks the hammer arm upward. **Arm height = f(RoundClock time remaining)** — synced to `phaseEndsAt` via the existing clock offset, not animation wall-time. The hammer is the arena-wide countdown. |
| T₀−2s (lockout) | Hammer ratchets past a visible **latch** with an audible arena-wide *click* — the diegetic lockout signal. Paddles go up (§6). |
| TALLY (2s) | Hammer trembles at apex; taiko roll; hero tile spins; board ticker cascades. |
| REVEAL | Latch releases → hammer swings the arc → **GONG** (single massive strike, screen-space shockwave ring, lantern flare) → **basin erupts** → hero tile lands on the World Throw. |
| Reset | Hammer returns to bottom; wheel resumes; water ambience carries the calm. |

**Reactive basin**: the pond under the dais is a **skinned-mesh water plane** (bone-deformed) rippled on command — impact rings radiate from the strike point + particle splash crown. Decorative water elsewhere (koi pond, streams) is plain Terrain water (cheap, auto-degrades on weak devices). Rule: **ambient water free, reactive water choreographed** — reactive surfaces only at contained pond scale.

The Water Hammer is **REVEAL variant #1** in the EffectRegistry. The machine is historically authentic in both target cultures (Japanese karausu / Chinese duì 碓 water trip-hammers), so it survives re-theming with dressing changes only.

## 6. Round choreography (player-facing beats)

- **ACTIVE**: lanterns ambient; picking via M3 UI; on lock the avatar plays a **wind-up bow** (hands in sleeves — pick stays secret). Ticker: "THE WORLD CHOOSES IN N".
- **Lockout (latch click)**: every participant raises a **wooden paddle showing their glyph** — picks are server-locked, so going public is safe and creates the crowd-read moment ("too many rocks this round!"). **Whiffed players** (final flush missed the cutoff; M3 already suppresses their local results) raise a **blank grey paddle with a "LATE" stamp** — the M3 carry-over made visible.
- **TALLY**: §5 drumroll assemblage.
- **REVEAL + consequences** (staggered 0–600ms across players for crowd ripple):
  - **WIN** — avatar grows ~1.6× via R15 Humanoid scale NumberValues tweened with overshoot bounce (never `ApplyDescription`); gold petal burst (theme-shaped: sakura now, plum later); a pot tile flips up over their head with the new amount; decays back over ~8s (winners walk around big — social flex window)
  - **LOSS** — classic iron anvil drops (deliberately culture-absurd against the zen; max **8 physical anvils** per reveal, overflow losers get dust-poof-and-flatten); paddle splinters
  - **SAFE** — paper umbrella (wagasa) pops open overhead, a leaf bounces off, twirls closed (oil-paper umbrellas are Chinese-origin: ports as-is)
- **Board updates**: LAST 5 flips; ticker flashes the result line.
- **Bank moment** (next ACTIVE): banking plays a **coin-toss into the offering box** by the dais (clink, glow) + ticker shoutout.

All effects are **client-side, driven by the existing M3 events** (`RoundUpdate`, `RevealResult`, `ProfileUpdate`) — zero new server traffic and no new REST surface. Particles via shared emitters, not per-player instances.

## 7. Brand integration (final set)

| Placement | Treatment |
|---|---|
| Gong face | The winking-face glyph arrangement (ring + macron eyes, ∨ smile) embossed — the gong is the mascot |
| Tatami watermark | `rôshåmbō` wordmark woven into the floor at *very subtle* intensity — discoverable in aerial screenshots/videos, not signage |
| Hero tile idle face | The winking-face arrangement |
| Jumbotron header | `世界 · THE WORLD` (deliberately NOT the wordmark — the board labels the opponent) |
| Noren / curtains | Plain fabric, no branding |

Logo source: `brand/rosh_logo.png` (committed). Roblox image-asset upload + moderation happens in M5; M4 builds the gong/tatami/hero-tile marks as geometry/textures, not decals of the PNG.

## 8. Implementation & testing approach

Same dual-runtime discipline as M2/M3 — Roblox-runtime files stay thin; schedulable logic is pure and Lune-tested:

| Pure module (Lune-tested) | Responsibility |
|---|---|
| `FlapScheduler` | Given (current board state, target state) → ordered flip steps per cell with timing offsets; cascade and drum-stepping logic |
| `HammerCurve` | Arm height/angle as f(timeLeft, phase); latch threshold; release trigger |
| `EffectSelector` | Registry lookup + selection policy (`random` now; policy interface takes pot context) |
| `ThemeManifest` | Schema validation of theme data modules (missing key = loud failure at boot, not silent gray prop) |
| `ChoreographyMachine` | Phase-driven state machine consuming the M3 `onRound`/`onReveal` callbacks → ordered effect cues |

Roblox-runtime additions: arena geometry (built in Studio, committed as Rojo-synced model files where practical), client effect players (tweens/particles/sounds), alcove TextChannel manager, paddle/emote controller.

**Animation constraint:** custom Animation assets require uploads to the creator's Roblox account (an M5-style dependency). M4 therefore implements avatar gestures **programmatically** (CFrame/Motor6D tweens for the paddle raise; a catalog/default emote for the wind-up bow) — custom authored animations are an optional later upgrade, not a dependency.

**Performance guardrails (design-level, not afterthoughts):** grow = 4 tweened NumberValues per winner (cheap at any count); anvil cap 8; shared particle emitters; pooled sounds (clacks ≤6 concurrent); 2D flap sim for all board cells (only the hero tile is physical); reactive water only in the basin; Terrain water elsewhere; staggered consequence cues spread load across frames.

## 9. R15 & avatar settings

- Avatar Type pinned to **R15** in Game Settings (place + published experience in M5). Not PlayerChoice — an R6 avatar would silently break the grow effect and the revenue eligibility.
- Effects must be **layered-clothing-safe**: scale NumberValues and external props only; never modify the HumanoidDescription mid-session.
- Watch item: Roblox has said it will clarify 18+ tier eligibility for custom rigs/no-avatar experiences; we use standard R15 so no exposure expected.

## 10. Deviations from the parent spec

- **Pedestals (parent §6) are deferred**: the jumbotron's HOT STREAK row carries the "current leaders, visible to all" job. Physical podiums with knock-off animations can join a later content pass — the social-drama idea is good, but it's not load-bearing for the 10-minute KPI and M4 is already large.
- **World Record holo (parent §6) is absorbed** into the jumbotron's WORLD REC row (same filtering/async rules).
- Parent §6's "shield shimmer" SAFE effect is replaced by the wagasa umbrella.

## 11. Future theme mapping (recorded for asset planning — NOT built in M4)

| Structure element | ZenDojo (ships) | JadeCourt (future) |
|---|---|---|
| Play floor | Tatami circle, moss green | Stone pavers, jade inlay ring |
| Gong + dais | Weathered bronze | Same (luo 锣 is Chinese); redder bronze |
| Hero tile / jumbotron | Ivory + dark lacquer | Same tiles; carved rosewood frame |
| Terraces | Garden, stone lanterns | Pavilion steps, red pillar lanterns |
| Alcoves | Teahouses, shoji, noren | Pavilions, lattice, ménlián |
| Gate | Torii | Páifāng |
| Drumroll | Taiko | Dàgǔ + guzheng sting |
| WIN petals | Sakura-shaped | Plum-blossom-shaped |
| SAFE / LOSS | Umbrella / anvil | Same / same |
| Bank ritual | Saisen box | Merit box (功德箱) |
| Watermark | Woven in tatami | Etched in paver grain |

## 12. Out of scope (M4)

JadeCourt assets; merch/cosmetics; pot-escalation effect policy (hook only); physical pedestals; arena-theme monetization; Open Cloud publishing, image-asset uploads, `HttpService:GetSecret` (all M5); PWA shared-theater refresh.

## 13. Decisions log

| Decision | Choice | Why |
|---|---|---|
| Aesthetic | Zen Dojo, hangout-first | User selection; 10-min dwell KPI favors lounge energy |
| Layout | Hybrid: terraced bowl + teahouses + engawa/tatami floor + floating two-sided board | Scales to large player counts; alcove privacy with sightlines |
| Board material | Ivory mahjong tiles | Crisp at distance; iconic clack; Chinese-origin (theme-portable) |
| Flap tech | 2D SurfaceGui sim everywhere + one true-3D hero tile | Perf at 200+ cells; spend 3D budget where players look |
| Reveal machine | Water Hammer (wheel-cranked, latch at lockout, gong + reactive basin) | User's concept; diegetic timer; authentic in both target cultures |
| Theming | ArenaTheme manifest + EffectRegistry data layers | China market (LuoBu 2026); seasonal skins; culture-neutral code |
| Glyph canon | ∧ up-caret in gameplay; ∨ only on the mascot face; single-circle ring | Matches PWA vectors and wordmark diacritics; user correction on ◎ |
| Branding | Gong face + subtle tatami watermark + hero tile idle; no wordmark signage | User preference: discoverable, not plastered |
| Pedestals | Deferred in favor of HOT STREAK row | Scope control; board does the job |
