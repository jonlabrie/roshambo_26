# Ring backing — report

Status: DONE, gates green (962 Luau, 211 server; stylua/selene clean).
Commit SHA: 16f1af3 (colour fix; geometry commit was 7f8b73a)

Backing: painted on the ring `TextButton` itself (not a sibling frame) — `WASHI`
(26,24,28) at BackgroundTransparency 0.3, `corner(ring, 8)`. Not IVORY_DIM/0.25 — that is the
throw buttons' disabled fill. WASHI/0.3 is what the hamburger used before Task 5 deleted it, and
what the plate/bank button/escalation prompt already use.

Disc verdict: KEPT. Disc colour and backing colour are the literal same constant (WASHI vs
WASHI), but transparency stacks: backing alone ≈ 70% opaque WASHI (0.3), disc-over-backing ≈
95.5% opaque WASHI (1 - 0.15*0.3) — a real, visible darkening for the digits/glyph ground, not
redundant.

RING_INSET = 4px (both tiers). Ring outer footprint (RING_D) unchanged.
- Desktop: backing 76px; ring segment radius 31 (was 35), ring effective diameter 68.
- Touch: backing 44px; ring segment radius 16.5 (was 20.5), ring effective diameter 36.

Disc: RING_DISC_GAP = 2px, sized from RING_R − RING_THICKNESS/2 − gap (pixel offset, not scale).
- Desktop: disc 52px diameter (was ~43px @ 0.56 scale).
- Touch: disc 26px diameter (was ~25px @ 0.56 scale).

Segment width vs arc pitch (overlap guaranteed by `RingTimer.segmentWidth`'s `ceil(...)+1`):
- Desktop: 7 vs 5.41 (was 8 vs 6.11).
- Touch: 4 vs 2.88 (was 5 vs 3.58).

Legibility: touch-tier disc grew slightly (24.64→26px) rather than shrinking, so digits
(TextSize 14) and the glyph box (0.82 of disc) remain comfortable; no RING_INSET reduction
needed.

Concerns: touch-tier disc growth is modest (~1.4px) since the 44px ring leaves little slack —
acceptable, still net growth, no legibility regression. None outside this section changed.
