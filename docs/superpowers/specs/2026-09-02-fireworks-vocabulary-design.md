# Fireworks Vocabulary (Wave One) — Design

**Date:** 2026-09-02
**Status:** Approved in conversation (owner, 2026-09-02)
**Program context:** Second of four fireworks sub-projects (range ✓ → **vocabulary** → handheld → distribution). The proving range ([[fireworks]], spec 2026-09-01) is the review loop this project feeds.

## Purpose

Shell variety is a first-class financial goal (owner ruling, recorded on
[[fireworks]]), but the render vocabulary can only say one thing: a radial burst
varying in color, spread and droop. This project gives recipes visibly different
break styles, staged multi-burst structure, real textures, real audio, and a glow
treatment — so the draft catalog can grow into many distinct sellable shells, all
provable at the range, all inside the binding mobile perf rules.

**Discovered during design, load-bearing:** `FireworkSchedule.compile` ALREADY
supports staged shells — `points` (break points), `scatter`, and budget `share`
per burst phase, with the per-shell budget divided so nesting never multiplies
cost. Nothing has ever exercised it. Staged fireworks are therefore wave one,
not a later project; the work is validation, seed drafts, and style composition —
not compiler changes.

## Decisions (owner, 2026-09-02)

- Wave-one styles: **ring, palm, strobe, kamuro** (plus `peony`, the name for
  today's radial default).
- **Both textures** (crisp round dot + short streak), authored by Claude,
  uploaded by the owner.
- **Done = styles + seed drafts**, provable at the range. Promotion to the shop
  stays per-shell and owner-gated; pricing tiers/Robux remain the distribution
  project.
- **Vibrancy is in scope** (owner: "we really need them to be vibrant, sparkly,
  colorful") — the glow stack, §7.
- **Audio is in scope** (owner supplied recordings) — §8.
- Architectural choice: **`style` is a field on burst phases**, not new phase
  kinds. Kinds stay exactly `report/ascent/burst`; the budget compiler is
  untouched; styles are pure render vocabulary. (New-kind-per-style and
  raw-emitter-params-in-recipes were both considered and rejected: the first
  makes every style a budget-logic change, the second turns authoring into
  emitter programming with no central tuning.)

## Binding constraints (unchanged from [[fireworks]])

Client-side VFX only; pooled emitters, no instance churn; NO per-shell
PointLights ever; ONE global Bloom; the per-shell particle budget and the
director's concurrent-shell cap stay exactly as measured. A style must never
change a shell's particle cost (§6 tests this).

## 1. BurstStyles.luau (new, shared, pure, Lune-loadable)

One module maps each style name to a **complete** emitter configuration:

- `speed` (min/max), `drag`, `lifetime` (min/max), `acceleration`,
  `brightness` (§7), `transparency` (keypoint list — strobe's flicker is a
  ~16-keypoint curve, others a plain fade), `spreadAngle` mode, `textureRole`
  (`dot` | `streak`), `soundRole` (§8),
- and a **point rule** — how a burst phase's break points place and aim:
  - `peony`, `strobe`: random scatter in a ball (today's behavior), omnidirectional.
  - `ring`: planar emission; the plane is randomly tilted per shell **from the
    seeded RNG**, so every client sees the same ring.
  - `palm`: points on a horizontal circle around the anchor, each emitting a
    narrow cone aimed outward-and-up; heavy droop makes the arms.
  - `kamuro`: single point, long-lifetime gold, heavy drag and droop.

Completeness is a hard rule: pool emitters are shared across shells, so any
property a style fails to write is inherited from the previous shell. Every
style declares every property the controller applies; a test enforces it (§6).

Data is plain numbers/strings/lists — no Roblox types — so the module and its
tests run under Lune. The controller translates to NumberRange/NumberSequence/
Vector3 at apply time.

## 2. Schema (FireworkRecipes.luau grows)

- `style`: optional on burst phases, must be a `BurstStyles` name (membership
  check — a typo'd style fails `lune run tests/run`, not the sky). Default
  `peony`.
- The already-live staged fields get validated instead of ignored: `points` an
  integer 1..8 (`MAX_POINTS` — the pool's per-slot break-part count), `scatter`
  a non-negative number, `share` a positive number. `style`/`points`/`scatter`/
  `share` on a non-burst phase is an error.
- One schema, as before: catalog and drafts both held to it.

## 3. Controller (FireworkController.client.luau)

`fireBurst` consults `BurstStyles[ev.style or "peony"]` and applies the FULL
property set per emit; point placement and aim follow the style's point rule,
using the shell's seeded RNG for anything random (ring tilt, palm arm phase) so
all clients agree. Budget, pooling, LOD, director, slot lifetime: untouched —
except the slot-release delay, which must respect the longest style lifetime
(kamuro hangs longer than the current 2.6s tail; the release becomes
style-aware rather than a constant).

## 4. Textures

Two PNGs, authored in-repo (source under `roblox/tools/textures/`, following
that directory's existing conventions), uploaded by the owner:

- **dot** — crisp round core with a tight falloff; the fix the 2026-07-20 bench
  named ("the real fix for crisp sparks is a custom round-dot upload — lower
  overdraw too"). Used by peony/ring/strobe.
- **streak** — short vertical streak for trailing looks. Used by palm/kamuro.

Ids live in `BurstStyles.TEXTURES = { dot = "rbxassetid://…", streak = … }`;
styles and recipes name ROLES, never raw ids, so a texture swap is one edit.
Until the owner's uploads clear moderation, both roles point at the built-in
sparkle — the pipeline works before the art does.

## 5. Seed drafts (FireworkDrafts.luau grows)

One family per style plus one staged demo, all range-provable on day one and
all authored SATURATED (§7):

- `wa` (輪, ring) — variants ladder ring radius/tilt spread.
- `yashi` (椰子, palm) — variants ladder arm count (points) and droop.
- `hotaru` (蛍, strobe) — variants ladder flicker rate and cloud size.
- `kamuro` — variants ladder lifetime and gold warmth.
- `dan` (段, the staged demo) — primary peony → secondary strobes at scattered
  points (`points`/`scatter`/`share`) → kamuro sigh; three timed burst phases,
  each with its own style. Exists to exercise the dormant staging machinery and
  to prove styles compose.

(Family names are romaji per the working convention; kanji stays in comments.)

## 6. Tests (Lune)

- **Style completeness**: every style declares every property in the applied
  set; a style added without, e.g., `transparency` fails.
- **Schema**: style membership; points/scatter/share bounds; staged fields
  rejected on non-burst phases.
- **Budget invariance**: for every seed draft, `FireworkSchedule.compile`
  particle totals are identical with styles stripped — styles never touch cost.
- **Point rules are pure**: ring tilt/palm placement derived from a seeded RNG
  interface, deterministic under test.
- **Drafts validate**, as today, via the one schema.

## 7. The glow stack (vibrancy)

Owner: particles read dull; they must be "vibrant, sparkly, colorful". Four
multiplying levers, all in scope, none of them lights:

1. **`LightInfluence = 0`** pool-wide — the pool never sets it, so it defaults
   to 1 and scene lighting DIMS the stars, worst exactly at night. Fireworks
   answer to no ambient light.
2. **`Brightness`** per style in BurstStyles — pushed past ~2–3 the star color
   crosses the global Bloom's 0.95 threshold and blooms. This is the
   "burning magnesium" read, delivered through the ONE existing Bloom.
3. **Texture** — §4's crisp dot concentrates energy the fuzzy sparkle smears.
4. **Color authoring** — seed drafts use saturated cores with hot near-white
   edge flashes; the range's ladders are the tuning instrument.

Per-shell PointLights remain banned; no second BloomEffect, ever.

## 8. Audio

Source: `~/Desktop/Roshambo Reference/sound/fireworks/` — 87 files, 573 MB:
65 WAV + 18 UNEXPANDED ZIP PACKS + 4 stragglers (aiff/flac/mp3/ogg),
Freesound-convention names the owner says NOT to trust. So triage is
manifest-driven, not name-driven:

1. **Expand + measure**: zips extracted to a working directory (the reference
   dir itself is the owner's and stays untouched); a committed tool
   (`roblox/tools/audio/survey_fireworks.py`, sibling of `measure_caws.py`)
   walks everything and writes a manifest — file, duration, peak/RMS, spectral
   centroid and low-band energy (booms are low-heavy, whistles tonal, crackle
   broadband) — plus a proposed category: `report`, `whistle`, `burst`,
   `crackle`, `ambience`, `reject`.
2. **Owner audition by category**, not by file: shortlists per category, judged
   the way the dock uguisu was — in situ, at the range, over the real canyon
   acoustics.
3. **Cut + normalize**: chosen takes get the birdcall-cutter treatment
   (bandpass, gate, ONE COMMON GAIN across the whole set so shells don't
   lottery in loudness). Burst clips are cut as **composites** — boom plus its
   crackle/sizzle tail in one file per style (peony boom; strobe boom-into-
   crackle; kamuro boom-into-long-sizzle) — because each pool slot owns ONE
   Sound and phases never overlap; composites need zero new machinery.
4. **Upload + wire**: owner uploads (moderation queue); ids land in
   `BurstStyles.SOUNDS` keyed by role; recipes/styles name roles. The catalog's
   stand-in `rbxasset` clips remain the fallback until uploads clear.

Rolloff is already correct per slot (InverseTapered, capped at the director's
near radius) and does not change.

## Non-goals

- Promotion/pricing/Robux SKUs (distribution project). Wave one ships drafts.
- Handheld items (sparkler/roman candle — next project).
- Yonshakudama (parked by owner ruling 2026-09-01, on [[fireworks]]).
- New perf benching; the particle budget and director cap are taken as given.
- Crossette as a named style — staged bursts via `points`/`scatter` already
  produce the crossette read; if a dedicated directed-split style is wanted
  later, it's one more BurstStyles row.
