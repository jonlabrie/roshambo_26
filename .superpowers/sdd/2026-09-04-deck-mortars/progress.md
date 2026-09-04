# SDD ledger — plan: docs/superpowers/plans/2026-09-04-deck-mortars.md

Spec: docs/superpowers/specs/2026-09-04-deck-mortars-design.md (read; authority for conflicts)
Branch: deck-mortars (in-tree — Rojo/Studio bind to this checkout; same reasoning as prior plans)
BASE at plan start: 709c6ca

## Preflight scan (2026-09-01)

| Pair / task | Produced vs consumed | Finding |
|---|---|---|
| T1 → T3 | PUT `/players/:id/mortar-placements` body `{placements}`, echo `{mortarPlacements}`; fireworks GET gains `mortarPlacements` vs T3 `putMortarPlacements` sending `{placements=...}` and GET passthrough | Consistent |
| T2 → T4 | `resolve(deckBounds, owned, stored?, teahouseFP?)`, `muzzleWorld(deckRow, placement, mortarId)`, `MORTAR_ORDER` vs T4's calls | Signatures match |
| T2 → T5 | `TUBE {bore,length}`, `resolve`, `MORTAR_ORDER` vs T5 render | Consistent |
| T2 ↔ T4 (shared file) | T4 Step 2 edits `MortarPlacement.luau` (adds `SHELL_MORTAR` + spec test) after T2 is reviewed | Plan handles it explicitly — T4's review covers the addition. No conflict |
| T4 → T5 | state tables gain `mortarPlacements`, `mortars` beside `deckDecorations` vs T5 reading them | Consistent |
| T4 → T6 | `SetMortarPlacement` remote payload `{mortarId, offset={x,z}, facing}` vs T6 FireServer call | Consistent |
| T5 → T6 | `MortarId` attribute on tagged Models vs T6 lookup | Consistent |
| T1 internal | Test expectations vs validator code (`{ok:true}` exact equal; unknown id via MORTAR_NOT_OWNED) | Agrees |
| T2 internal | Spec math checked by hand: L muzzle y = 50+0.5+2.5; yaw rows `p'=R*p` gives (100,·,−22) | Agrees |
| T3 internal | Mirror-the-existing-PUT contract; report must state whether GET passthrough needed a change | Agrees |
| T4 internal | Contract leaves "how server learns gear-required" as an explicitly delegated choice, stated in report | By design, not a TBD |
| T5 internal | Cylinder axis note (Size length on X + axis fix OR copy tsukubai idiom) | Agrees — implementer copies house idiom |
| T6 internal | Move/rotate only, no remove, cap ignores mortars | Agrees |

Scan clean — no rulings needed before execution.

## Model plan

Implementers: sonnet (all tasks — T1 multi-file TS idiom-matching; T2 pure-module math; T3-T6 integration in large runtime files). Reviewers: sonnet. Final whole-branch review: fable.

## Task log

