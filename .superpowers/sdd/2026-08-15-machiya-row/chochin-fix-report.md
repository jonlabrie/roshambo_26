# The kit chōchin is the canyon chōchin — fix report

## What was wrong

`Machiya.luau`'s identity-kit `chochin` branch restated `tools/studio/buildHanabiyaChochin.luau`
(the owner-gated Studio tool behind the accepted `Chochin_Hanabiya`) at reduced density: 10
slices / 8 ribs and a straight `HangRod` cylinder, instead of the canonical 18 slices / 16 ribs
with a real 14-segment hoop ring. Colours and scale already matched (they were derived
correctly), but the shape didn't — the owner's objection was "you designed new chōchin instead
of using the existing, canyon-wide pattern."

## Fix

- New `tools/builders/Chochin.luau`: a pure Spec-emitting builder (same shape as `StoneLantern.luau`)
  that reproduces the canonical lantern's geometry exactly — ring, barrel, ribs, caps, hook, and
  the two tagged glyph plates.
- `Machiya.luau`'s `identity.chochin` branch now only computes *where* to hang two lanterns (the
  eave's outside corners, per the existing eave-tilt math) and calls `Chochin.build(name, x, z,
  armY)` for each. The hem-clearance assert stays in `Machiya.luau`, computed via the new
  `Chochin.hemY(armY)` helper so the formula lives in one place.
- New `tests/Chochin.spec.luau`: drift guard (reads the Studio tool's source as text and checks
  the module's constants against its literals) + module behaviour tests (part counts, tag
  presence, hem-clearance formula).

## Canonical constants ported

| Constant | Studio tool value (`buildHanabiyaChochin.luau`) | Module value (`Chochin.luau`) |
|---|---|---|
| LS (lantern scale) | `0.65 / 0.9` | `0.65 / 0.9` |
| Rmax | `0.9 * LS` | `0.9 * LS` |
| capR | `0.30 * LS` | `0.30 * LS` |
| bodyH | `2.8 * LS` | `2.8 * LS` |
| ringR | `0.22 * LS` | `0.22 * LS` |
| tubeR | `0.05 * LS` | `0.05 * LS` |
| HOOK_DROP | `0.22` | `0.22` |
| N (barrel slices) | `18` | `18` |
| centerIdx | `9` | `N // 2 = 9` |
| ribs | `16` (`for j = 1, 16`) | `16` |
| ring segments | `14` (`for i = 0, 13`) | `14` |
| INK | `Color3.fromRGB(46, 40, 30)` | `{0.18, 0.157, 0.118}` (÷255) |
| METAL | `Color3.fromRGB(120, 122, 128)` | `{0.47, 0.478, 0.502}` (÷255) |
| PAPER | `{200, 170, 143}` | `{0.784, 0.667, 0.561}` (÷255) |
| PAPER_T | `0.42` | `0.42` |
| light colour | `Color3.fromRGB(255, 168, 96)` | `{1.0, 0.659, 0.376}` (÷255) |
| profile formula | `capR + (Rmax-capR)*(1-d^6)^0.5` | `capR + (Rmax-capR)*sqrt(1-d^6)` (sqrt/mul, same as the *already-correct* restated version, kept for CI arch-stability) |

All colour/scale constants already matched in the restated version (they were derived correctly)
— the actual defect was density (N=10→18, ribs=8→16) and the ring (`HangRod` cylinder → real
14-segment hoop, ported with `cos`/`sin`, permitted per the brief since `Spec.segment` +
`JsonEmit`'s near-zero rounding already make trig arch-stable elsewhere in `Machiya.luau`).

## The glyph-plate / tag question — investigated, decision: EMIT THE TAG

Checked `Spec.luau` (a plain `Spec.part` properties table with no special-casing of `Tags`),
`JsonEmit.luau` (generic recursive JSON encoder — any property key, including an array-valued
one, passes through unchanged), and `genmodels.luau`'s `toRojo()` (copies `spec.properties`
verbatim into the Rojo node). None of them block a `Tags` property.

More directly: **this repo already ships committed assets with a `Tags` array property** in
model.json, built by this exact pipeline, against this repo's pinned Rojo 7.7.0
(`rokit.toml`) — `grep -l '"Tags"' assets/*.model.json` hits `MachiyaApparel`, `Hanabiya`,
`Overlook`, and `SwitchbackDeck`. `Machiya.luau` itself already emits `Tags = { "NorenSeg" }`
on noren segments (line ~1141) via the identical mechanism, and the *previous* (restated)
chōchin branch was already emitting `Tags = { "RoundLantern" }` on its glyph plates — that part
of the restated code was correct, just attached to under-fidelity geometry.

Decision: `Chochin.build` emits the plate with `Tags = { "RoundLantern" }`, unchanged from
before. No limitation to report — Rojo model.json supports instance tags in this repo's toolchain
and it was already proven working.

## RED / GREEN evidence

