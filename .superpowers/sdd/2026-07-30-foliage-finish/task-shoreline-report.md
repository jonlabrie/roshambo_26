# Task: shoreline stations — report

## Status: DONE

## Commit
`1fe0d35` — `feat(roblox): shoreline stations - mixed handfuls marching along the shore`
(2 files changed, 490 insertions(+), 5 deletions(-))

## Test summary
`lune run tests/run` from `roblox/`: **783 passed, 0 failed, 783 total** (776 baseline + 7 new shoreline tests). `stylua --check src tools tests` and `selene src tools` both clean (0 warnings/errors).

## What was built

`roblox/tools/builders/ZoneScatter.luau`:
- New `ShorelineConfig` export type (`stationSpacing`, `membersMin/Max`, `spread`, `inland`) and a `shoreline: ShorelineConfig?` field on `Recipe`.
- A shoreline pre-pass, modelled closely on the existing grove pre-pass: its own LCG stream (`shoreStates`/`shoreRoll`, seed offset `SHORE_SEED_OFFSET = 700000`), exhaustive (non-dart) station selection, and exclusion from per-sample resolution (extended the existing grove-exclusion closure in the per-sample loop to also exclude `recipe.shoreline ~= nil` zones).
- **Shore samples**: grid samples that pass `contains` + `not keepOutAt` + `accepts(zone, s)` + `waterWithin(water, s.x, s.z, recipe.nearWater or 0)`.
- **Stations**: greedy walk of the sorted shore samples, accepting one whenever it clears `stationSpacing` from every prior station.
- **Water direction / inland push**: probes the four cardinal offsets at `pitch` distance (`waterWithin(..., pitch/2)` — same grid-cell tolerance as `sampleKey`), sums unit vectors toward wet probes; none/all four wet → no bias (inert push, not a crash).
- **Members**: per station, target count = `membersMin + floor(roll*(membersMax-membersMin+1))`. Each member gets up to 3 attempts: polar offset (angle/radius≤spread) + additional inland push (≤`inland`) → `nearestSample` lookup (nil skips the attempt) → `accepts(zone, probe)` → `spacingMin` check against every same-layer placement already in `out` → independent `pickWadingSpecies` draw. Any failure retries; 3 failures abandon the slot (no backfill).

`roblox/tests/ZoneScatter.spec.luau`: appended a `describe("ZoneScatter shoreline pass", ...)` block with the 7 required tests (determinism, follows-the-shore, stations-spaced, mixed-handfuls, per-species-gates-within-a-handful, member-count-respected, no-per-sample-scatter).

## TDD / RED findings worth flagging

I wrote all 7 tests first and ran them against the unmodified planner to check they fail for the right reason. Only **3 of 7** were robustly RED pre-implementation, for structural reasons:
- "stations are spaced" (no two closer than `stationSpacing*0.8`)
- "member count is respected" (no station exceeds `membersMax`)
- "does NOT also scatter per-sample" (bounded by `stations * membersMax`)

The other 4 (determinism, follows-the-shore, per-species-gates, mixed-handfuls) **passed even before the shoreline pass existed**, and I judged forcing them into artificial RED wasn't worth the fragility it would introduce:
- **Determinism** and **per-species-gates**: these test behavior (LCG reproducibility, `pickWadingSpecies` narrowing) that already existed in the ordinary per-sample path — they're legitimate regression coverage for the new pass, just not discriminating power against the old fault.
- **Follows-the-shore**: with a water line spanning the full 100-stud z-range, *any* nearWater-restricted scatter (old or new) already has along-axis range ≫ across-axis range, so this assertion (as the brief specifies it) can't discriminate given that geometry.
- **Mixed-handfuls**: old per-sample scatter draws each point's species independently anyway, so it's *already* locally mixed absent clumping. I tried forcing a RED via `clumpChance=1` + low `zone.densityScale` (clump children inherit the parent's species — the actual fault), but hit a real geometric conflict: `recipe.spacingMin` is reused by the new pass for member-to-member spacing, and by clumping for parent-to-parent spacing, and no single value made both a clean old-fault demonstration (well-isolated monospecific clumps) and a viable new-code multi-member station simultaneously — empirically, sparse clumps still occasionally landed close enough to falsely register as "mixed" via post-hoc clustering, which is a *worse* signal (looks like a pass, isn't a real one) than leaving the test as a straightforward regression check. I reverted to the literal brief-spec recipe.

None of this affects correctness of the shipped implementation — it's purely about which tests could serve as pre-implementation proof. I verified the implementation is right by (a) the 3 genuinely-RED tests going GREEN, and (b) manual review of the pre-pass against the brief's exact semantics.

## Files touched
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tools/builders/ZoneScatter.luau`
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/ZoneScatter.spec.luau`

## Note on working-directory state
Two other files (`roblox/tools/studio/foliageZoneRecipes.luau`, `roblox/tools/studio/scatterPreserve.luau`) showed as modified in `git status` during this session (iris pool weight tuning, unrelated to this task) — these were **not** touched by me; they reflect concurrent activity elsewhere in this shared working directory. I staged and committed only the two files named in the brief.

## Concerns
- None blocking. The two "not robustly RED" tests I couldn't cleanly force (mixed-handfuls, follows-the-shore) are documented above for the record — the controller/follow-up work (Studio mirror, recipe values, bake) should be sufficient to validate real-world "mixed handful" behavior visually, per the user's original gate complaint.
