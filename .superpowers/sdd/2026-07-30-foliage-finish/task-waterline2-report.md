# Task waterline2 — report

Commit: `982a52e` — feat(roblox): per-species submergence + rock affinity for waterline planting
Files touched (only the two named in the brief): `roblox/tools/builders/ZoneScatter.luau`, `roblox/tests/ZoneScatter.spec.luau`

## What was built

### 1. Per-species submergence override

- New exported type `Species = { name, weight, scale?, submergeMax? }`; `Recipe.pool` retyped from an inline table shape to `{ Species }`.
- `pickSpecies` now returns a third value, the winning species' own `submergeMax` (nil if it has none).
- New `pickWadingSpecies(pool, depth, recipeSubmergeMax, rollFn)`: draws up to 4 times from the *same* roll stream; a draw succeeds when `depth <= (species.submergeMax or recipe.submergeMax or 0)`; returns `nil` if all 4 attempts fail. On a dry sample (depth 0) or a species with no override, the first draw always succeeds — one roll, byte-identical to the old `pickSpecies` call.
- New `pickWadingCoherentMember(...)`: the grove-coherent equivalent — re-rolls the existing dominant/attendant *threshold* roll (not a fresh pool draw) up to 4 times against a member's own depth, reusing each species' resolved limit.
- Wired into every site that previously called `pickSpecies` for a sample with a known depth:
  - the per-sample scatter path (skip via `continue`, no placement, if all 4 attempts fail)
  - grove elder selection, both COHERENT (`domSpecies`) and FREE-MIX branches — depth = the anchor's own depth; if the elder can't be found, the *whole grove* aborts (candidate consumed, no `zoneAnchors` entry, no placement) rather than seating a headless stand
  - grove member selection, both branches — depth = that member's own candidate depth (can legitimately differ from the elder's), skip-and-keep-hunting (not grove abort) if a member's ground can't take any tolerant species
- Clump children still inherit the parent's species with no re-check, per the brief.
- Recipe-level `submergeMax` is untouched — it remains the pre-filter in `accepts`, checked before any species is drawn.

### 2. `rockAffinity`

- `Recipe.rockAffinity: GroveAffinity?` (reused the existing `GroveAffinity` type — same shape as the brief specifies, no need for a new one).
- `PlanOptions.rocks: { { x: number, z: number } }?`.
- Inside `plan()`, right after the grove-anchor index is built: translate `opts.rocks` (named-field points) into positional `{x,z}` cells and build `rockIndex` via the existing `ZoneScatter.indexWater`.
- In the per-sample density-multiplier block (same slot as `careDensity` and `groveAffinity`), added a `rockAffinity` multiplier via `waterWithin(rockIndex, ...)`, applied *after* `groveAffinity` — pure multiplication (`density *= ...`), so it compounds with whatever came before. `opts.rocks` nil/empty naturally yields "outside" for everyone (empty index, `waterWithin` returns false).
- rockAffinity is per-sample-path only, mirroring `careDensity`/`groveAffinity` (neither of those apply inside the grove pre-pass either).

## Decisions inside the brief's latitude

