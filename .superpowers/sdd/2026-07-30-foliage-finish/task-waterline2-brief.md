# Task: waterline recipe upgrades in the pure planner (ZoneScatter)

Two new capabilities for the WaterMargin family of recipes, driven by a user gate on the
canyon's shoreline planting. PURE PLANNER ONLY: `roblox/tools/builders/ZoneScatter.luau`
+ tests appended to `roblox/tests/ZoneScatter.spec.luau`. The Studio mirror, recipe
values, terrain painting, and the bake are the controller's follow-up; do NOT touch any
other file.

## 1. Per-species submergence override

Today `Recipe.submergeMax` is one number for the whole pool, so a fern is allowed to
wade exactly as deep as a reed. Add an OPTIONAL `submergeMax` to the species entry:

```luau
export type Species = { name: string, weight: number, scale: number?, submergeMax: number? }
```

**Semantics.** The recipe-level `submergeMax` keeps its current meaning as the SAMPLE
gate (an unchanged pre-filter: a sample deeper than the recipe value is rejected before
any species is drawn). After a species is picked for an accepted sample, compute its
effective limit = `species.submergeMax` if present, else `recipe.submergeMax`. If
`sample.depth` exceeds that limit, RE-PICK (fresh `pickSpecies` roll from the same
stream) up to 4 total attempts; if all 4 attempts exceed their limit, SKIP the sample
entirely (no placement). Species without an override behave exactly as today.

Apply this in the per-sample scatter path AND to grove members/elders (a grove recipe
with submergence is legal even if none exists today) — anywhere `pickSpecies` chooses a
species for a sample with a known depth. Clump children inherit their parent's species
as they do now (no re-check).

## 2. Feature affinity (`rockAffinity`)

Generalises the existing `groveAffinity` idea to an arbitrary injected point set, so
waterline planting can gather at the shore rocks placed by the ShoreRocks pass.

```luau
-- Recipe gains:
rockAffinity: { radius: number, inside: number, outside: number }?
-- PlanOptions gains:
rocks: { { x: number, z: number } }?
```

**Semantics.** Identical in shape to `groveAffinity` but keyed on `opts.rocks`: a
recipe carrying `rockAffinity` multiplies its effective density (the same slot that
`careDensity` multiplies — they COMPOUND, both apply) by `inside` when the sample lies
within `radius` of any rock point, else by `outside`. Build the lookup with the existing
`ZoneScatter.indexWater` helper and query with `waterWithin`, exactly as the grove-anchor
index does. With `opts.rocks` nil or empty, a recipe with `rockAffinity` behaves as if
every sample were `outside`.

**Determinism:** unchanged inputs → identical output. No `math.random`. Integer LCG only.

## Tests (RED first, then implement)

Append to `roblox/tests/ZoneScatter.spec.luau` using the existing flatSamples/CORE
helpers and the file's established style. Cover at least:

1. **Determinism** — a plan using both new features is identical across two runs.
2. **Species submergence gates** — a pool of two species where species A has
   `submergeMax = 0` and species B has `submergeMax = 2`, over samples with depth 1:
   every placement is species B (A is always re-picked away).
3. **Skip when all attempts fail** — a single-species pool whose species has
   `submergeMax = 0`, over samples with depth 1: ZERO placements (not a crash, not a
   fallback placement).
4. **No override = unchanged** — the same plan with no per-species values equals the
   pre-change behavior (assert against an explicit expected count/species mix, not
   against a re-run of the same new code path).
5. **Recipe gate still pre-filters** — a sample deeper than the RECIPE `submergeMax` is
   rejected even when a species override would allow it (the recipe value is the outer
   bound).
6. **rockAffinity inside/outside** — `rockAffinity = { radius = 10, inside = 1,
   outside = 0 }` with one rock point: every placement lies within 10 studs of it.
7. **rockAffinity with no rocks** — same recipe, `opts.rocks` nil: behaves as all-outside
   (with `outside = 0`, zero placements).
8. **Compounding** — a recipe with BOTH `careDensity` and `rockAffinity` multiplies both
   (assert a placement count strictly between the two single-factor counts, or an
   equivalent unambiguous check).

## Constraints

- Work from /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
- `lune run tests/run` all green (763 existing); lint `stylua --check src tools tests &&
  selene src tools` (selene FAILS on warnings; run from roblox/, rokit-managed).
- `--!strict`; match the file's existing style and comment register (explain WHY a rule
  exists, in the voice of the surrounding comments).
- Commit message: `feat(roblox): per-species submergence + rock affinity for waterline planting`
  ending with:
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01Wkn8pmb3GYwsXZrSRnZYNu