RED (module didn't exist yet):
```
error requiring module "../tools/builders/Chochin": could not resolve child component "Chochin"
```
(from `lune run tests/run`, `tests/Chochin.spec.luau` requiring `../tools/builders/Chochin`
before the module was written)

GREEN (after implementing `Chochin.luau` and wiring `Machiya.luau`):
```
1143 passed, 0 failed, 1143 total
```
(the pre-existing `[WARN] [QUEUE] ...` lines are `HandlerQueue.spec`'s own deliberate
error-injection test, unrelated to this change)

## Determinism check (genmodels run twice, diffed)

```
$ lune run tools/genmodels   # run 1, saved assets/MachiyaApparel.model.json
$ lune run tools/genmodels   # run 2
$ diff run1.json run2.json
DETERMINISTIC: run1 == run2
```
No output from `diff` — byte-identical across runs, confirming the new `cos`/`sin` ring loop
doesn't introduce arch/run nondeterminism (JsonEmit's near-zero snap + `%.9g` formatting hold).

## Byte gates

- `git diff --exit-code assets/Hanabiya.model.json` → clean (Hanabiya's `identity` has no
  `chochin` field, so it never touched this code path; its model file is untouched).
- `git diff --exit-code default.project.json` → clean (no new stage children).
- `assets/MachiyaApparel.model.json` changed as expected (denser lanterns), and was regenerated
  and is meant to be committed:
  - `Slice_*` parts: 18 → 34 (17 per lantern × 2, was 9 × 2)
  - `Rib_*` parts: 16 → 32 (16 per lantern × 2, was 8 × 2)
  - `LoopSeg_*` parts: 0 → 28 (14 per lantern × 2 — the new ring; `HangRod` count 2 → 0)
  - `RoundLantern` tag count: 4 → 4 (unchanged — the tag was already present and correct)

## stylua / selene

```
$ stylua --check src tests tools   # after auto-format pass
(clean)
$ selene src tools
0 errors, 0 warnings, 0 parse errors
```
(One `unused_variable` warning for a stray `capR` local was caught and fixed before this — Chochin.luau
uses `Chochin.capR` directly inside `profile()` rather than a shadowing local.)

## What the drift test covers, and what it skips

Covers (parsed as text from `tools/studio/buildHanabiyaChochin.luau` and compared to the module's
exported constants, `tests/Chochin.spec.luau`):
- LS, Rmax, capR, bodyH, ringR, tubeR (as formulas: literal multiplier × LS)
- N (slice count) and centerIdx
- rib count (from `for j = 1, 16 do`)
- ring segment count (from `for i = 0, 13 do`, i.e. 14 segments)
- INK / METAL / PAPER colours (parsed as `Color3.fromRGB(r,g,b)` / `{r,g,b}` literals, compared
  ÷255 against the module's stored 0–1 floats, tolerance 0.001 to absorb 3-decimal rounding)

Skipped (documented in the spec file itself): the barrel profile formula
(`capR + (Rmax-capR)*(1-d^6)^0.5`) and the glyph-plate size/offset/yaw — these aren't simple
numeric literals in the tool's source, so a text-pattern match would be fragile and more likely
to bit-rot than catch real drift. The profile is instead covered *functionally*: a test asserts
`ChochinBody`'s radius equals `Chochin.Rmax` (the silhouette's known widest point, at its centre
slice), which would fail if the formula were ever broken in either copy in a way that changes
its peak value.

## Files touched

- `roblox/tools/builders/Chochin.luau` (new)
- `roblox/tools/builders/Machiya.luau` (identity-kit `chochin` branch replaced with calls into `Chochin`)
- `roblox/tests/Chochin.spec.luau` (new)
- `roblox/assets/MachiyaApparel.model.json` (regenerated, denser lanterns)

---

# Follow-up: per-shop chōchin tints, with a night-legibility floor

## What changed

Owner-directed follow-up: the merchant row's lanterns get per-shop tinted paper barrels (the
row "varies" — shops advertising themselves), while paths and canyon-wide lanterns (the
wayfinding system, gate-tuned) stay canonical cream, unchanged.

- `Chochin.build(name, x, z, armY, paperRGB255?)` — new optional 5th parameter. Units are the
  SAME 0-255 ints the Studio tool's own `local PAPER = { 200, 170, 143 }` literal uses (verified
  by reading the tool's source — it's a plain human-readable RGB table, not the 0-1 floats
  `Chochin.PAPER` stores internally). The function does the `/255` conversion itself. Omit it (or
  pass `nil`) and behaviour is byte-identical to before — the default stays canonical cream, so
  the Studio tool, path lanterns, and 花火屋's place-only lanterns are unaffected, and the
  original drift test passes unchanged. The tint replaces only the base colour the per-slice
  gradient (`f`) scales — nothing else about the geometry, ribs, ring, caps, or glyph plates
  changes. The glyph plates never reference `paper` at all, so they cannot be tinted by
  construction (verified by a test that diffs a plain vs. tinted build's `GlyphPlateA`
  properties and finds them identical).
