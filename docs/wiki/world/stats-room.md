---
shelf: world
updated: 2026-08-16
---

# Stats Room (番付) — the cavern

The excavated hall behind [[hanabiya]]'s neighbour, the Stats false front. Bored
2026-08-16 and saved to the place. What goes ON its walls is specced separately
(`docs/superpowers/specs/2026-08-16-stats-room-design.md`); this page is the rock.

## As-built

Terrain is **place-only** — git cannot see it. `roblox/tools/studio/boreStatsCavern.luau`
records the surveyed geometry and re-measures the as-built; it defaults to
`MODE = "VERIFY"` and writes nothing.

| | |
|---|---|
| Chamber | x[−58.0, −18.0] · 40 wide × 25 deep, entered from the north at ~x −28 |
| Floor | **114.00**, flat (interior range 113.16–114.00) against the shop sill at 113.30 |
| Ceiling | **134.00** — ~19 studs clear |
| Rock cover | 17.9 studs at the thinnest over the interior |
| Tunnel | 8-stud bore (≈6–7 net), floor 113.12–114.00, min clear **7.67** |
| Breaches to sky | none |

The tunnel roof is pinned to the **top of the rear-door lintel (120.60)** at the mouth so
it meets the doorway without a step, then ramps 0.85/stud to 124.3 once there is rock
overhead. The chamber ceiling opens ~5 studs above the tunnel, so the hall reveals itself
on arrival.

## The berm — why the hillside was raised

There was **no rock to bore through**. Natural grade behind the rear doorway topped out at
**120.29** — the door head (120.10) exactly — so the first ~8 studs of tunnel would have
been an open trench. The hillside behind the shop was raised to 125.0 at z ≤ 44.3, climbing
0.96/stud to 129.5 where it meets the natural slope.

That berm is threaded under a hard ceiling: **`RoofSouth`'s lowest corner sits at 127.20**,
and terrain must stay clear of it. Note that corner is at 127.20, not the 129.3 a naive
`Position.Y − Size.Y/2` reports — the part is rotated, and the 2.1-stud error would have
driven the berm through the roof. Clearance as saved: **+2.45** (the owner hand-shaped the
mouth further after the bore).

## Owner gates

- **2026-08-16** — bore accepted ("Tunnel looks good"), place saved.
- **2026-08-16** — room doubled: the west wall pushed −38 → −58 on the owner's call.
  Finished floor area ≈ 2.15× the original.
- **2026-08-16** — ceiling raised 129 → **135 carve / 134 as-built** ("raise the ceiling to
  135"). Held flat wherever the rock allowed, under a rule that the ceiling never comes
  closer than 11 studs to the hillside; only the thin north-east entry corner steps down.

The chamber is the bounding box of four owner-dragged corner markers, not their irregular
quad — the stated default, and the owner did not ask for the quad. Markers survive at
`Workspace.PathDraft.StatsCavern` (tagged `DevMarker`, hidden in Play).

## Raw layer

`roblox/tools/studio/boreStatsCavern.luau`, `roblox/tools/studio/draftStatsCavern.luau`,
`docs/superpowers/specs/2026-08-16-stats-room-design.md`, [[misc-engine-traps]] (bore
technique), [[place-state]].
