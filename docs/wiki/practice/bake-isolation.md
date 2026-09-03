---
shelf: practice
updated: 2026-08-15
checked: 2026-09-03
---

# Bake Isolation

Standing rule (owner, 2026-08-01, after approved planting was silently destroyed
several times): **the owner approves RESULTS, not algorithms** — a bake aimed at one
zone must never rewrite another. Their words: *"I'm not approving algorithms, I'm
approving the results of algorithms."* And: *"If I approve a waterline bake, saying
'bake' in another context shouldn't touch the waterline OR ANY OTHER ZONE, ever."*

## The two defects that broke it (both fixed)

Two independent defects in `roblox/tools/studio/scatterPreserve.luau` allowed it:

1. **Grid origin derived from zone bounds.** `sampleTerrain` started the 4-stud grid
   at the minimum of all zone bounds, so editing ANY zone moved the origin by a
   non-multiple of the pitch and shifted every sample in the canyon — re-rolling zones
   nobody touched. Fixed by snapping the origin to a fixed world lattice (`56367a0`).
2. **`readZones` skipped un-targeted zones**, so a filtered bake planned against a
   different world than a full one and produced different trees — this is why
   "zone-filtered bakes are not isolation-safe" was true. Planning is now ALWAYS
   whole-world; the filter gates only wipe+stamp. Destructive modes REFUSE without an
   explicit target: `zones = {"Margin"}`, or `zones = {"ALL"}` to mean it (`2afde87`).

**Also:** the terrain grass paint changes the surface, which changes later plans — an
approval taken at the end of a `mode="grass"` run was invalidated by that same run.

## How to work

- **Name what a bake will change before running it.** Never treat a past "go" as
  standing permission for later bakes.
- **Always plan first.** It caught `stationBand = 2` (finer than the 4-stud sample
  grid), which would have emptied the waterline to zero plants.
- **Verify isolation empirically**, not by assertion: snapshot every plant's position,
  bake, re-compare. "10 untargeted zones byte-identical" is the evidence to report.
- `HandTuned = true` on an instance survives a bake (parked, planted around, restored).

Related: [[placement-discipline]], [[destructive-bake-guard]] (the sibling rule about
hand-tuned output), [[foliage]], [[owner-rulings]].