- `Chochin.hemY` unaffected (tint doesn't move geometry).
- New `Chochin.luminance(rgb01)` (Rec. 709 weights) and `Chochin.LEGIBILITY_FLOOR = 0.55`,
  exported so the guard test and any future caller share one formula/threshold.
- `Machiya.luau`'s `identity.chochin` is now `true` (canonical cream) OR a table
  `{ paper = {r, g, b} }` (0-255) tinting the barrel. `paperRGB255` is read via
  `type(identity.chochin) == "table" and identity.chochin.paper or nil` and threaded through to
  `Chochin.build`.
- `MachiyaShops.apparel.identity.chochin = { paper = { 170, 178, 200 } }` — pale indigo,
  rhyming with (not matching) the shop's deep-indigo noren `{0.16, 0.18, 0.32}`.
- `MachiyaShops.luau` gained a reserved-palette comment block (before the `MachiyaShops.accessories`
  definition) for Tasks 5-7: accessories -> light moss/green-grey (unchosen), chaya -> warm
  persimmon/russet, 花火屋 -> stays canonical cream. True red (赤提灯) explicitly excluded — it
  conventionally signals an izakaya, and none of these shops are one.

## Units check

Confirmed by reading `tools/studio/buildHanabiyaChochin.luau`: `local PAPER = { 200, 170, 143 }`
is a plain 0-255 RGB literal (fed to `Color3.fromRGB` semantics elsewhere in that file, e.g.
`local INK = Color3.fromRGB(46, 40, 30)`). The module's own `Chochin.PAPER` is the pre-divided
0-1 form (`{0.784, 0.667, 0.561}`, commented `-- {200, 170, 143} / 255`). `paperRGB255` matches
the tool's human-authored units so a shop author writes an ordinary RGB triple in
`MachiyaShops.luau`, and `Chochin.build` is the single place that converts.

## Legibility guard — RED/GREEN

RED (before fixing the "f=1 at centre" assumption in two of the new tint tests — the
`ChochinBody` slice sits at `tt = (CENTER_IDX + 0.5) / N = 0.5278`, not exactly `0.5`, so the
gradient factor `f` is `~0.988`, not `1.0`):
```
FAIL  Chochin.build — per-shop paper tint > default (no tint) matches canonical cream exactly at the centre slice (f=1)
      expected {0.7679, 0.6533, 0.5495} to deep-equal {0.784, 0.667, 0.561}
FAIL  Chochin.build — per-shop paper tint > a tint replaces the base colour the gradient scales, nothing else
      expected {0.6530, 0.6837, 0.7682} to deep-equal {0.6667, 0.6980, 0.7843}
1147 passed, 2 failed, 1149 total
```
Fixed by comparing ratios (recovering `f` from the default build's own colour, then checking
`tinted == tint01 * f`) instead of assuming `f == 1`.

GREEN:
```
1149 passed, 0 failed, 1149 total
```

## Legibility floor values

| Tint | RGB (0-255) | RGB (0-1) | Luminance | Clears 0.55? |
|---|---|---|---|---|
| Canonical cream (`Chochin.PAPER`) | {200, 170, 143} | {0.784, 0.667, 0.561} | 0.684 | yes (reference) |
| Apparel (pale indigo) | {170, 178, 200} | {0.667, 0.698, 0.784} | 0.698 | yes |

The guard test (`describe("Chochin legibility guard...")` in `tests/Chochin.spec.luau`) walks
every entry of `MachiyaShops` generically (`for shopKey, shop in MachiyaShops do ... end`,
filtering to table-form `identity.chochin.paper`) rather than hardcoding shop names, so a future
shop's tint is checked automatically without anyone remembering to add a new assertion — a dark
lantern fails CI, not just a code review.

## Gates (this round)

```
$ lune run tools/genmodels        # FIRST, per instructions — default.project.json untouched
$ git diff --exit-code default.project.json   # PROJECT CLEAN
$ lune run tests/run              # 1149 passed, 0 failed
$ git diff --exit-code assets/Hanabiya.model.json   # HANABIYA CLEAN
$ lune run tools/genmodels (again) && diff run1 run2   # DETERMINISTIC: run1 == run2
$ stylua --check src tests tools  # clean (after one auto-format pass)
$ selene src tools                # 0 errors, 0 warnings, 0 parse errors
```

`assets/MachiyaApparel.model.json` changed again (tinted `Slice_*`/`ChochinBody` colours only —
part names/counts/geometry unchanged from the previous round) and is committed.

## Files touched (this round)

- `roblox/tools/builders/Chochin.luau` (optional `paperRGB255` param, `Chochin.luminance`,
  `Chochin.LEGIBILITY_FLOOR`)
- `roblox/tools/builders/Machiya.luau` (`identity.chochin` table form threaded through)
- `roblox/tools/builders/MachiyaShops.luau` (apparel tint + reserved-palette comment block;
  `APPAREL_RACK_OVERRIDES` untouched)
- `roblox/tests/Chochin.spec.luau` (tint plumbing tests + legibility guard)
- `roblox/assets/MachiyaApparel.model.json` (regenerated, tinted slices)