- Task 1 dispatched (sonnet), BASE 709c6ca. Brief task-1-brief.md, report task-1-report.md.
- Task 1 implemented: bc82000, 481/481 green. Review: Approved with 2 Important (validator lacks unknown-key rejection + offset bound vs siblings; both inherited from the plan snippet) + 1 Minor (MORTAR_FACINGS duplicates PLACEMENT_FACINGS).
- Ruling: fix all three — spec says the route "mirrors the decorations route", so validation parity beats the plan's verbatim snippet — cost if wrong: slightly stricter validator than plan text. Fix round 1 resumes implementer.
- Task 1 fix round 1: 1468c8a, 483/483. Re-review: all findings ADDRESSED, no new breakage.
- Task 1: complete (bc82000 + 1468c8a).
- Task 2 dispatched (sonnet), BASE 1468c8a. Brief task-2-brief.md, report task-2-report.md.
- Task 2 implemented: 9fcf650, 1638 Lune tests green, lint clean. DONE_WITH_CONCERNS: nudge x-walk clamps to RAW deck bounds, not the 0.5-inset placement clamp.
- Ruling: accept raw-bounds escape — the plan's own nudge test (teahouse spanning full deck width) is unsatisfiable under the inset clamp, and "mortars never hide" is the owner ruling; the inset is cosmetic. Cost if wrong: a tube sits 0.5 studs closer to the deck edge in the pathological full-width-teahouse case. Reviewer asked to sanity-check.
- Task 2 review: Approved, 0 fixes. Ruling confirmed coherent (nudge scoping doesn't loosen non-nudge clamps; walk terminates unconditionally). Minor parked for final review: math.clamp throws on sub-1-stud decks (no realistic trigger); a rescued mortar's x can sit at raw minX/maxX — downstream tasks aware.
- Task 2: complete (9fcf650).
- Task 3 dispatched (sonnet), BASE 9fcf650. Brief task-3-brief.md, report task-3-report.md.
- Task 3 implemented: ce13ee0, 1640 Lune green, lint clean. getFireworks passthrough confirmed no-change (returns decoded body as-is). Review dispatched (sonnet).
- Task 3 review: Approved, 0 fixes. Minor parked: no passthrough regression test on getFireworks (cheap insurance, final review may weigh).
- Task 3: complete (ce13ee0).
- Task 4 dispatched (sonnet), BASE ce13ee0. Brief task-4-brief.md, report task-4-report.md.
- Task 4 implemented: edadd85, 1641 Lune green, lint clean. DONE_WITH_CONCERNS: (a) TreatmentApplier doesn't yet consume mortarPlacements/mortars — carry pointer into Task 5 dispatch (its consumption job); (b) SHELL_MORTAR hand-mirrors TS REQUIREMENTS with no fixture enforcement — parked for final review + T7 wiki promotion-pipeline note (promotion now touches 3 places); (c) no join-time echoEconomy refresh — brief-scoped, accepted. Review dispatched (sonnet).
- Task 4 review: Approved, 0 fix rounds. All 7 deckDecorations-carrying state tables extended; deckRowFor extraction closes the deck-row drift hazard. Minors: (i) LOAD-BEARING — muzzleOriginFor resolves with teahouseFP=nil (brief's literal wording) while T5's render passes the footprint → launch origin can diverge from the rendered tube in nudge cases. Ruling: muzzle must track the rendered tube; T5 implementer reports how the client derives the footprint, then a small alignment fix lands (vehicle TBD after T5). (ii) pre-spend pos snapshot race — matches existing convention, accepted. (iii) or-accumulation style nit — final review may sweep.
- Task 4: complete (edadd85).
- Task 5 dispatched (sonnet), BASE edadd85. Brief task-5-brief.md, report task-5-report.md.
- Task 5 first attempt: 2af1710 — client-side render pass in DecorationController. Report reveals the plan premise was WRONG: decorations are server-built by TreatmentApplier._buildDecorations (replicating to all clients); DecorationController only attaches prompts. Client-side mortars render owner-only (EconomyState/FireworkState are FireClient single-target) — violates spec §3 "Every player's mortars are visible to every visitor" and "same machinery that draws decorations".
- Ruling (spec beats plan): rework to server-side build in TreatmentApplier:apply beside _buildDecorations, consuming treatment.mortars/mortarPlacements (already carried by Task 4's tables). Same in-memory teahouseFP _buildBuilding computes → visitor visibility AND visual/nudge correctness by construction. Fold in the muzzle alignment (muzzleOriginFor computes teahouseFP with the same pure math from the same state) — this was the pending T4 alignment fix; same fix round is the vehicle. Keep the "Mortar" tag ruling (distinct tag avoids dead decoration prompts — accepted). pushFireworkState must trigger a pad rebuild when mortar fields change (they arrive only via fireworks GET). Cost if wrong: server builds ~3 small anchored parts per claimed pad — negligible. Fix round 1 resumes implementer.
- Task 5 fix round 1: 50529c6 — server-side _buildMortars, byte-identical client revert, pure BuildingPlacer.resolveFit shared by _buildBuilding and muzzleOriginFor's teahouseFootprintFor (muzzle alignment DONE — closes the T4 load-bearing minor), SetMortarPlacement rebuilds, pushFireworkState fingerprint-guarded rebuild, comment fixed. 1645 Lune green (4 new resolveFit tests), lint clean. Implementer concerns: mortars gated on treatment.lit like decorations (accepted — spec says "like decorations"); pre-existing deckRowFor vs resolveBuilt deck-size discrepancy parked for final review; geometry constants inline per Nobori precedent (accepted). Re-review dispatched (sonnet — rework-sized diff).
- Task 5 re-review: all 5 findings ADDRESSED, no new breakage. resolveFit behavior-preserving; lit-gate identical to decorations; fingerprint no-re-entrancy verified. Parked for final review: padOccupancyPreview's TreatmentApplier.new lacks mortarPlacement dep (harmless — synthetic treatment never sets mortars; pre-existing idiom); deckRowFor vs resolveBuilt deck-size discrepancy (pre-existing, affects mortar deck-bounds clamp).
- Task 5: complete (2af1710 + 50529c6).
- Task 6 dispatched (sonnet), BASE 50529c6. Brief task-6-brief.md, report task-6-report.md.
- Task 6 implemented: 33b383b, 1646 Lune green, lint clean. Real editor flow = DecorationController + MoveController (BackDoorController is unrelated back-door-bay UI — same plan/reality mismatch as T5). Cap naturally excludes mortars (counts state.deckDecorations). Review dispatched (sonnet) with named-risk checks: cap claim, drag-mapping reuse, no removal affordance via other prompt pipelines.
- Task 6 review: Approved, 0 fixes. All named risks verified directly (cap exclusion, byte-identical drag math reuse, structural Remove-prompt omission, FOOTPRINT derived from server's own PLACEMENT_HALF). Minor parked: enterMortar silent no-op on missing part instance (matches house guard style).
- Task 6: complete (33b383b).
- All tasks 1-6 complete. Final whole-branch review dispatched (fable), range 709c6ca..33b383b.
- Final review verdict: With fixes. Critical #1: mortarRenderedFingerprint never cleared on PlayerRemoving → rejoin to same live server skips the tube-drawing rebuild (invisible mortars, mid-air muzzle); Studio Play can't catch it — owner gate must include a same-server rejoin. Important #2: muzzleOriginFor uses deckRowFor (e.maxDeckSize, raw row lookup) while render uses resolveBuilt/DeckPlacement.resolve → wrong row+bounds when deck display-shrunk or pad-capped, and internally inconsistent with its own teahouseFootprintFor; fix = use deckCFForUid via forward declaration. Important #3: SHELL_MORTAR fixture enforcement (house "drift fails CI" rule). Minors #4-7 parked/confirmed.
- Ruling: ONE fix dispatch bundles #1+#2+#3 (all pre-deploy; #3 is cheap and the repo's standing rule). deckSiteFor's own row choice NOT touched (radius tolerance makes it benign; changing site validation risks regressions — reviewer's optional rec declined). #4 passthrough test parked as nice-to-have.
- Final fix round: 31dcd6f — rejoin fingerprint cleanup + record-on-actual-rebuild, muzzle via deckCFForUid forward decl, SHELL_MORTAR fixture gate in both suites. Lune 1649 green (+4), Vitest 486 green (+3), lint + tsc clean. Scoped re-review dispatched (sonnet).
- Owner-gate addendum for Task 7 (from final review): the Play gate MUST include a same-server rejoin (leave and re-enter the running instance) — fresh Studio Play sessions structurally cannot surface the fingerprint bug class.
- Final fix re-review: all 3 ADDRESSED, no new breakage. Forward-decl safe (assigned before any event callback can fire); first-arrival rebuild preserved; fixture additive text-only, both gates assert real source objects.
- Controller verification on final tree (2026-09-01): Lune 1649/1649, stylua clean, selene 0/0/0, Vitest 486/486. Branch 709c6ca..31dcd6f = 9 commits, tree clean except owner's uguisu .blend + .superpowers/sdd/.gitignore (both pre-existing, untouched).
- Task 7 progress (2026-09-01): owner said "merge it" → fast-forward merge to main (31dcd6f), branch deleted, pushed (f817607..31dcd6f). start-deployment fired on roshambo_server_dev (op 53c76034aca34d3c869c47e10f060312). Wiki committed+pushed f43a6f2 (log ship entry, fireworks.md as-built, proving-range spec §5 fifth-step amendment). Deployment SUCCEEDED (confirmed); CI green on the merge push (roblox-ci + server-ci both success). Remaining: Rojo reconnect (new SetMortarPlacement remote), owner Play gate incl. same-server rejoin.
- Task 7 GATE (2026-09-04, owner in Play): six finds, all fixed same-day on main (9d3cd3c front=MINZ + PivotTo; 7d3dece true-bore + CSG hollow; d510c69 boot-race task.spawn; 59a1968 prompt-binding attr race; 9aa660a firecracker hand origin). Gate PASSED: defaults, kiku S-muzzle, move-persist across Plays, hand firecracker, no phantoms. Rejoin: DEFERRED to published-place verification (solo Studio cannot rejoin). Wiki: log entries + fireworks.md amended + parked-defects (i) tsukubai, (j) proving bores, (k) bootstrap race (b2074b9). PLAN COMPLETE.
- Next thread (owner direction): rail-mounts spec — tubes clamp to the engawa front rail aimed out over the canyon; launch heading follows the visible tilt.
- Tasks 1-6 COMPLETE + final review CLEAN. Remaining: Task 7 (owner-in-loop, main session): merge to main (owner's call by house precedent) → push → aws apprunner start-deployment (autoDeploy OFF) → Rojo reconnect (new SetMortarPlacement project.json entry) → owner Play gate (plan Step 3 + same-server rejoin addendum) → wiki (fireworks.md as-built, log.md ship entry, SHELL_MORTAR promotion-pipeline note in proving-range spec §5 correction block — now covers the fixture too).
