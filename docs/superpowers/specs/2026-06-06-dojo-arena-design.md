# Dojo Arena — Milestone 4 Design

**Date:** 2026-06-06
**Status:** Approved pending final review
**Parent spec:** `2026-06-05-roblox-client-design.md` (§6 arena experience; this document supersedes its arena/effects sketch where they differ — notably pedestals, see §10)

## 1. Goals & KPIs

- **≥10-minute average session** — the Creator Rewards engagement threshold is the design KPI; every feature is judged by "does this make someone stay another round?"
- **R15 avatars pinned** (Game Settings → Avatar Type = R15, never PlayerChoice): eligibility condition for the +42% DevEx rate on US 18+ spend effective 2026-06-08. The grow effect already requires R15 scale NumberValues, so this also de-risks the marquee effect.
- **China-portable theming** — Roblox/Tencent plan to relaunch LuoBu in 2026. The arena must re-skin to a Chinese theme as assets + data, with zero code changes.
- Ships the M3 carry-over: a whiff signal — a personal "TOO LATE" toast + small dust poff visible to the whiffed player (private; to others they read as a spectator that round).

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

- **ACTIVE**: lanterns ambient; picking via M3 UI; on lock the avatar plays a **wind-up bow** (hands in sleeves — the pick itself stays secret until the reveal's consequences make it readable). Ticker: "THE WORLD CHOOSES IN N".
- **Lockout (latch click)**: the hammer's latch click is the arena-wide signal that picks are closed. No pick disclosure (an earlier paddles-up beat was cut: once the world throw lands, visible picks would let everyone read all outcomes before the effects fire, killing the surprise). **Whiffed players** get the private TOO LATE toast (§1).
- **TALLY**: §5 drumroll assemblage.
- **REVEAL + consequences** (staggered 0–600ms across players for crowd ripple):
  - **WIN** — avatar grows ~1.6× via R15 Humanoid scale NumberValues tweened with overshoot bounce (never `ApplyDescription`); gold petal burst (theme-shaped: sakura now, plum later); a pot tile flips up over their head with the new amount; decays back over ~8s (winners walk around big — social flex window)
  - **LOSS** — **The Three Fates** (§6.1): the loser's doom matches the World Throw and *pursues them*
  - **SAFE** — paper umbrella (wagasa) pops open overhead, a leaf bounces off, twirls closed (oil-paper umbrellas are Chinese-origin: ports as-is)
- **Board updates**: LAST 5 flips; ticker flashes the result line.
- **Bank moment** (next ACTIVE): banking plays a **coin-toss into the offering box** by the dais (clink, glow) + ticker shoutout.

### 6.1 The Three Fates (LOSS consequences)

The doom is the thing that beat you, in period-authentic per-theme dress (model refs live in the ArenaTheme manifest):

| World Throw | Fate | ZenDojo (Edo Japan) | JadeCourt (Qing China) |
|---|---|---|---|
| ○ Rock | **The Boulder Rain** — a boulder drops on a shadow tracking the fleeing player; every miss spawns MORE shadows at an accelerating drop rate until the victim is dancing through a stone hailstorm. Dodges earn crowd-visible "DODGED!" board flashes. Catch (contact): squash-flatten-respring; boulders crumble to gravel | Weathered moss-flecked garden stones | Taihu scholar's rocks (the holes whistle as they fall) |
| ─ Paper | **The Paper Storm** — sheets pursue and KEEP JOINING from new directions; the comet-tail behind the sprinting victim grows longer and longer, readable across the arena. Catch (contact/engulfment): wrapped in an unfurling scroll, then burst-flatten-respring | Washi sheets (kozo fiber, cream, deckled edges, abstract sumi strokes — never readable text); emakimono scroll wrap | Xuan paper; handscroll wrap |
| ∧ Scissors | **The Shears** (the creepy one) — half-buried snips quiver UP OUT OF THE GROUND ahead of the flight path and leap at the victim's legs, snapping; more emerge the longer the flight. Catch (contact): a flurry of snips shreds a brief paper aura to confetti; flatten-respring beneath | Giant **nigiri-basami** (one-piece U-spring snips — they clench, not scissor) | **Zhang Xiaoquan-style** ring-handled scissors (the 1781 Qianlong-endorsed form) |

**Chase rules — fate is patient, not punctual.** There is **no guaranteed catch**: contact ends the flight, and skilled players can survive comically long — that survival IS the show. Intensity escalates on a time-based stage curve (more entities, faster spawns, tighter targeting) toward near-impossibility, but **plateaus at a per-victim entity cap** so cost stays bounded while the antics continue. Standing still = caught in ~4s — and never before the doom has visibly manifested (the show must start). Dooms pursue through doors, over bridges, into the koi pond (soggy paper storm slaps — bonus gag).

**Fate-binding — you can't throw until you face your fate.** While a player's fate is active they are **barred from submitting a throw** (pick UI locked with "FACE YOUR FATE"; enforced server-side by a FateRegistry gate on the Roblox game server before `submitPick`). The flight may continue indefinitely across rounds, but every fled round is a round not played — glory costs participation. Two doors back into the game: **get caught**, or the explicit **Accept Fate** action (button → the avatar stops, kneels/bows → the doom takes them at once — fittingly zen). Either way the player is cleansed and may throw from the next ACTIVE. (This supersedes the earlier win-banish and fate-compounding rules: you cannot win or lose while fate-bound, because you cannot play.)

**Caps**: 12 concurrent pursuits per server (overflow losers get the instant-catch squash); per-victim entity plateaus (≈6 active boulder shadows, ≈40 paper sheets in the tail, ≈8 shear ambushers); a global doom-entity budget shared across victims. The retired anvil may someday return as a rare EffectRegistry variant.

**Event architecture**: M3's `RevealResult` fires per-player with only that player's outcome — insufficient for arena-wide theater. M4 adds a **`RevealTheater` broadcast** (FireAllClients) carrying `{worldThrow, distribution, results: {userId → result}, whiffed}` so every client renders all grows/fates/umbrellas locally. Pursuit simulation is client-side with **per-victim authority**: the doomed player's own client simulates their pursuit and detects contact (or executes the Accept Fate sequence), firing a small **`FateResolved` remote with a reason (`caught` | `accepted`)** (victim → server → broadcast) so all clients land the catch at the same moment and the server's FateRegistry lifts the throw bar; other clients render approximations and snap on that event. No server physics; traffic is one tiny event per catch. The per-player `RevealResult` remains for authoritative personal UI. No new REST surface; no new server→Node traffic.

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
| `DoomEscalation` | Pure pursuit math: intensity stage as f(elapsed); spawn schedules per fate type; entity-cap plateaus; homing/ambush position steps; stand-still fast-catch threshold |
| `FateRegistry` | Who is fate-bound: begin/resolve/isBound per userId — the server-side gate that bars throws until the fate resolves |
| `ThemeManifest` | Schema validation of theme data modules (missing key = loud failure at boot, not silent gray prop) |
| `ChoreographyMachine` | Phase-driven state machine consuming the M3 `onRound`/`onReveal` callbacks → ordered effect cues |

Roblox-runtime additions: arena geometry (built in Studio, committed as Rojo-synced model files where practical), client effect players (tweens/particles/sounds), alcove TextChannel manager, paddle/emote controller.

**Animation constraint:** custom Animation assets require uploads to the creator's Roblox account (an M5-style dependency). M4 therefore implements avatar gestures **programmatically** (CFrame/Motor6D tweens for the paddle raise; a catalog/default emote for the wind-up bow) — custom authored animations are an optional later upgrade, not a dependency.

**Performance guardrails (design-level, not afterthoughts):** grow = 4 tweened NumberValues per winner (cheap at any count); pursuit cap 12 (one anchored homing model + one particle trail per doom, client-side, zero replication); shared particle emitters; pooled sounds (clacks ≤6 concurrent); 2D flap sim for all board cells (only the hero tile is physical); reactive water only in the basin; Terrain water elsewhere; staggered consequence cues spread load across frames.

## 9. R15 & avatar settings

- Avatar Type pinned to **R15** in Game Settings (place + published experience in M5). Not PlayerChoice — an R6 avatar would silently break the grow effect and the revenue eligibility.
- Effects must be **layered-clothing-safe**: scale NumberValues and external props only; never modify the HumanoidDescription mid-session.
- Watch item: Roblox has said it will clarify 18+ tier eligibility for custom rigs/no-avatar experiences; we use standard R15 so no exposure expected.

## 10. Deviations from the parent spec

- **Pedestals (parent §6) are deferred**: the jumbotron's HOT STREAK row carries the "current leaders, visible to all" job. Physical podiums with knock-off animations can join a later content pass — the social-drama idea is good, but it's not load-bearing for the 10-minute KPI and M4 is already large.
- **World Record holo (parent §6) is absorbed** into the jumbotron's WORLD REC row (same filtering/async rules).
- Parent §6's "shield shimmer" SAFE effect is replaced by the wagasa umbrella.
- Parent §6's "anvil falls on losers" is replaced by the Three Fates (§6.1) — the doom matches the World Throw and pursues the loser.

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
| SAFE | Wagasa umbrella | Oil-paper umbrella (same form) |
| LOSS fates | Garden boulder / washi storm + emakimono / nigiri-basami | Taihu rock / xuan storm + handscroll / Zhang Xiaoquan shears |
| Bank ritual | Saisen box | Merit box (功德箱) |
| Watermark | Woven in tatami | Etched in paver grain |

## 12. Out of scope (M4) — and M5 notes

JadeCourt assets; merch/cosmetics; pot-escalation effect policy (hook only); physical pedestals; arena-theme monetization; Open Cloud publishing, image-asset uploads, `HttpService:GetSecret` (all M5); PWA shared-theater refresh.

**Recorded for the M5 plan:**
- Create a **Roblox Group** to own the experience and all assets (animations, images, sounds, meshes) — group ownership beats personal-account ownership for team/CI reuse.
- **Animation session**: author the gesture set (wind-up bow, victory stance, flee panic, acceptance bow) via Studio's **video Animation Capture** (perform on webcam, clean up keyframes), publish to the group, and flip the ThemeManifest entries from programmatic gestures to authored asset ids.

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
| Paddles-up beat | Cut | Post-reveal, visible picks would spoil all outcomes before effects fire; whiff signal became a private toast |
| LOSS effect | Three Fates: throw-matched escalating pursuits, NO guaranteed catch — contact or acceptance ends it | "Destroyed by what beat you" made flesh; skilled flights are spectator theater; dwell time |
| Fate-binding | No throwing while fate-bound; Accept Fate action is the deliberate door back | Fleeing must cost something; glory vs. participation trade-off (supersedes win-banish/compounding) |
| Fate authenticity | 18th-c. East Asian designs per theme (nigiri-basami / Zhang Xiaoquan; washi-emakimono / xuan-handscroll; garden stone / taihu rock) | User requirement; China-market sensitivity; verified historical forms |
