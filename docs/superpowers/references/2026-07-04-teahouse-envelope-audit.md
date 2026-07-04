# Teahouse Expansion-Envelope Audit — 2026-07-04 snapshot

Run of `roblox/tools/studio/auditTeahouseEnvelopes.luau` (read-only) against the live place,
for the meta-game spec's pad-class question (which cliff perches can take which structural tiers).
**Re-run after any terrain or path/railing work near the perches** — this is a snapshot, not a fact.

Method: 4-stud oriented slab march from each teahouse bbox face (front = veranda facing), in a
12-stud band above true deck level; blocked at >2% terrain occupancy or any anchored foreign part.
`front 40` means ≥40 (probe cap). Stilt drop raycast at the outer edge of a hypothetical +16 front
extension. Provisional gates: T2 front≥10, T3 front≥18 (drop≤60 else cantilever-only), story up≥14,
wing side≥12.

| site | front | left | right | up | T2 | T3 | story | wing | stopped by |
|---|---|---|---|---|---|---|---|---|---|
| TeahousePrototype | 40 | 0 | 32 | 24 | Y | Y (stilts 41) | Y | R | L:rock |
| Teahouse_01 | 40 | 4 | 0 | 24 | Y | Y (stilts 36) | Y | – | L/R:rock |
| Teahouse_02 | 40 | 8 | 4 | 24 | Y | Y (stilts 22) | Y | – | R:NW2040Path |
| Teahouse_03 | 0 | 40 | 0 | 12 | – | – | – | L | F:Teahouse3Stair, U:Teahouse_04 |
| Teahouse_04 | 40 | 0 | 0 | 24 | Y | Y (stilts 42) | Y | – | L/R:rock |
| Teahouse_05 | 4 | 0 | 4 | 0 | – | – | – | – | F:Rail_NW40Descent, L/R/U:rock |
| Teahouse_06 | 40 | 4 | 0 | 24 | Y | Y (stilts 23) | Y | – | L:Rail_NW80FallsStair |
| Teahouse_07 | 40 | 12 | 4 | 24 | Y | Y (stilts 10) | Y | L | L:NW80FallsStair |
| Teahouse_08 | 40 | 4 | 0 | 0 | Y | Y (stilts 22) | – | – | U:rock |
| Teahouse_09 | 40 | 0 | 0 | 4 | Y | Y (stilts 34) | – | – | U:FarWall_71 |
| Teahouse_10 | 40 | 0 | 4 | 4 | Y | Y (stilts 33) | – | – | L:rock(69%), U:rock |
| Teahouse_11 | 40 | 0 | 12 | 8 | Y | Y (stilts 20) | – | R | U:FarWall_62 |
| Teahouse_12 | 40 | 8 | 12 | 24 | Y | Y (stilts 15) | Y | R | L:rock |
| Teahouse_13 | 40 | 0 | 0 | 24 | Y | Y (stilts 24) | Y | – | L/R:rock |

## Reading

- **T2 + T3 (front stage / moon deck): 12/14.** Front is ≥40 studs of open air everywhere except
  03 and 05 — verandas face the gorge, so outward growth is essentially free. Max stilt drop seen
  is 42 studs: every T3 is buildable on real stilts, no cantilever-only site exists at current gates.
- **Second story: 8/14** (Proto, 01, 02, 04, 06, 07, 12, 13). Far-wall row 08–11 sits under
  overhangs/upper paths; 03 sits under Teahouse_04; 05 under rock.
- **Wings are scarce (5/14)** — lateral growth hits canyon wall almost everywhere. Cliff-perch
  luxury is outward and (sometimes) upward, confirming the air-vocabulary design.
- **Conservative grades:** several stoppers are our own movable structures, not geology —
  03's front is its own access stair (model `Teahouse3Stair`), 05's front is a railing run 4 studs
  out (`Rail_NW40Descent`), 06/07's left is the NW80 falls stair, 02's right is NW2040Path.
  True hard-blocked sites: only **05** (rock on 3 sides + railing in front) and partially **03**
  (04 stacked above it).
- **Site classes suggested:** 05 = "alcove" class (base tier only, priced/marketed as the snug
  hermit hut); 03 = left-wing-only; 08–11 = single-story stage class; the rest = full ladder.
