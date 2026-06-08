# ZenDojo Art Pass — Milestone 4b Design

**Parent spec:** `2026-06-06-dojo-arena-design.md` (Milestone 4). M4a built the arena *machinery* on placeholder geometry; 4b makes the arena *real*. This spec records where 4b amends the parent (§2, §8) — the parent stands everywhere not amended here.

## 1. Goal

Replace every placeholder in the live arena with real ZenDojo art so the experience feels like the parent spec reads, in service of the same 10-minute dwell KPI. No new gameplay mechanics: the M4a machinery (FlapScheduler, HammerCurve, DoomEscalation, ChoreographyMachine, FateRegistry, EffectRegistry, the four controllers, the remotes) keeps running underneath unchanged. 4b edits manifest data and adds thin presentation, never machinery logic.

## 2. Amendments to the parent spec

| Parent | Amendment | Why |
|---|---|---|
| §3 central floor: tatami circle + engawa ring + gong dais | **Replaced** by a karesansui raked-gravel apron around the basin; the Striker monument is the sole centerpiece | Floor and monument competed to be the centerpiece; less is more (user direction) |
| §5 water route: terrace streams drain downhill into the basin | Streams gather in a **terrace collecting pool**, then a **kakehi flume** (raised timber/bamboo aqueduct on posts) carries water *over* the unbroken gravel and drops it onto an **overshot waterwheel** | Solves the water-across-dry-garden problem; the whole power train (pool → flume → fall → wheel → drawn log) becomes one legible silhouette; overshot reads the most mechanical torque |
| §10 pedestals deferred (jumbotron HOT STREAK row carries the job) | **Un-deferred, in statue form**: three champion statue promontories + an all-time stele (§4 below) | With the tatami floor gone there is no default "stage"; a hangout arena needs inhabitants with status (user direction) |
| §7 tatami watermark | **Deferred** out of 4b (no home without tatami). Brand presence in 4b = bell-boss mascot glyphs + drum idle face | User choice over gravel-rake or paver alternatives |
| §4 split-flap jumbotron (giant two-sided floating board + hero tile + ticker rows) | **Replaced by a three-channel display system** (§4b below): a **Throw Drum** atop the pavilion (replaces the hero tile, shows the World Throw), **3 two-sided kōsatsu** boards at the pedestal bases (round #/players/last-5 tape), and a **minimal screen-space HUD** (round status + scrolling ticker for all prose). The giant floating jumbotron is removed entirely. | A jumbo-stadium slab floating over a zen garden broke the aesthetic, and split-flaps are great for slow tabular state but terrible for streaming prose (announcements, badge hints). Split the info by medium (user direction, 2026-06-08 gate) |

## 3. Arena layout (final)

- **Center**: reactive basin; bonshō bell + shu-moku log in a timber shōrō pavilion standing over the water; waterwheel + ratchet + draw chain at the pavilion's side.
- **Apron**: karesansui raked gravel ringing the basin, rake rings echoing the bell's ripples. Unbroken — nothing crosses it at grade. Walkable.
- **Bowl**: three terrace tiers (cushions, tea tables, lanterns) with amphitheater sightlines to the bell + throw drum.
- **Flume line**: mid-terrace collecting pool → raised kakehi flume over the apron → overshot wheel drop.
- **Promontories**: three stone platforms jutting inward from the second tier (one top-center, two flanking) — the champion seats.
- **Periphery**: torii gate at the south entrance, sandō stone path from gate to apron edge, all-time stele beside the gate, koi pond, terrace streams, foliage.
- **Teahouse alcoves**: shells, porches with sightlines, noren (plain), dressed interiors. (Private TextChannels are deferred — see §9.)
- **Displays** (§4b): throw drum atop the pavilion; three kōsatsu boards at the pedestal bases; minimal screen-space HUD. No floating jumbotron.

## 4. Champions (the one new code slice)

Three living champions get statues; history gets stone.

| Seat | Holder | Data source |
|---|---|---|
| **The Record** | All-time best pot, cross-platform | Same leaderboard payload that feeds the WORLD REC row (existing polling — no new REST surface) |
| **The Streak** | Current longest live streak, Roshambo-wide | Same payload as HOT STREAK row |
| **The Local Hero** | This server's current points leader | Computed server-side from `PlayerProfiles` on each settlement |

- **`ChampionSeats`** (new pure module, Lune-tested): `(leaderboardPayload, serverRoster) → {record, streak, localHero}` seat assignments. One player may hold multiple seats simultaneously; duplicate statues are allowed (honest and simpler than cascade rules).
- **Statue rigs**: three pre-placed anchored R15 mannequins on the promontories. On seat change the server fetches the holder's `HumanoidDescription` by userId and applies it server-side (replicates to all clients); static dignified pose via Motor6D offsets. Name plaque per pedestal in tile lettering (TextService-filtered, same rules as the WORLD REC row).
- **PWA-origin holders** (no Roblox identity): a stone jizō effigy + plaque instead of an avatar statue — the mysterious off-world champion.
- **Presence beacon**: soft glow + petal drift on a promontory when its holder is physically in this server (the Local Hero's flex spot).
- **Stele**: stone slab by the gate; all-time top-10 engraved via SurfaceGui from the same leaderboard payload.
- Dethronement theater (statue-swap beat) is future polish, not 4b.

## 4b. Display system (2026-06-08 gate — replaces parent §4)

The giant floating split-flap jumbotron is **removed**. Information is split by its nature across three channels:

**1. The Throw Drum** (replaces the parent's "hero tile") — the World Throw reveal, arena-wide.
- A **hexagonal timber drum on a horizontal axis** (E–W) atop the shōrō pavilion, raised to clear the top-tier sightline (~6 studs above the ridge). Size ~10 studs long × ~6 diameter (a face is a ~3-stud gold-inlaid symbol). Six flat faces carved/inlaid **R · P · S · R · P · S**, so opposite faces match.
- A **miya-style timber housing** with a single **front window** (toward the entrance/south) and a **back window** (toward the north promontory). Because the faces are paired at 180°, both windows always show the same symbol; the housing hides the other four faces.
- **Detented motion** (escapement/Geneva-driven off the waterwheel's continuous spin → step-and-dwell): it **always dwells on a full face, never an edge.**
- **Choreography**: ACTIVE — holds the **prior round's** World Throw as a standing reminder (Round 1: an idle mascot face). Lockout — still showing the prior throw (the reference you lock your pick against); shared latch click. TALLY — escapement releases fast, rapid click-through drumroll, full faces flashing. REVEAL — final click lands hard on **this round's** World Throw and locks, **synced to the bell strike** (symbol + shockwave + ripple together); then holds, becoming next round's reminder.
- The client already receives each round's `worldThrow` (RevealTheater) and phase (RoundUpdate), so "remember the last one" + "land on the new one at the strike cue" is the whole controller.

**2. Kōsatsu boards** (×3) — the running tabular state, glanceable in-world.
- Human-scale split-flap notice boards (~8 × 4 ft) on timber posts, one at the **base of each champion pedestal** (N/W/E). **Single-faced**, oriented **inward** toward the bell/apron (readable while spectating); three around the ring give coverage from any arc. (Two faces dropped 2026-06-08 — redundant up close with three boards.)
- Each shows the same readout: **ROUND #, players-now, LAST-5 tape**. "Who leads" is the statue's own name plaque, so the boards don't repeat it. These reuse the existing `FlapScheduler` + the (refactored) board renderer.

**3. Screen-space HUD** — all fast/prose text, styled as the environment.
- **Minimal, bottom-anchored.** The top of the screen stays clear for the bell/drum/sky (the legacy top-center status panel moves to the bottom). Washi-translucent dark panels, thin gold hairline, ink-cream text.
- **Status line** (phase + countdown + your PTS/POT/STREAK) above the R/P/S pick buttons; a slim **ticker strip** along the very bottom edge for streaming prose — round prompts, announcements ("Admin event Tue 10:00 GMT"), badge hints ("Win 3 with ○ to earn HAMMER"), hype lines, the TOO-LATE toast. The ticker is the home for everything a flap board reads badly.
- May fade toward invisible between rounds for a cleaner idle.

**Glyph canon** (parent §4.4) is unchanged: Rock = ○, Paper = ─, Scissors = ∧ (up-caret); ∨ is the mascot smile only.

## 5. Art direction

**Painterly stylized.** Stylized forms with soft material depth: Roblox built-in materials used selectively (wood grain on the flume, slate on stone), warm gradient lighting, subtle AO — warmth without authored texture assets. Palette family: moss · ivory · vermilion-brown · sumi ink · gold. Full PBR was rejected: `SurfaceAppearance` texture uploads are an M5 pipeline dependency (ID verification) and punish low-end mobile — the LuoBu-market phone owns the perf budget.

## 6. Asset production (hybrid, leaning MCP)

The Roblox Studio MCP (installed and verified 2026-06-06) drives most production; Creator Store assets only for vetted commodity dressing; hand-work where taste beats scripting.

| Asset | Method |
|---|---|
| Terrain bowl, streams, pond | Scripted Terrain API blockout (MCP) → user hand-polish pass |
| Bonshō bell, nigiri-basami, boulders | MCP `generate_mesh` |
| Shōrō pavilion, flume, waterwheel, promontories, stele, torii, jumbotron frame, hero tile | MCP procedural part-builds (posts, beams, wedges; painterly materials) |
| Teahouse shells, porches, noren | MCP part-builds; interiors dressed with vetted Creator Store props |
| Foliage, garden rocks | Creator Store (vetted) + procedural rocks |
| Fate washi sheets / emakimono scroll | Thin parts + slight-bend meshes |
| Audio (taiko roll, flap clacks, bell bong, water ambience) | Roblox audio library — licensed marketplace sounds, **no upload pipeline needed** |
| Lighting | Manifest-driven `Lighting` config + lantern PointLights (scripted) |

**Durable artifacts**: generated geometry serializes to committed Rojo-synced model files (parent §8 intent); MCP builder scripts are throwaway tooling; the ZenDojo `ThemeManifest` swaps placeholder IDs for real asset entries as each lands (validation stays loud-failure).

**Flagged risk — reactive basin**: the parent wants a skinned-mesh water plane. MCP mesh generation may not produce boned meshes. **Build the fallback first**: choreographed concentric ripple rings (transparent toruses tweened outward from the strike point) — pure parts, reads ~90% as good. Skinned mesh becomes an upgrade, not a dependency.

## 7. Build sequence (blockout-first)

| Pass | Content | Gate |
|---|---|---|
| 0 — Pipeline proof | One MCP-built model → serialized → Rojo-synced committed file → loads in a fresh place; painterly palette registered in manifest | Pipeline works end-to-end |
| 1 — Graybox | Terrain bowl + tiers, sandō path, building shells, flume line, promontory stubs, jumbotron position — massing only | **Playtest walk-through**: scale (bell vs avatar), sightlines (bell + board from every tier and porch), walk-feel. Iterate here while moves are cheap |
| 2 — The monument | Bell, pavilion, wheel, flume, basin + ripple system (fallback rings first), draw chain visually hooked to existing `HammerCurve` cues; **throw drum + housing + DrumController** (§4b) | Full round reads at the center; drum holds prior throw → drumrolls → locks on the strike |
| 3 — The bowl | Terrace materials, teahouses + interiors, lantern rig; **minimal bottom HUD redesign + ticker** (§4b) | Bowl feels inhabitable; HUD is unobtrusive, prose flows in the ticker |
| 4 — Periphery & inhabitants | Torii, koi pond, foliage, fate models wired through manifest, champions (`ChampionSeats` + statues + stele); **3 kōsatsu boards at pedestal bases** (§4b, board renderer refactored off the removed jumbotron) | Fates read in real dress; champions dress from live data; kōsatsu show round state |
| 5 — Unification | Arena-wide lighting pass, full audio wiring, R15 pin in Game Settings, final tune | Done-criteria below |

Every pass ends with the MCP playtest-screenshot loop plus a user walkthrough for taste calls (passes 1 and 5 carry the user's terrain-polish and lighting-judgment slots).

## 8. Testing

- **Lune**: `ChampionSeats` fully unit-tested; `ThemeManifest` validation extended to every new asset key (missing = loud boot failure); the 113 existing machinery tests stay green untouched.
- **Visual**: MCP playtest screenshots at each pass gate; checkpoints shared in PR descriptions (`.superpowers/` stays gitignored).
- **Perf**: every gate also runs at minimum graphics quality.

## 9. Out of scope (4b)

Teahouse TextChannel manager, self-win screen-space feedback, tremble final tuning (→ a small 4c); wordmark watermark (deferred, no home); JadeCourt assets; authored animations and image-asset uploads (M5); dethronement theater; pot-escalation effect policy.

## 10. Done criteria

- No placeholder geometry remains; the giant floating jumbotron is gone.
- The full round reads in the real set: draw → latch click → tremble → release → BONG → ripples → reveal, under final lighting. The throw drum holds the prior throw, drumrolls in TALLY, and locks the new throw on the strike.
- Manifest validation green with all-real asset entries; all Lune tests green (113 existing + `ChampionSeats` + any new pure modules).
- Champions dress from live data; PWA-effigy fallback works; stele shows all-time top-10.
- 3 kōsatsu boards show round state; minimal bottom HUD with the prose ticker; top of screen clear.
- Stable at minimum graphics quality.

## 11. Decisions log

| Decision | Choice | Why |
|---|---|---|
| Centerpiece | Karesansui apron; Striker monument sole centerpiece; tatami + engawa deleted | Competing centerpieces; less is more (user) |
| Water crossing | Kakehi flume over the gravel → overshot wheel | Unbroken dry garden; legible power train; Nanzen-ji precedent |
| Champions | 3 living statues (Record/Streak/Local Hero) + all-time stele; statues via HumanoidDescription; jizō effigy for PWA holders | Living vs eternal split; ≥4 seats dilute the honor; champions are rarely present so likenesses, not occupancy |
| Champion placement | Terrace promontories (stele by the gate) | Visible during play; Local Hero spot doubles as a real flex spot |
| Art direction | Painterly stylized, built-in materials only | Warmth for the hangout KPI; no M5 texture dependency; low-end mobile budget |
| Production | Hybrid leaning MCP-driven; Creator Store only for vetted dressing; user on terrain polish + lighting taste | MCP loop proven same-day; control over hero pieces |
| Sequencing | Blockout-first graybox, then quality passes | Proportion/sightline mistakes get caught while cheap |
| Watermark | Deferred | No home without tatami (user) |
| Scope trim | TextChannels + carried tuning → 4c | Keep 4b purely "make it look real" |
| Basin ripples | Fallback rings first, skinned mesh as upgrade | De-risk unknown MCP boned-mesh support |
| Arena scale | 2× the original (bowl r220, rim 28; tanada terraces, rolling backdrop hills) | Felt cramped; user wanted a discovered-amphitheater that fills every sightline (2026-06-07 gate) |
| Entrance | Rim gate plaza (torii/stele/spawn on the rim) + sandō ramp carved down the tiers; E/W terrace ramps | Arrive high, descend into the bowl; terraces must be walkable (2026-06-07 gate) |
| Display system | Throw drum (replaces hero tile) + 3 kōsatsu + minimal HUD; **giant floating jumbotron removed** | Stadium slab broke the zen aesthetic; flap is for slow tabular state, prose belongs in HUD (2026-06-08 gate) |
| Throw drum | Hexagonal, horizontal axis, water-driven escapement (always dwells on a full face); holds prior throw, drumrolls in TALLY, locks new throw on the bell strike; two-sided via 180° face pairing | Turns like the waterwheel (water kinship); prior-throw reminder at lockout; mechanically married to the striker (user concept + gate refinements) |
| Kōsatsu | 3 single-faced boards at pedestal bases, facing inward; round#/players/last-5 | Single face sufficient up close with three around the ring (2026-06-08 gate) |
| Jumbotron text legibility (historical) | Roblox TextSize caps at 100px and TextScaled was inert → big SurfaceGui text needs a SMALL canvas | Recorded in the [[roblox-surfacegui-textsize]] memory; reuse for drum/kōsatsu/HUD text |
| Board font | Merriweather, optically centered in the tile (frame + padded glyph + seam) | Softer/more elegant than GothamBlack; caps centered, not riding high (2026-06-07/08 gate) |