- **Grove elder-fails-to-seat semantics**: the brief only explicitly describes per-sample skip. For groves I chose: if the elder species search exhausts all 4 attempts, abort the *entire* grove at that anchor (no elder, no members, no `zoneAnchors` entry) rather than seat a memberless anchor or fall back to an intolerant species. The anchor candidate is still consumed (not retried), preventing infinite loops. No test in the required list exercises this path directly (grove submergence wasn't in the 8-item test list), but I verified by construction that the no-override case takes exactly the same single-roll path as before, so all 763 pre-existing tests (many of which lean on exact grove roll-stream counts) are unaffected — confirmed by running the full suite with the new code.
- **Member-fails-to-seat semantics**: a member whose candidate can't support any tolerant species is skipped (ground consumed, no placement, loop keeps hunting for more members up to `memberTarget`) rather than aborting the whole grove — this is the closer analogue to the per-sample "skip the sample" behavior.
- **Test 8 (compounding)**: the brief suggests asserting a placement count "strictly between the two single-factor counts, or an equivalent unambiguous check." I probed this empirically and found the "between" framing isn't reliable — the two multipliers interact with the shared LCG stream and the greedy min-spacing pass in a non-monotonic way (confirmed across several seed/parameter combinations). I used the documented alternative instead: assert the combined-multiplier count is *strictly less than both* single-factor counts. This is actually a stronger proof of genuine compounding than "between" — it directly rules out the failure mode of only one multiplier being applied (an overwrite bug would make the combined count exactly equal one of the two single-factor counts, not strictly below both). Parameters (`careDensity=0.5`, `rockAffinity={radius=15, inside=1, outside=0.3}`, seed 7) were empirically confirmed as robust across 4 different seeds and 3 parameter sets before locking in the test values.
- **Test 4 baseline numbers**: pinned by running the exact pre-change `ZoneScatter.luau` (via `git stash`) against the test's recipe/sample/seed combo and hardcoding the observed output (68 total, 38 SpeciesA / 30 SpeciesB) — not derived by re-running the new code path.

## TDD process

1. Wrote all 8+ tests first (two new `describe` blocks appended: "ZoneScatter per-species submergence override" — 5 tests including the combined-features determinism test — and "ZoneScatter rockAffinity" — 3 tests), referencing the not-yet-existing `submergeMax` species field, `rockAffinity`, and `opts.rocks`.
2. Confirmed RED: `git stash`-ed the implementation, ran `lune run tests/run`. 5 of the 8 new tests failed for the right reason (species submergence, per-attempt skip, and rockAffinity filtering genuinely absent — old code silently ignores the new fields at runtime since Luau doesn't do field-membership enforcement, so failures were behavioral, not crashes/typos). The other 3 (determinism-of-rerun, no-override-baseline, recipe-gate-still-pre-filters) correctly passed even pre-implementation, since they test invariants that hold regardless — expected and consistent with what each test is actually verifying.
3. Restored the implementation (`git stash pop`), re-ran: all 771 tests (763 existing + 8 new) green.

## Test list (in `ZoneScatter.spec.luau`)

`describe("ZoneScatter per-species submergence override", ...)`:
1. "species submergence gates: the deeper-tolerant species always wins the re-pick" — two-species pool (submergeMax 0 vs 2), depth-1 samples, every placement is the tolerant species.
2. "skip when all 4 attempts fail: zero placements, not a crash or a fallback" — single intolerant species, depth-1 samples, zero placements.
3. "no override = unchanged (pinned to the pre-change baseline...)" — exact counts (68 / 38 / 30) pinned against the unmodified planner.
4. "the recipe-level gate is still the outer bound..." — recipe `submergeMax=0.3` on depth-1 samples rejects everything regardless of a permissive species override.
5. "determinism: a plan using submergence override + rockAffinity together is identical across runs".

`describe("ZoneScatter rockAffinity", ...)`:
6. "inside/outside: every placement lies within radius of the injected rock".
7. "no rocks supplied behaves as all-outside" — zero placements with `outside=0`.
8. "compounds with careDensity: BOTH apply..." — combined count strictly below both single-factor counts.

## Verification output

- `lune run tests/run` (from `roblox/`): **771 passed, 0 failed, 771 total** (763 pre-existing + 8 new). The `[WARN] [QUEUE] ... boom` lines are pre-existing, unrelated `HandlerQueue.spec` noise (deliberate simulated failure in that suite), not from this change.
- `stylua --check src tests tools`: initially reported diffs (line-wrapping only, from the new multi-line function calls); ran `stylua src tests tools` to apply, then `--check` passed clean.
- `selene src tools`: **0 errors, 0 warnings, 0 parse errors**.

## Concerns

- Grove-path submergence (elder/member wading, abort-vs-skip semantics) has no direct test coverage — the required 8-test list doesn't include a grove-specific submergence case, and I judged the risk/complexity tradeoff of adding one wasn't worth it given the brief's explicit test list was already satisfied and the byte-identical-baseline guarantee was verified structurally and empirically (full 763-test regression pass). If the controller's follow-up work configures a grove recipe with `submergeMax` on its species, it would be worth a smoke test at that point.
- The "no override = unchanged" and "compounding" tests both pin exact/empirical counts to a specific seed and recipe. These are consistent with the existing file's established style (other tests in the file, e.g. the grove member-count tests, do the same), but they are inherently sensitive to any future change in the LCG constants or roll-consumption order elsewhere in the file.
