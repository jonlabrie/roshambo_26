# SDD ledger — plan: docs/superpowers/plans/2026-09-04-rail-mounts.md

PLAN COMPLETE + GATED (2026-09-05). Merged 8e1a61b; gate fixes 27b410d (RequestSync pull),
862568c (3s rescan heartbeat — convergence ends the 5-belt prompt saga), 864c880 (ballistic
apex), 07ab0fa (comet rides the heading — the trail-unfold root cause), dcdffed (DEFAULT_MOUNT
= rail, legacy fall-through guarded). Owner verdicts: persistence pass, snap band fine as-is,
rail is the default. Elevations stand 25/12. Rejoin verification still pending published place.
Wiki updated abe4771.

Spec: docs/superpowers/specs/2026-09-04-rail-mounts-design.md (read; authority for conflicts)
Branch: rail-mounts (in-tree — Rojo/Studio bind to this checkout, house precedent)
BASE at plan start: 7fd8cee

## Preflight scan (2026-09-04)

| Pair / task | Produced vs consumed | Finding |
|---|---|---|
| T1 ↔ T4 | Handler writes `{offset, mount, aim}` (no facing); validator makes facing OPTIONAL, mount/aim optional-but-validated | Consistent — validator serves legacy DB records AND new writes |
| T2 → T3 | `Resolved {mount,x,z,aim}`, `axisLocal`, `pose`, `BASE_OFFSET`, `RAIL` vs render contract | Consistent; T3 must state its construction agrees with `pose` (explicit delegation) |
| T2 → T4 | `launch(deckRow, resolved, mortarId) → (ox,oy,oz,hx,hy,hz)` vs muzzleOriginFor use; muzzleWorld DELETED, sole caller updated in T4 | Consistent |
| T4 → T5 | `heading {x,y,z}?` send vs read; nil = vertical | Consistent |
| T2/T4 → T6 | `AIMS`/`axisLocal`/`RAIL` + payload `{mortarId, mount, offset, aim}` vs FireServer | Consistent |
| T1 internal | Tests vs code: mount/aim enums, unknown-key rejection retained, legacy facing accepted | Agrees |
| T2 internal | Hand-checked: rail z = minZ+0.225; newelMargin clamp maxX−0.95; launch oy = 50+2.75+run·cos25; yaw test oz = −22 exact (tight form), hx = −sin12 | Agrees. Plan offers coarse-band OR tight assert for the yaw test with a stated preference — RULING: use the tight form (`math.abs(oz - (-22)) < 1e-9`) |
| T3 internal | Floor base stays flat, only tube leans; rail clamp block 0.35 = BASE_OFFSET.rail; no yields (boot-race rule) | Agrees |
| T4 internal | mount/aim REQUIRED in new payload; heading nil for non-gear/public | Agrees |
| T5 internal | rng draw ORDER preserved (x-jitter, height-jitter, z-jitter — current arg-eval order); formulas reduce to current code when dir=(0,1,0) | Agrees — implementer must draw in current order and state it |
| T6 internal | RAIL_SNAP_BAND 1.25; Mount/Aim attribute seed may land in T3's file (plan anticipates, T6 commit includes TreatmentApplier if so) | Agrees |

Scan clean except the one pre-recorded ruling (tight assert). No plan-vs-spec conflicts.

## Model plan

Implementers: T1 haiku (single-file, complete code in brief); T2-T6 sonnet. Reviewers: sonnet (T1 re-review haiku if trivial). Final whole-branch review: fable.

## Task log

