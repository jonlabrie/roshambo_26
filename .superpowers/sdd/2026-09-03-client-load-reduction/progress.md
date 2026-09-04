# SDD ledger — plan: docs/superpowers/plans/2026-09-03-client-load-reduction.md

Spec: `docs/superpowers/specs/2026-09-03-client-load-reduction-design.md` (read; binding authority)
Base at start: `96257d7`, branch `main`

## Preflight

Ruling: execute on `main` rather than a worktree — the session harness explicitly
configures this session to work in place ("Edit files directly in your working
directory… Skip EnterWorktree unless the user explicitly asks"), every commit in this
repo's recent history is direct-to-main, and the prior SDD run recorded the same
ruling. Cost if wrong: commits land on main and would need reverting rather than a
branch being abandoned.

### Cross-task pairs (shared file or interface)

| Pair | Produced → consumed | Finding |
|---|---|---|
| T1 → T2,T3,T4,T5,T6 | `AmbientBudget.inRange/inView/step/DEFAULT/Config` | Consistent. `step` returns `(fire, nextAcc)` at all 15 call sites in the plan. Clean. |
| T2 ↔ T3 ↔ T4 ↔ T5 | `num()` / `cfg()` helpers | ⚠ Plan mandates copying both helpers **verbatim** into four client files. Verbatim duplication of a logic block is a defect the review rubric flags — this would be raised in four consecutive reviews. **Ruled (see below).** |
| T4 → T5 | `DriveOmega` attribute | No conflict. T4 lands first and reads the attribute Hammer already writes unconditionally; T5 later hoists that write above its own gate, which only makes T4 more correct. Ordering is safe in both directions. |
| T5 internal | timing half → rendering half | `camNet` and `driverDir` computed in the timing half, used in the rendering half; both are in scope after the hoist. Clean. |
| T6 (two files) | none shared with other tasks | Clean. |
| T7 / T9 | both `src/server`, different files (`main.server.luau` vs `TreatmentApplier.luau`) | No overlap. Clean. |
| T8 | `FlapBoard.luau`, sole caller `StatsController` | No overlap. Clean. |

### Per-task self-consistency

| Task | Tests vs code / files created vs later touched | Finding |
|---|---|---|
| T1 | Six `step` cases checked against the implementation by hand: remainder carry (0.05 vs 0.03 → 0.02), stall bound (5s → `< 1/30`), zero-interval guard reached because `elapsed < interval` is false for `interval <= 0`. | Agrees. |
| T2 | `AMP`/`SPEED` still consumed by `add` after `hangPointFor` is deleted. | Agrees. |
| T3 | Loop body preserved verbatim inside the new gate. | Agrees. |
| T4 | `spins[1].hub` is a `CFrame`, so `.Position` is valid. | Agrees. |
| T5 | Post-fix task text writes the whole loop out; hoist is explicit and diff-checked. | Agrees. |
| T6 | Adds `pad.near`; task text also flags the `Pad` type declaration. | Agrees. |
| T7 | Sets `Workspace` properties + mirrors them as attributes. | Agrees. |
| T8 | One constant, one assignment, sole caller verified. | Agrees. |
| T9 | Investigation whose third outcome is an explicit no-change. | Agrees. |
| Global | "All 129 existing spec files must stay green" vs T1 adding a 130th. | Not a contradiction — the constraint binds the pre-existing suites. |

Ruling: **the `num()`/`cfg()` duplication is replaced by one client ModuleScript,
`roblox/src/client/AmbientConfig.luau`, created in Task 1**; tasks 2–5 require it
instead of copying twelve lines four times. The attribute reads need the `workspace`
global, so they cannot live in the pure `AmbientBudget` without costing it its Lune
coverage — but a client ModuleScript is an established shape here (`FlapBoard.luau` is
one, required by `StatsController` via `script.Parent:WaitForChild`). This pre-empts a
finding in four consecutive reviews. Cost if wrong: one extra small file, reversible by
inlining.

## Progress

Task 1: dispatched (haiku) at base `96257d7` — AmbientBudget + spec, plus the ruled
AmbientConfig client module. Briefs for tasks 2-9 pre-generated.
Task 1: implementer DONE — commit `68a025c`, 1844 tests green (12 new). Review
dispatched (sonnet) over `96257d7..68a025c`.
Task 1: review clean — spec ✅, quality Approved, 0 Critical/Important.
Task 1: ⚠ resolved by controller — reviewer could not verify whether tasks 2-5 call
  `AmbientConfig.get()` per-prop-per-frame (which would reintroduce the allocation cost
  this effort exists to remove). Checked the plan's code for tasks 2, 3, 4 and 5: every
  call site is once per Heartbeat, outside the per-prop loop. Not a gap. Ruling: the
  fresh-table-per-call safety stays (a cached shared table would be mutable by any
  caller); instead each of tasks 2-5 carries an explicit "once per Heartbeat, never
  inside the prop loop" instruction in its dispatch. Cost if wrong: ~6 small table
  allocations per frame, against thousands of PivotTo calls removed.
Task 1: minor (deferred): task-1-report.md miscounts its own tests (12/130 claimed; the
  spec file has 13 `test(...)` calls). Report-only, no code impact.
Task 1: minor (deferred): `step` has no test for a NEGATIVE interval; it lands in the
  same safe `interval <= 0` branch as zero. Guard is `<= 0`, not `== 0`.
Task 1: complete (commits 96257d7..68a025c, review clean)
Task 2: dispatched (sonnet) at base `68a025c` — ChochinSway; sets the adoption shape
  tasks 3-5 copy.
Task 2: implementer DONE — commit `c88690b`, 1844 tests green, gates clean. Review
  dispatched (sonnet) over `68a025c..c88690b`.
Task 2: review clean — spec ✅, quality Approved, 0 Critical/Important/Minor.
Task 2: ⚠ resolved by controller — reviewer could not verify that every stamped pole
  lantern really has a `CrossArm` sibling. Checked: buildChochinPole.luau creates the
  Swing model (:106) and CrossArm (:131) under the same parent, and `grep -c CrossArm`
  returns 0 for both buildTeahouseChochin and buildHanabiyaChochin — the discriminator
  is exact in both directions. It is also the same lookup the shipped `hangPointFor`
  used, whose derived pivot demonstrably applied in the live place. Not a gap.
Task 2: complete (commits 68a025c..c88690b, review clean)
Task 3: dispatched (haiku) at base `c88690b` — NorenSway, same shape as Task 2.
Task 3: implementer DONE — commit `b8c2406`, 1844 tests green, gates clean. Review
  dispatched (haiku; small mechanical diff) over `c88690b..b8c2406`.
Task 3: review clean — spec ✅, quality Approved, no findings.
Task 3: complete (commits c88690b..b8c2406, review clean)
Task 4: dispatched (sonnet) at base `b8c2406` — WheelController; integrated angle must
  keep advancing while culled, only writes and Emit are gated.
Task 4: implementer DONE — commit `e5fe6be`, 1844 tests green, gates clean. Review
  dispatched (sonnet) over `b8c2406..e5fe6be`; reviewer pointed at the integration
  hazard (angle must advance every frame; lastStrike must update even when culled).
Task 4: review clean — spec ✅, quality Approved, 0 Critical/Important. Reviewer traced
  both hazards and confirmed: `angle +=` is unconditional at the top of the closure
  (:178-182), and the strike block sits OUTSIDE the visibility branch with
  `lastStrike[side] = k` unconditional and only `b:Emit(3)` gated (:203-214).
Task 4: minor (deferred) + Ruling: the wheel's hub/paddle CFrame writes are now
  throttled to 30Hz WHILE VISIBLE, not only culled when hidden. The reviewer is right
  that "identical to before" oversells it — this is a real cadence change on a
  continuously rotating object, and the sway props (7-second sine) are a much safer
  case for it than a turning wheel. Ruling: keep it as the plan specifies; the wheel is
  slow (DriveOmega fallback 0.5 rad/s) so 2 display frames per update should not read
  as judder, and the owner's walk is the gate. Cost if wrong: visible stutter on one
  prop, remedied by one line — drop `fire and` from the wheel's visible branch, keeping
  the visibility gate and losing only the throttle half of the win. ADDED TO THE WALK
  LIST: watch the waterwheel for judder while looking straight at it.
Task 4: complete (commits b8c2406..e5fe6be, review clean)
Task 5: dispatched (sonnet) at base `e5fe6be` — HammerController split. Highest-risk
  task in the plan: a mistake here silences the bell or desyncs the wheel.
Task 5: implementer DONE_WITH_CONCERNS — commit `41fe7f8`, 1844 tests green, gates
  clean. The sole concern is the Studio play-test, which I had instructed it to skip as
  unrunnable headless; it is on the owner's walk list. Not a defect.
Task 5: controller sanity-check before review — strike detection (:436) and the
  DriveOmega publish (:464) are both ABOVE the gate (:474), with the three spinner
  write loops below it. The plan's #1 failure mode is avoided.
Task 5: review dispatched (opus — riskiest diff in the plan) over `e5fe6be..41fe7f8`.
Task 5: review — spec ✅, quality Approved, 1 Important + 4 Minor.
Task 5: IMPORTANT (entering fix loop): `strike()` (:314-316) samples `dowels[1].Position`
  for `anchorNet`, but that dowel is kept current only by `updateSuspension`, which this
  task gated — and the `arm` it hangs from is gated too. A culled machine pins the cam
  to a frozen dowel, ~36 degrees out of phase on return. Visual only, self-heals in one
  round, but a genuine regression this commit introduced. Neither the plan nor I caught
  it; the reviewer did.
Task 5: minor (deferred): the cull anchor is `arm.Position`, a part the cull itself
  freezes — stale by at most ~3 studs against a 180-stud radius, cannot flip the
  decision. No change.
Task 5: minor (deferred): three `AmbientConfig.get()` calls per frame (nine GetAttribute
  reads). Exactly what my override specified; on the record if ever consolidated.
Task 5: minor (deferred): `:12` re-walks RoshamboShared though a `shared` local exists
  at `:8`. Harmless, and verbatim the house pattern from tasks 2 and 4 — diverging one
  file would be worse.
Task 5: fix round 1/5 dispatched (resumed original implementer) — extract `poseArm(p)`
  from the draw loop and refresh pose + suspension at the strike call site.
Task 5: fix round 1/5 — implementer returned commit `e57f7e7` (15+/4-), 1844 green.
  ⚠ CONCURRENT SESSION ON MAIN: commit `9ba2027` (synthetic-crowd spec, 288 lines,
  00:29:51) landed between my task commit and the fix — another of the owner's sessions
  committing to main, not my implementer's work. Re-scoped the re-review base to
  `9ba2027` so the unrelated spec stays out of the diff. NOTE FOR THE FINAL REVIEW: the
  whole-branch range will contain other sessions' commits; it must be scoped to this
  plan's files, not to a merge-base range.
Task 5: scoped re-review dispatched (sonnet) over `9ba2027..e57f7e7`.
Task 5: fix round 1/5 (1 addressed, 0 open — dowel refresh before strike; commits
  41fe7f8..e57f7e7). Re-reviewer confirmed poseArm declared before both call sites,
  arithmetic identical to the lifted inline block, refresh strictly before the dowel
  read, all timing lines still unconditional, and no double-write hazard across the
  three Heartbeats (the writes are idempotent from the same metronome schedule).
Task 5: complete (commits e5fe6be..e57f7e7, review clean after 1 fix round)
Task 6: dispatched (sonnet) at base `e57f7e7` — ShopController full poll + the
  AccessGateController split where the fade must keep its frame dt.
Task 6: implementer DONE — commit `6830823`, 1844 green, gates clean. Correctly left the
  concurrently-modified files alone. Review dispatched (sonnet) over `5ff0bc8..6830823`
  (re-scoped again: `5ff0bc8`, another synthetic-crowd commit from the peer session,
  landed inside the range).
Ruling: `.superpowers/sdd/.gitignore` had regressed to a bare `*` again — the documented
  bad state whose own header records that it once broke 11 wiki citations across 7 pages.
  Cause FOUND, and it is our own tooling: the skill's `scripts/sdd-workspace:39` runs
  `printf '*\n' > "$base/.gitignore"` unconditionally on every invocation, so it clobbers
  the narrowed version at the start of every SDD run. Restored via `git checkout --`.
  Cost if wrong: none — restoring the committed version is what the file's own comment
  prescribes. TO DO AT FINISH: record this in the wiki, since it will recur on every
  future SDD run in this repo and nobody has connected the two before.
Ruling: at finish, COMMIT this workspace's markdown rather than `rm -rf` it as the skill
  directs. This repo's wiki cites SDD ledgers as its raw layer (schema rule 4), the
  committed .gitignore exists specifically to keep the markdown, and a prior session had
  to rescue stranded ledgers for exactly this reason (8aeef2a). Cost if wrong: a few
  tracked markdown files that could be deleted later.
Task 6: review clean — spec ✅, quality Approved, no findings at any severity. Reviewer
  read both files in full and confirmed the fade loop is a SIBLING of the throttled
  branch (not nested), `near: boolean` is on the Pad type and initialised at
  construction, collision still snaps off the fresh local, and the accumulator is
  written back unconditionally so the throttle cannot stall.
Task 6: complete (commits e57f7e7..6830823, review clean)
Task 7: dispatched (haiku) at base `6830823` — streaming radii owned in code.
Task 7: implementer DONE — commit `34c3ded` (14 insertions), 1844 green, gates clean.
  Studio verification honestly reported as skipped (headless); on the owner's walk list.
  Review dispatched (haiku; tiny diff) over `6830823..34c3ded`.
Task 7: review clean — spec ✅, quality Approved, no findings.
Task 7: complete (commits 6830823..34c3ded, review clean)
Task 8: dispatched (haiku) at base `34c3ded` — stats-room SurfaceGui MaxDistance.
Task 8: implementer DONE — commit `1e55c9c` (10 insertions), 1844 green, gates clean.
  Review dispatched (haiku; tiny diff) over `34c3ded..1e55c9c`.
Task 8: review clean — spec ✅, quality Approved, no findings.
Task 8: complete (commits 34c3ded..1e55c9c, review clean)
Task 9: dispatched (opus) at base `1e55c9c` — teahouse Persistent investigation. Highest
  blast radius in the plan (a wrong call breaks other players' structures) and the only
  task whose correct outcome may be no code change at all.
Task 9: implementer complete — OUTCOME 3 (change nothing; comment is the deliverable),
  commit `d1d288b` (51 comment lines), 1844 green, gates clean.
  Blocker found: `PerchPreferenceController.attachToStructure` captures `anchorPart()`
  of EVERY site's Structure once per arrival with no retry path — no ChildAdded, no
  ChildRemoved, no heartbeat — so a streamed-out Structure is captured as nothing and
  never recovered. Outcome 2 (narrow to the owner's own structure) would protect the
  WRONG set: every dependency found is on OTHER players' distant teahouses.
  Two corrections to the plan's own assumptions, both worth carrying forward:
   - COST IS LARGER than the plan said: all 14 PadSites use vacantForm
     "dormant-structure", so every pad builds a Structure whether claimed or not — 14
     persistent models per client, 13 of them dormant shells nobody enters, not "one per
     occupied pad".
   - SCOPE IS NARROWER than the plan said: only the Structure carries the flag; deck,
     decorations, mortars, nobori and PortalControl already stream. "Uncapped by
     distance" overstated it — StreamingTargetRadius 512 against a ~496-stud pad spread.
   - The line has no recorded reason anywhere: present since the file's first commit
     (`0566689`), no comment, and that commit message never mentions streaming. The
     status quo is unexplained, not justified.
   - Two cheap, independently-correct hardening fixes would unblock a later removal: a
     retry in PerchPreferenceController and a bay-level ChildRemoved in ShojiController.
     Both controllers already try to be arrival-order resilient and are each one guard
     short. NOT in this task; carry to phase 2.
Task 9: review dispatched (sonnet) over `ac2a390..d1d288b` — reviewing the REASONING,
  with an explicit instruction to say so if the blocker does not hold up, since an
  unnecessary outcome 3 leaves a real memory win on the target device.
Task 9: review clean — spec ✅ (correct outcome-3 call), quality Approved, 0 Critical/
  Important. Reviewer independently read PerchPreferenceController and CONFIRMED the
  blocker by absence: attachToStructure's only triggers are one folder.ChildAdded plus
  an initial sweep; on a nil anchor it returns WITHOUT setting boundStructure, and
  nothing calls it again. Contrasted against BackDoorController:122-128 and
  ShojiController:390, which DO carry late-arrival catches — so the distinction is
  demonstrated, not asserted. Both corrected assumptions verified (14 dormant-structure
  pads; only the Structure carries the flag). Also corroborated the ShojiController
  bay-level ChildRemoved sub-finding independently.
Task 9: minor (deferred): the report's "no recorded reason" provenance claim was made
  with `git log -S ModelStreamingMode`; this very commit reintroduces that string, so a
  future -S search returns two hits. The claim was true at investigation time and
  concerns why the line was ORIGINALLY added, which is unaffected.
Task 9: complete (commits 1e55c9c..d1d288b, review clean)

ALL NINE TASKS COMPLETE. Final whole-branch review dispatched (opus) over the
roblox/-scoped package `final-review-96257d7..HEAD.diff` (10 commits, 1116 lines).
Verified no concurrent-session commit touched roblox/, so the scoping is exact.

## Final whole-branch review (opus)

Verdict: approve with one required fix. Confirmed correct across the branch: the
HammerController/WheelController DriveOmega producer-consumer under all four cull
combinations; `step`'s (fire, nextAcc) order and accumulator write-back at all six call
sites; the squared-distance contract at all five `inRange` sites; AmbientConfig cost is
noise (six tables + eighteen GetAttribute reads per frame against thousands of PivotTo
calls removed).

CRITICAL C1 — a second instance of this branch's signature defect, missed by the Task 5
  fix. `updateSuspension` was throttled to 30Hz, but during a strike `arm.CFrame` is
  driven by a TweenService tween at DISPLAY rate, ungated by anything in this branch
  (the draw loop deliberately yields to it). So the chains and twelve fittings follow the
  log at 30Hz while the log itself moves at 60-120Hz: peak swing velocity ~17 studs/s
  gives up to 0.56 studs of lag on parts whose job is to read as rigid. It is the arena
  centrepiece at the climax of the round, at close range — a visual change on every
  device, which is the branch's one binding constraint. One-line fix.
IMPORTANT I1 — the global AmbientRadius=180 was chosen for two-foot lanterns ("under a
  pixel past thirty feet") and is now also applied to the arena machinery. The far
  teahouse decks are 340-400 studs from the shu-moku and well inside
  StreamingTargetRadius=512, so from the fireworks-watching vantage the whole arena
  freezes — while WheelController's foam emitter, which is NOT gated, keeps churning at
  a motionless wheel. The file's own header says a stalled wheel "read wrong". Raising
  AmbientRadius cannot fix it: it is global, so it would un-cull all 2,599 path lanterns
  and give back the branch's main win.
IMPORTANT I2 + Ruling (REVERSES my Task 7 instruction) — the streaming-radius writes are
  bare property assignments at line ~153 of a 3,436-line composition root, and the entire
  game boots after them. I told Task 7 to add no pcall, reasoning a failure should
  surface loudly. The reviewer is right that I had it backwards: a throw there kills the
  round loop entirely and the symptom (a dead place) points nowhere near the line.
  Ruling: pcall it WITH a warn() naming the cause — loud and non-fatal beats loud and
  fatal. Cost if wrong: three lines of defensive code for a low-probability failure.
Deferred, not fixed: M4 (three redundant accumulators — harmless, and consolidating them
  is refactoring beyond need) and the report-only test miscount.

Fix wave dispatched (sonnet), one subagent, findings C1 + I1 + I2 + M1 + M2 + M3 + M5 + M6.
Final fix wave: commit `46c8a2e` (7 files, 95+/14-), 1847/1847 green (1844 + 3 new M5
  tests), gates clean. Scoped re-review dispatched (sonnet) over `d1d288b..46c8a2e`.
  ⚠ Fixer hit Luau's 200-local-register ceiling in main.server.luau — the pcall's two
  new locals tipped it — and resolved it by scoping them in a `do...end` block. That
  file is now AT the ceiling: any future top-level local risks the same compile failure.
  Worth a wiki line; HudController hit this same ceiling before.
Ruling (correction to my earlier ledger entry): the .gitignore clobber is worse than
  "once per SDD run". `review-package:28` and `task-brief:24` BOTH invoke `sdd-workspace`
  internally, and that script unconditionally rewrites the file — so it is clobbered on
  every brief generation and every review package, dozens of times per run. Restored
  again. This makes the wiki note more valuable, not less.
