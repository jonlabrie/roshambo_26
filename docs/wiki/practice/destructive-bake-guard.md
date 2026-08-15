---
shelf: practice
updated: 2026-08-15
---

# Destructive Bake Guard

Standing rule: a bake that destroys-and-rebuilds is safe only until the owner
hand-tunes; after that it must REFUSE to run — the guard lives in the tool, never in a
note or anyone's memory.

## The rule

Most of this project's Studio bakes **destroy their output folder and rebuild it**
(`bakeArrangements`, `scatterPreserve`, the moss and shore-rock passes, all under
`roblox/tools/studio/`). That is safe exactly once — before the owner hand-tunes the
result.

The owner, 2026-08-02, on the arrangements sweep: *"tuning will probably be an ad-hoc
process as I build other areas and systems (e.g. around the teahouses, which will
become curated areas) so I just need to be cautious about when and why I bake."* The
hand-work accumulates over months, interleaved with other building, and by the time a
re-bake is tempting the folder holds decisions that exist nowhere else — not in git,
not in a plan.

**Why:** a moved object returning to its computed spot is visible and gets noticed. A
DELETED one coming back is not, and deletion is usually the most deliberate judgement
in the pass ("this one does not belong here"). Silent resurrection is the failure mode.

## How to apply

- Build the guard into the TOOL, not into a note.
  `roblox/tools/studio/bakeArrangements.luau` stamps a `BakeFingerprint` attribute
  (group names + rounded pivots, so moves count as well as deletions) and `error()`s if
  what it finds is not what it last wrote. Arm it on the live folder too — a guard that
  only activates on the next bake protects nothing.
- If a guard trips: **stop and ask.** Never flip the override to make the script run.
  Baking into a FRESH folder and merging by hand is nearly always right.
- Never re-run a destructive bake without asking first, even when the owner asked for
  the outcome — they are agreeing to the result, not to losing their edits.
- Offer the fork explicitly when a pass is gated: FREEZE it (promote to a permanent
  place-only folder, tool never touches it again — usually right) or teach the tool to
  preserve edits (skip existing sites, tombstone deletions).

See [[bake-isolation]] for the sibling rule about zones, and [[friends-family-baseline]]
for current program state.