- Task 1 dispatched (haiku), BASE 7fd8cee. Implemented: 24c6da9, 489/489 green (RED→GREEN evidenced). Review dispatched (sonnet) — asked to check the invalid-facing-when-present case survived the optionality change.
- Task 1 review: Approved, 0 fixes. Invalid-facing regression test intact. Minors parked for final review: no all-three-fields-present test; no wrong-TYPE mount/aim test (code handles both by inspection).
- Task 1: complete (24c6da9).
- Task 2 dispatched (sonnet), BASE 24c6da9. Ruling carried: yaw test uses the TIGHT assert form.
- Task 2 implemented: 926fd2c, 1652 Lune green, lint clean. Expected mid-branch break: main.server.luau/TreatmentApplier still call deleted muzzleWorld until T3/T4 (don't Play on this commit). Review dispatched (sonnet) with hand-check directives.
- Task 2 review: Approved, 0 fixes. Unit-axis formula verified algebraically; identity + yaw launch cases hand-computed; tight assert honored; floor path byte-identical; muzzleWorld cleanly gone. Minors parked: narrowing-assert comment nit; pose param `_mortarId` naming.
- Task 2: complete (926fd2c).
- Task 3 dispatched (sonnet), BASE 926fd2c.
- Task 3 implemented: 01b67ae, 1652 Lune green, lint clean, no concerns. Review dispatched (sonnet) — named risks: tilt-vs-axisLocal agreement (yaw stability, handedness), PivotOffset correctness under tilt, rail mount-point composition matching pose's capTop.
- Task 3 review: Approved, 0 fixes. Both named risks hand-verified (fromMatrix basis right-handed + yaw-stable; PivotOffset reads the tilted frame → identity pivot; BASE_OFFSET measured ALONG the axis, matching launch's run — the geometrically correct reading). Minor parked: `mp: any` param typing (matches file's DI convention).
- Task 3: complete (01b67ae).
- Task 4 dispatched (sonnet), BASE 01b67ae.
- Task 4 implemented: 4eb766f, 1652 Lune green, lint clean. Addition beyond contract (judged sound, review to confirm): fingerprint hashes mount,aim instead of dead facing. Review dispatched (sonnet) — named risks: two-fallback split (hand vs overhead) survives the 2-return change; fingerprint format parity between pre-seed and checker.
- Task 4 review: Approved, 0 fixes. Both named risks verified (heading nil in both fallback branches; single mortarFingerprint function shared by checker + pre-seed — drift impossible by construction). Fingerprint addition judged correct AND necessary. Minors parked: no typeof-string guard on mount/aim (harmless, matches old facing style); StoredPlacement type keeps `facing: string?` (correct for legacy DB records but could use a "legacy, read-only" comment).
- Task 4: complete (4eb766f).
- Task 5 dispatched (sonnet), BASE 4eb766f.
- Task 5 implemented: 16ccefc, 1652 Lune green, lint clean, no concerns. Review dispatched (sonnet) with three algebraic equivalence hand-checks (draw order, bonus, control) + apex-verticality sweep.
- Task 5 review: Approved, 0 fixes. All three equivalences EXACT (scatter has zero Y — no fuzz); draw order verified; verticality sweep clean. Minor parked: comment hedges "within scatter" where the vertical case is exact.
- Task 5: complete (16ccefc).
- Task 6 dispatched (sonnet), BASE 16ccefc.
- Task 6 implemented: 2245335, 1652 Lune green, lint clean. DONE_WITH_CONCERNS: ghost base/clamp block doesn't morph mid-drag (barrel retilts + model elevates only) — ruled acceptable-cosmetic, owner gate judges readability. MoveController-only diff (T3 already seeded Mount/Aim attrs). Review dispatched (sonnet) — named risks: shared-flow isolation, rail-band coordinate space (world vs deck-local), rail offset shape.
- Task 6 fix round 1: 6ed3d62 — guard catches falsy + both comments. Re-review (haiku): both ADDRESSED, no breakage.
- Task 6: complete (2245335 + 6ed3d62).
- All tasks 1-6 complete. Final whole-branch review dispatched (fable), range 7fd8cee..6ed3d62.
- Final review verdict: READY TO MERGE with 1 Important on an unexercised path — the spec's "rail-by-default one-line lever" doesn't exist (rail branch asserts on nil override; no rail default-stagger). Ruling: IMPLEMENT the rail default path (spec §2 describes it; T7 hands the owner the lever, so it must work) — default t from the existing stagger, aim C; default mount stays floor. Minor for T7 gate script: floor default z (minZ+1) sits INSIDE the 1.25 snap band — a pick-up-and-drop-in-place of a default mortar converts it to rail; judge deliberately at the gate. Strengths: pose-sharing architecturally sound, L/R sign verified end-to-end, nil-heading BIT-identical, rail constants verified vs PadOps, legacy handling consistent at every layer, fingerprint nil-interpolation safe. Test-gap minors parked (R-component check, wrong-type validator case).
- Final fix round dispatched: resume T2 implementer (owns the module).
- Final fix round: 8e1a61b — railDefault path (defaultX stagger, newel clamp, aim C), DEFAULT_MOUNT lever constant, assert gone, failing-first test. Re-review: ADDRESSED on all 4 parts; lever-flip check SAFE across every consumer; floor path provably identical; stale muzzleWorld concern confirmed stale.
- Controller verification on final tree (2026-09-05): Lune 1653/1653, stylua clean, selene 0/0/0, Vitest 489/489. Branch 7fd8cee..8e1a61b = 8 commits.
- Tasks 1-6 COMPLETE + final review CLEAN (verdict: ready to merge). Remaining: Task 7 (owner-in-loop): merge decision → push → backend deploy (validator MUST be live before Studio writes mount/aim records; autoDeploy OFF) → owner gate (leaning tubes, rail drop + snap feel incl. default-z-inside-band judgment, L/C/R arcs, ELEVATION live-tuning, floor-tube lean, firecracker/public unchanged, persistence, DEFAULT_MOUNT lever decision) → wiki.
- Task 6 review: Approved w/ 1 Important — `and`-short-circuit guard in retiltMortarGhost yields `false`, nil-check misses it (latent throw). All 3 named risks cleared (coordinate space consistent; shared flows untouched by trace; rail offset[2] inert). Ghost-morph concern confirmed genuinely cosmetic. Fix round 1 resumes implementer (guard fix + optional comment on redundant PivotTo).
