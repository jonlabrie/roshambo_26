# Suspension Bridge (Kazurabashi) — Design

**Status:** approved 2026-07-09
**Goal:** Build the valley's architectural setpiece — a ~112-stud vine/rope kazurabashi footbridge
spanning the two abutment piers across the Far-Wall canyon, high above the river. Walkable, atmospheric,
gently swaying, and a fireworks-viewing standing spot.

## Context

- **Span:** Abutment_A → Abutment_B is **112.1 studs, dead level** (height diff 0.12), running roughly
  N–S along +Z→−Z with a slight X drift.
- **Abutments** (place-only, `Sandbox/TempBridgeAbutments`): pier blocks 11×9×8 with 13×1.5×9.5 caps.
  Cap tops (deck seat): **A_Cap top ≈ (−248.00, 218.43, 55.71)**, **B_Cap top ≈ (−243.82, 218.31, −56.29)**.
- **Below:** midspan sits ~39 studs above the river; **water surface at Y ≈ 174.8**.
- **Palette (match `buildBridge.luau` / decks):** TIMBER 107/79/51, CAP_DARK 30/26/20, STONE 96/94/88.
  New: **VINE (rope) ≈ 105/86/55** (hemp-brown), LASHING ≈ 120/100/66 (lighter wrap).
- Existing `buildBridge.luau` builds the small arched taiko-bashi (Bridge3) — a *different* structure; this
  is a much larger suspension span. Both parent under `CanyonWorld/Structures/Bridges`.

## Form

- **Deck centreline (catenary):** parabolic sag. For arc parameter `t ∈ [0,1]` from A to B:
  `y(t) = lerp(seatA, seatB, t) − SAG·4·t·(1−t)`, **SAG = 8** → midspan deck ≈ Y 210.4 (~36 studs over water).
  XZ centreline = straight lerp A_Cap→B_Cap.
- **Deck width = 6 studs** (edge cables at ±3 from centreline). Comfortable two-abreast + viewing spot; fits
  the 9.5-wide caps.
- The deck runs cap-to-cap; the first/last slats seat flush on the cap tops so the path network connects at
  the abutments.

## Components

All geometry parents under `CanyonWorld/Structures/Bridges/SuspensionBridge`. The **visible** rope/slat
geometry is grouped into **N span segments** (≈10 Models, `Seg_1..Seg_N`, each with a `WorldPivot` at its
centre) so the sway controller can pivot ~10 bones instead of animating hundreds of parts. The **collision
floor and fall barriers are NOT inside the sway segments** — they are static children of the root.

1. **Deck-edge main cables (2)** — the load-bearing vine bundles, dia ~0.5, following the deck catenary at
   ±3 cross. Built as short cylinder segments (~1.5 studs) chained along the curve, VINE colour.
2. **Hand-rail cables (2)** — a parallel catenary at **+2.9** above each deck-edge cable (matches the bamboo
   rail top height), dia ~0.36.
3. **Vertical suspenders** — every **~4 studs** of arc, each side: a rope upright (dia ~0.14) from hand cable
   down to deck-edge cable.
4. **Woven side lattice** — one diagonal rope (dia ~0.1) per suspender bay, alternating lean, filling each
   side panel between hand rope and deck (the kazurabashi weave). Density: one diagonal per bay (X-weave
   optional if too sparse).
5. **Deck slats** — timber cross-pieces spanning the width (~6.4 long to lap the cables), size
   `(6.4, 0.28, 0.55)`, **pitch ~1.05 (slat 0.55 + gap ~0.5)** → ~106 slats, each seated on the deck
   catenary and yaw-aligned to local travel. Per-slat tint ±8 on TIMBER. See-through gaps to the river.
6. **Invisible collision floor** — thin CanCollide slabs (~2-stud segments, 6 wide, 0.4 thick), Transparency 1,
   following the deck catenary flush under the slats (top ≈ slat top). Continuous so players never fall through
   the gaps. NOT swayed.
7. **Fall barriers** — invisible CanCollide walls (~5 tall, 0.4 thick), Transparency 1, along each edge just
   outboard of the deck, following the catenary. NOT swayed. (The rope lattice is decorative; the barrier
   stops falls.)
8. **Anchor piers** — dress the two temp abutment blocks as **stacked-stone abutments**: STONE ishigaki-style
   facing slabs on the visible faces + a TIMBER cap + CAP_DARK band; a lashed **deadman post** behind each cap
   where the four cables sweep over the cap and terminate (rope-wrap lashings, LASHING colour). Final piers
   move under `CanyonWorld/Structures/Bridges` (out of Sandbox).

## Sway (ambient, client-side, collision-stable)

- **Discovery is tag-based** (`BridgeSway`), workspace-wide and folder-agnostic — applying the
  lantern-architecture lesson (see `LanternController`) so it works under CanyonWorld. **Each `Seg_i` visible
  segment Model is tagged `BridgeSway`** by the builder; the controller drives every tagged model directly
  (`GetTagged` + `GetInstanceAddedSignal`), reading each one's normalized arc position from a `SwayPhase`
  attribute the builder stamps on it (0 at A, 1 at B) so the controller needs no span geometry.
- **Controller:** `src/client/BridgeSway.client.luau` (committed, Rojo-synced). Each frame, pivot each segment
  by a **travelling sine wave** along the span: lateral offset `A_lat·sin(φ_i − ω·t)` + vertical
  `A_vert·sin(φ_i − ω·t + θ)`, where `φ_i` is the segment's normalized arc position. **A_lat ≈ 0.3,
  A_vert ≈ 0.15, wavelength ≈ span/1.5, ω slow** (period ~6–9 s) → a gentle undulation, not a jitter.
- The pivot uses `Model:PivotTo(basePivot * swayCFrame)` from each segment's stored base pivot. Endpoints
  (segments touching the abutments) get **amplitude scaled toward 0** so the deck stays anchored at the piers.
- Collision floor + barriers are static — verified by measuring floor Y is constant while swaying.

## Build approach

- **`tools/studio/buildSuspensionBridge.luau`** (new, Studio-runnable, parts-only + catenary math, idempotent):
  reads the two abutment cap parts for endpoints, builds the segmented visible geometry + static
  floor/barriers + pier dressing under `CanyonWorld/Structures/Bridges/SuspensionBridge`. CONFIG carries the
  span params (SAG, width, slat pitch, suspender spacing, segment count, colours).
- **`src/client/BridgeSway.client.luau`** (new, committed): the tag-driven sway controller.
- Geometry is **place-only** (save the place after building); the controller is Rojo code.

## Verification

- **Walkable:** a player crosses end to end — collision floor continuous (no gaps/steps that snag), rail/barrier
  keeps them on; headroom is open (no ceiling).
- **Clearance:** midspan deck ~36 studs over the water; slats see-through but floor solid underfoot.
- **Sway:** visible segments undulate gently; measured collision-floor Y is unchanged during sway; endpoints
  do not detach from the caps.
- **Fit & finish:** slats sit just proud of the floor (no z-fight), deck meets both caps flush, piers read as
  stone abutments, cables sweep cleanly to the deadman anchors. No `.rbxl` committed; CI stylua/selene green on
  the two new files.

## Out of scope (later)

- Reactive (player-responsive) sway — ambient only for v1.
- Teahouse-7 access and other valley-layout items — tracked separately.
- Fireworks integration — the deck is a viewing spot; the fireworks system is its own work.
