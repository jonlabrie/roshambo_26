---
shelf: practice
updated: 2026-08-27
---

# One Model Is Not a Building

Standing rule: a Roblox structure is usually several models stacked on one footprint —
measure the composite, never one model's bounding box.

## The rule

**A named model is not the structure.** The ZenDojo bell tower is SEVEN models sharing
one footprint, stacked vertically:

```
Shoro          112.00 .. 136.20      RanmaCarvings  140.37 .. 147.63
ShoroRoof      133.55 .. 136.47      BellDrive      110.00 .. 141.60
ThrowDrum      135.23 .. 153.54      BonshoRig      116.95 .. 134.50
BonshoBell     inside BonshoRig      <- the seventh, and the one that goes missing
```

⚠ **BonshoBell was absent from this list for weeks while the sentence above said SEVEN** —
a page that could not count its own rows. It is worth adding for the reason it was dropped:
the bell hangs INSIDE the rig's span, so it moves the union not at all, and a model that
changes no answer is exactly the one an inventory forgets. Iterating it is still the rule;
"it wouldn't have mattered" is a conclusion you can only reach after looking.

⚠ **THESE NUMBERS ARE A 2026-08-13 SNAPSHOT, KEPT DELIBERATELY — do not read 153.54 as the
tower's height.** The drum's roof was pitched up and given a sōrin on 2026-08-14, and the
top has been `ArenaLayout.towerTopY` = 174.17 ever since, held by a test that rebuilds the
tower and compares. The snapshot stays because it is the evidence for the 17-stud error;
the live number is measured, not transcribed ([[derive-from-what-it-touches]]).

Measuring `Shoro` alone gave 136.5, written into `Machiya.luau` as `SHORO_TOP` — **the
middle of the building**. The drum storey stands on the shōrō's roof and carries on up
to 153.54. The error was 17 studs and it survived from the spec through the whole build
(fixed in `951c5ea`).

**Why it matters:** it ran in the direction that manufactures alarm. Every reading
looked tight ("0.14 studs of slack left"), and the owner had to ask *"do you think
these two buildings conflict with each other?"* to break it open. They don't — they are
15.9 studs apart in plan; the real clearance was 22.18 studs. **Tight readings feel
like diligence, so nobody re-checks them.**

**How to apply:**

- To measure a structure, iterate every model whose footprint overlaps it and take the
  union — never `model:GetBoundingBox()` on the one with the matching name. The
  measuring snippet is in the session that produced `951c5ea`.
- Rotation matters: use the per-axis extent (`|R·size|` summed) rather than
  `Position.Y + Size.Y/2`, or every tilted roof panel reads short. Same trap as the
  teahouse floor-vs-pivot entry on [[misc-engine-traps]].
- **Write down HOW a landmark constant was measured, beside it.** A bare
  `local SHORO_TOP = 136.5` cannot be audited; the same number with its model list can.
- When a constraint starts feeling tight, re-measure the landmark before optimising
  against it. See [[placement-discipline]] and the one-attempt rule on
  [[owner-rulings]].

## And don't launder your own thresholds as the owner's

`MIN_SHORO_GAP = 5.0` was a floor **invented here** <!-- lint-ok: narrating the invented value; the code carries the owner's 9.0 --> when the owner's holdout top was
retired as "approximate". Their stated relationship was **9 studs subordinate to the
bell tower**. The 5.0 then got quoted back to them repeatedly as though it were their
gate, framing a design decision around spending "the last stud" of it.

**How to apply:** when a gated number is retired and you replace it with a proxy, say
in the code and in the conversation that the new number is yours. Otherwise it hardens
into a constraint the owner never set and cannot recognise as negotiable. See
[[friends-family-baseline]] and [[owner-rulings]].
