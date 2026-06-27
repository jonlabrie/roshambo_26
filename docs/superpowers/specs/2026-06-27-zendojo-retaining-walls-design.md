# ZenDojo Path Retaining Walls — Fitted Ishigaki (Design)

Status: design, awaiting user review (2026-06-27).

Related: `docs/superpowers/specs/2026-06-26-zendojo-organic-path-system.md` (original ishigaki recipe),
`docs/superpowers/specs/2026-06-27-zendojo-fw11-fw10-descent-design.md`; memory
`zendojo-fw11-switchback-deck`, `zendojo-organic-cobble-path`.

## Purpose

Add dry-stone (ishigaki) retaining walls to the canyon path system where the built-up downhill edge floats
above natural grade. An earlier prototype using the original recipe read too gappy — like scattered pebbles
rather than a fitted dry-stone face. This spec retunes the recipe for a **tight fitted look** and applies it
**selectively** to the stretches that actually need support.

## Scope (from the float survey, 2026-06-27)

Walls go **only on contiguous spans where the downhill edge floats > ~2.5 studs**, tapering to zero at each
span's ends. Surveyed need:

| Path (timber prefix) | timbers | max float | spans needing wall (>2.5) |
|---|---|---|---|
| `PathSteps` upper run (`Timber_*`) | 48 | ~4.0 | ~12 |
| `PathExtension` (`ExtTimber_*`) | 5 | ~4.5 | ~1 |
| `DescentPath` (`DescTimber_*`) | 19 | ~3.4 | ~1 |

Walls are short (2.5–4.5 studs). Most are on the upper run; the extension and descent hug grade (user
marker-shaping), so they need little. **Continuous walls and the tall-everywhere assumption are out** —
stone appears only where structurally needed, bare ground elsewhere.

## §1 — The fitted-stone fix (core change vs the prototype)

Same Voronoi-on-battered-face machinery, retuned so cells read as a tight dry-stone face:

| Param | Prototype (gappy) | This design |
|---|---|---|
| Inset (grout) | 0.12 | **≈ 0.03** (cells meet edge-to-edge, hairline joints) |
| Dome (face relief) | 0.35 | **≈ 0.15** (low relief, flatter faces) |
| Min-sep / size var | 0.7 | **0.7, ×0.6–1.4** (big + small stones interlock) |
| Chaikin | 1 pass | 1 pass (keep) |
| Normals | center − out·0.75 | same (smooth) |
| Colour / material | 116/121/111 ±6, Rock | same |

The inset was the main culprit (it opened a gap around every stone); near-zero inset + low dome is what
turns scattered pebbles into fitted dry-stack. **Validated on one prototype span before batching.**

## §2 — Wall geometry & placement

- **Edge:** the **downhill side** of each floating span (per-timber, whichever cross-edge drops away).
- **Battered face:** top edge at the **bed edge (±3.2** from path centerline); base flared **out to ±3.7 and
  down to terrain raycast − 0.4**; wall **top = timber grade − 0.2**, interpolated along the span (analytic —
  never raycast a Box-collision mesh for height); back-extruded ~0.6 for solidity.
- **Taper:** wall height eases to ~0 at each span's first/last timber, so it emerges from and sinks back into
  the slope (no abrupt stone ends).
- Heights are 2.5–4.5 studs; the face follows the path's curve (per-span local frame, like the cobbles).

## §3 — Build units & where it lives

- **SpanFinder** — walk a path's timbers in order, mark each as floating (downhill-edge float > 2.5) or not,
  group contiguous floating timbers into spans, and record the downhill side per span. Input: model name +
  timber prefix + half-width 3.2. Output: list of spans (ordered timber subsets + downhill sign).
- **IshigakiFace** — per span, build the battered tight-fit Voronoi face as ONE EditableMesh (§1 params,
  §2 geometry, tapered ends), **publish** via `CreateAssetAsync`, place as a MeshPart. Input: a span.
- **Build flow:** build **one prototype span** (a representative upper-run stretch) → user visual approval
  (tune inset/dome/relief as needed) → then batch the remaining spans with the approved params.
- **Lives** in `Workspace.RetainingWalls` (a Model), published meshes, **ad-hoc** — consistent with the path
  system (`PathSteps`/`PathMesh`/`PathExtension`/`DescentPath` are all ad-hoc, not in the Rojo pipeline).
  Published asset IDs recorded here as-built. Persists via the saved place + published assets.

## Units (independently buildable/testable)

- **SpanFinder** (Studio query) — deterministic given the timbers; output inspectable.
- **IshigakiFace** (Studio mesh build + publish) — one span at a time; visually reviewed.

## Out of scope

- The **river bridge(s)** at FW10/Bridge3 and other `Bridge*` markers.
- **Capstones / coping** on the wall tops, planting in the joints — possible later polish, not this pass.
- Pipelining the walls (or the paths) into Rojo — intentionally ad-hoc, matching the existing paths.

## Open questions

- Exact float threshold (2.5 assumed) and minimum span length — confirm against the prototype.
- Whether marginal (~2–2.5) spans adjacent to a walled span should be joined in for continuity — decide when
  the spans are listed.
