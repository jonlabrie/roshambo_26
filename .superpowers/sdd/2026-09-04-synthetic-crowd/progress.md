# SDD ledger — plan: docs/superpowers/plans/2026-09-04-synthetic-crowd.md

Spec: docs/superpowers/specs/2026-09-04-synthetic-crowd-design.md (approved 2026-09-04, all three §11 decisions taken as recommended).
Worktree: .worktrees/crowd, branch thread/crowd, base 39f3387 (main). Baseline: server suite 507/507 green.
Models: implementers = opus (owner's choice); task reviewers = opus; final whole-branch review = fable.

## Pre-flight scan (before Task 1)

Pairs sharing a file or interface:

| tasks | produces → consumes | finding |
|---|---|---|
| 1→2 | `Rng`, `mulberry32` → `sample(d, rng)` | consistent |
| 2→3 | `PolicyId/POLICY_IDS/Memory/freshMemory/policyDistribution/sample/advance/Dist` → crowd bots | consistent; `POLICY_IDS` order fixed in both |
| 3→4 | `parseMix/DEFAULT_MIX/formatMix/Mix` → `readCrowdConfig` | consistent; error strings identical in T3 impl and T4 test |
| 3→5 | `Crowd` (size, throws, observe, expected) → `CrowdSource` (throws, observe) | structurally assignable |
| 5→6 | `RoundClosedEvent.crowdCounts` (required) → `RoundToSettle.crowdCounts?` (optional) | compatible; socketAdapter spreads `data` through unchanged |
| 6→7 | both edit `server/src/index.ts` (T6 tape seed line; T7 imports/config/log) | different regions; T7 runs after T6, no overlap |
| 1,3,4,5→7 | `mulberry32/randomSeed`, `createCrowd/formatMix`, `readCrowdConfig`, `CrowdSource/RoundClosedEvent` | names match |
| 2,3→8 | policies + `createCrowd(...).expected()` for the oracle | `expected()` defined in T3 |
| 8→9 | `RoundRecord/HumanSpec` → reporters | humans[i] index order = HumanSpec[] order, used consistently |
| 8,9→10 | `runSimulation/applyBank`, five reporters → experiments | names match; effective-n is an experiment over `winRates`, not a reporter |
| 3→10 | `DEFAULT_MIX/DEFAULT_STRENGTH` → `parseArgs` defaults + test | T11 may move them; T11 Step 3 lists both tests to update |
| 11→12 | sim outputs → wiki section | T12 pastes T11 Step 4 files |
| 12→13 | docs → push/CI | ok |

Per-task internal consistency:

| task | check | finding |
|---|---|---|
| 1 | known-answer values | computed locally from the same mulberry32 (0.627074 0.002736 0.527447 / 0.601104 0.448291 0.852466) |
| 2 | every expected distribution vs the impl formula | hand-checked: rocky no-mem .45/.275/.275; twoRocks .1/.45/.45; wsls SAFE strength/2; counter/conform/second point masses |
| 3 | `allocate(10, DEFAULT_MIX)` expectation | hand-derived: quotas 2/3.5/2/1.5/1, remainder to wsls (earlier id on tie) → matches |
| 4 | TEST_MODE warning string test vs impl | identical |
| 5 | `toHaveBeenCalledExactlyOnceWith`, `mock.invocationCallOrder` | Vitest 4.1.8 has both |
| 6 | distribution 21/6/4 of 31 → 68/19/13 | correct rounding; `synthetic` required on GlobalResult → ResultsStore.test helper updated in-task |
| 7 | crowd built before the MONGODB_URI fatal check; dotenv non-override of empty string | correct; boot-log checks are observational, no test harness for index.ts |
| 8 | round-0 nondeterminism in the two conform-crowd tests | rewritten to be exact from round 1 regardless of round 0 |
| 9 | 5-round hand log vs reporter expectations | a: 2W/3S; b: 3W/1S/1L; transitions 1 same/3 counter |
| 10 | `npm run sim` = `tsc && node dist/sim/cli.js`; dist ignored; tsc excludes tests | ok |
| 11 | judgement task with ordered adjustments and a strength ceiling | fine; controller reviews result |
| 12 | flip procedure checks ConfigurationSource before editing | ok; owner-gated, not executed |

Rubric-sensitive plan mandates (so the reviewer's flag is anticipated, not dismissed):
- `cli.ts` runs `main()` at module load (it is the CLI entry). `experiments.ts` destructures `_json` to drop a field (no `noUnusedLocals` in tsconfig).
- T7 has no automated test (index.ts connects to Mongo at import); verification is the boot log per plan.

Scan verdict: no conflicts requiring a ruling. Proceed to Task 1.

## Tasks
Task 1: implementer agent aa118f4c63130a14a (opus); reviewer a238edcb57032ccfd (opus)
Task 1: minor (deferred): Prng.test.ts:29-33 randomSeed asserted on one draw; a short loop would match the mulberry32 uniformity test (brief-inherited)
Task 1: minor (deferred): Prng.ts:7 `seed >>> 0` truncates non-integer seeds silently — covered downstream: Task 4's nonNegativeInt rejects non-integers for CROWD_SEED
Task 1: complete (commits 39f3387..9f9c79f, review clean; Co-Authored-By trailer verified by controller)
Task 2: implementer agent a321535fbbffcec68 (opus); reviewer abca540305df2bcde (opus)
Task 2: minor (deferred): CrowdPolicies.ts:41 UNIFORM is a shared mutable singleton returned by reference; Object.freeze would be safe (all write sites build fresh literals). Task 3's expected() accumulates into a fresh object per plan — pointer carried into Task 3 dispatch.
Task 2: minor (deferred): blend's clamp untested; no sum-to-1 property test across POLICY_IDS; normalised zero-total branch unreachable
Task 2: minor (deferred): report claimed "no extra exports" but pointMass/blend are exported (brief-mandated, additive)
Task 2: complete (commits 9f9c79f..54f5864, review clean; Co-Authored-By trailer verified by controller)
Task 3: implementer agent abd6b9e1dda641e3b (opus); reviewer a1459a25901d4c161 (opus)
Task 3: minor (deferred): parseMix accepts a second colon ('wsls:1:2' → weight 1) and reports a missing colon as a weight error; a segment-count guard would be additive to the four pinned strings
Task 3: minor (deferred): no regression tests for double-observe idempotence or UNIFORM non-mutation by expected(); allocate comment lists quotas in DEFAULT_MIX order not POLICY_IDS order
Task 3: minor (deferred): fractional size over-allocates in allocate — covered downstream: Task 4's nonNegativeInt rejects non-integer CROWD_SIZE
Task 3: complete (commits 54f5864..4e2ea80, review clean; trailer verified)
Task 4: implementer agent a66fcfb7a6938163d (opus); DONE_WITH_CONCERNS at 88de2c0
Task 4: note: implementer saw one flaky failure in src/transports/socketAdapter.test.ts (CLAIM_LIMIT assertion), untouched by this task; two re-runs green. Pre-existing; not this plan's defect.
Task 4: Ruling: validate CROWD_MIX and CROWD_SEED BEFORE the TEST_MODE guard, so a malformed value refuses to boot in every mode (spec §5 "refuses at boot"); the guard still disables the crowd with its warning, and the "CROWD_SEED unset; using N" line prints only when the crowd is actually on — why: dev and prod both run TEST_MODE today, so the brief's ordering would let a CROWD_MIX typo sit silent until flip day — cost if wrong: a service with a typo'd CROWD_MIX fails to boot under TEST_MODE instead of ignoring it; trivially reversible by fixing the env var.
Task 4: fix implementer (fresh, SendMessage unavailable) ad618045e0813df41 (opus) → 1d23924; reviewer ada22795386c4ac12 (opus)
Task 4: fix round 1/5 (1 addressed, 0 open — validation before TEST_MODE guard; commits 88de2c0..1d23924)
Task 4: Ruling: CROWD_SIZE="0" with a malformed CROWD_MIX stays silent — 0 is the explicit off switch and spec §5 says 0 → off silently; the ruling above covered only the TEST_MODE guard — cost if wrong: a typo'd mix on a size-0 service waits until a size is set; caught then by the boot refusal.
Task 4: minor (deferred): whitespace-only values inconsistent across the three vars (a shared trim would unify); Number() accepts 1e3/0x10 forms; DEFAULT_MIX returned by reference when CROWD_MIX unset
Task 4: complete (commits 4e2ea80..1d23924, review clean; trailers verified)
Task 5: implementer agent ae7cd4a236b4e3fc2 (opus); reviewer addb460bb1dbd8f4f (opus)
Task 5: Ruling: a throwing CrowdSource.throws()/observe() would propagate out of the setInterval tick and exit the process (no uncaughtException handler). Fix belongs in the COMPOSITION ROOT (Task 7), not the engine: wrap the crowd passed to the engine so an exception logs `[CROWD] error …` and yields {R:0,P:0,S:0} / a no-op observe for that round. Keeps the engine pure and the round alive. Cost if wrong: one round with no crowd and a log line, vs a dead server.
Task 5: minor (deferred): crowdCounts aliases the object crowd.throws() returned (createCrowd allocates fresh, fakeCrowd in tests does not — a mutating CrowdSource would go uncaught); `closed: any[]` in the new tests; second test title overpromises ("never reach settlement" is Task 6's file)
Task 5: complete (commits 1d23924..b1ac300, review clean; trailer verified)
Task 6: implementer agent a6e1c2c0eea484750 (opus); reviewer a9c699754efdd6428 (opus)
Task 6: minor (deferred): no test pins the zero-humans + crowd round (correct by construction: totalPlayers = bots, placeholder 33/33/33 now only when nobody at all threw); `r.synthetic ?? 0` in the tape seed is defensive not load-bearing (schema default fills on hydrate); buildDistribution's independent rounding (pre-existing) is more visible with non-round denominators
Task 6: complete (commits b1ac300..b10a33f, review clean; trailer verified)
Task 7: implementer agent acfbab2d3f3f490e0 (opus); reviewer aa0db8cfbadca1592 (opus)
Task 7: note: plan Task 7 Step 6 predicted `mix wsls:35,...`; actual formatMix order is POLICY_IDS order `random:20,wsls:35,counter:20,conform:15,rocky:10`. Stale prediction in the plan text, not a defect.
Task 7: minor (deferred): guardCrowd logs `undefined` for a non-Error throw (String(err?.message ?? err) would keep the diagnostic); failure test asserts content not call count; the guard narrows Crowd → CrowdSource so index.ts holds no handle to expected()/size (unused there today)
Task 7: complete (commits b10a33f..c35ce0d, review clean; trailer verified)
Task 8: implementer agent aec477781f7583cc6 (opus); reviewer a75fe944ffbf8b313 (opus)
Task 8: minor (deferred, plan-mandated): `minParticipants ?? 5` duplicates GameRules' default (literal 5 now in GameRules.ts, index.ts, Simulation.ts); `freshMemory() as Memory` no-op cast; `?? 0` after pop() unreachable
Task 8: minor (deferred): ratio rule never exercised inside runSimulation (only as pure applyBank); rounds:0 / humans:[] / minParticipants override untested; small-crowd random fallback invisible in RoundRecord (derivable from counts sum); `mix: {}` yields a zero-bot crowd silently (SyntheticCrowd treats {} as a valid mix)
Task 8: note: ratio rule has a discontinuity at bank = 3·pot (spec's rule, not a defect) — readability tables will show it
Task 8: complete (commits c35ce0d..8ab146e, review clean; trailer verified)
Task 9: implementer agent a40738bcb9e6da525 (opus); reviewer aa4f69cefa9fb46de (opus)
Task 9: minor (deferred): on an empty log winRates returns one row per human while bankedTotals/maxPots return [] (Task 10 zips by index — a zero-round run would yield undefined columns); positional r.humans[i] unchecked (plan-mandated, aligned by construction); zero-length guards untested; Math.max(0, n-1) dead defence
Task 9: complete (commits 8ab146e..83f85c1, review clean; trailer verified)
Task 10: implementer agent a10a9c341e3420bbf (opus); DONE_WITH_CONCERNS at 359797e (concerns are about the model, not the code)
Task 10: finding (model): at DEFAULT_MIX, 2000 rounds seed 1 — random 30.8%, counter 6.6%, second 82.5%, oracle 82.4%; world transitions counter-wards ~82%. The crowd is OVER-readable: `second` (counter the counter) is a teachable rule above the ~60% ceiling, and the naive `counter` reader is punished (SAFE most rounds). Plan Task 11's adjustment list (raise counter, raise strength, lower random) assumes UNDER-readability and points the wrong way.
Task 11: Ruling: tuning direction REVERSED for the observed failure — adjust toward LESS predictability: (a) lower `counter` weight toward 10 and raise `wsls`/`random` to compensate; (b) lower DEFAULT_STRENGTH toward 0.5–0.6; (c) if still >60%, raise `random` toward 30. Stop at the first mix where the best non-oracle rule is 45–60% AND some rule is ≥45%. Keep the plan's strength ceiling of 0.85 (irrelevant now) and add a floor of 0.4 — below that the crowd is noise. Cost if wrong: a mix a little too easy or too hard; Q1 (owner's twenty minutes) is the real test either way.
Task 11: Ruling: the `random` target "33% ± 1.5" is read as 30–34% — a blind human's own throw is in the tally it is judged against (self-inclusion → SAFE more, WIN less, ~2 pts at crowd 30). This is a property of the game (spec §2 within-round reactivity), not of the sim. Cost if wrong: none material; the sim's random row is a null hypothesis, not a target.
Task 10: reviewer aa65648b2f635f444 (opus): Approved with 2 Important (plan-mandated) findings
Task 10: Ruling: both Important findings are accepted over the brief's verbatim code — (1) the four numeric flags get a finiteness guard (`--strength abc` otherwise yields NaN → every bot throws S via sample()'s rounding guard and prints a believable table); (2) parseArgs refuses rounds < 1 (empty log prints `undefined`/NaN). Why: Task 11 tunes by reading these tables; a silent bad run would tune against noise. Cost if wrong: two extra error paths in a dev-only CLI.
Task 10: minor (deferred): header prints crowd=30 for effective-n (which sweeps sizes); blind-spread `runs` vs ratios.length gap unrecorded; banked/max-pot columns overflow and exceed 2^53 (float artifacts printed as digits); report cites a nonexistent server/.gitignore (root .gitignore:2 is the real source); DEFAULT_MIX by reference; `in`-narrowing vs switch; unguarded main() prints a stack trace
Task 10: fix round 1/5 (2 addressed, 0 open — finite() guard on numeric flags; rounds >= 1; commits 359797e..c33d17a); fix implementer a7140492d616e1563 (opus); re-reviewer a1219aa53ab14d967 (sonnet)
Task 10: minor (deferred): --crowd has no lower bound (0/negative accepted after the finite guard)
Task 10: complete (commits 83f85c1..c33d17a, review clean; trailers verified)
Task 11: Ruling: sim outputs for the wiki are saved under the plan workspace (.superpowers/sdd/2026-09-04-synthetic-crowd/sim-*.txt) instead of /tmp — why: /tmp does not survive between sessions and Task 12 needs the files. Cost if wrong: none.
Task 11: implementer agent a2c7f751337970f7b (opus); DONE_WITH_CONCERNS at e79540b. Settled DEFAULT_MIX wsls:30,counter:10,conform:30,rocky:10,random:20 at strength 0.7. Seed 1: random 29.4, counter 42.2, conform 5.9, wsls 32.8, second 51.9, oracle 56.5. Best rule 51.4–52.4% across seeds 1–3; nothing non-oracle above 60%.
Task 11: finding (model): the baseline was over-readable because wsls's lose-shift is CLOCKWISE, which lands on the counter-throw, so wsls and counter pulled the world the same way; raising conform (not noise) was the fix. Documented in the report.
Task 11: Ruling: the `random` band is widened to 29–34%. The implementer probed ~40 cells (strength 0.5–0.85, eight mixes, three random weights) and a blind human never left 29.1–30.6% once the best rule was held under 60% — the shortfall tracks the plurality margin, which any non-metronome crowd narrows. The random row is a null hypothesis, not a design target; recording the structural reason on the wiki is the deliverable. Cost if wrong: none material to the game; the live READ column measures real humans, not this row.
Task 11: minor (deferred): conform is a near-dead rule at the settled mix (5.9% — it wins only on "other" rotations, expected); effective-n is non-monotonic at crowd 15 because of allocate rounding at small sizes, not noise
Task 11: reviewer ae325f6a74e7248dd (opus): Approved; reproduced sim-readability.txt byte-identically from the committed constants; allocate expectation re-derived
Task 11: minor (deferred): DEFAULT_MIX comment omits conform's 5.9%; report's verdict table still says random MISS against the pre-ruling band (Task 12 must not paste that verdict); "smallest sufficient change" sentence overstates (run 7 was rejected for second == oracle, the right reason); first allocate test title still says "largest remainder" though the case no longer exercises it; plan Task 7 Step 6 banner string is stale (Task 12 fixes the plan text)
Task 11: complete (commits c33d17a..e79540b, review clean; trailer verified)
Task 12: implementer agent a8af7cf3b354b4047 (opus); DONE at 3de3bb1; wiki lint tools/wiki/lint.mjs baseline 35 errors / 1 warning pre-existing, unchanged by this task
Controller: restored .superpowers/sdd/.gitignore from HEAD (the sdd-workspace script rewrote it to a bare `*`; the repo's narrowed version keeps ledger markdown, which the wiki cites as raw layer). This plan's ledger/brief/report markdown is committed at finish; .diff packages stay ignored.
Task 12: reviewer a6def3290d3803f9b (opus): Approved with 1 Important — deploy.md flip step 5 omits parked-defects.md (h) and CLAUDE.md's Architecture line, both of which state "not active in any deployed environment" and would go stale on flip day. Fix round 1 dispatched.
Task 12: minor (deferred): "as of the date at the top of this page" ambiguous (two dates in frontmatter); seeds 2–3 result lacks its re-measure command; "~40 mix cells" reads as a measurement (it was a search); world-throw "run" vs deploy "ran" tense; deploy.md quotes the boot line without its `[SYS]` prefix; plan lines 415/514/544 still show the pre-tuning DEFAULT_MIX (in-scope only for the Step 6 banner by ruling — the plan is a historical artifact)
Task 12: fix round 1/5 (1 addressed, 0 open — flip checklist names all four pages; commits 3de3bb1..a38c6d3); fix implementer ac647f10b4f31c7e4 (opus); re-reviewer a682eee724ae1df8c (sonnet)
Task 12: complete (commits e79540b..a38c6d3, review clean; trailers verified)
Task 13: implementer agent a951c30d086f0426e (opus). npm test 579/579 (28 files), tsc clean, sim header at settled mix. Pushed thread/crowd; server-ci success https://github.com/jonlabrie/roshambo_26/actions/runs/33870848462
Task 13: note: implementer quoted random 26.2% from a 1000-round run and read the band as 30–34; the 20000-round figure on the wiki is 29.4% inside the ruled 29–34% band. Not a defect.
Task 13: Ruling: no task review dispatched — the task produced no diff (verification + push only); controller confirmed the CI run conclusion directly. Cost if wrong: none; the whole-branch review covers every commit.
Task 13: complete (no commits; CI green)
Final review: agent a8235485f00f64de9 (fable). Verdict: With fixes. Important #1: index.ts pickWorldThrow calls deriveWorldThrow without `random`, so ties break on Math.random and the seeded zero-human sequence is not reproducible (spec §2/§7 Q6, deploy.md). Minors: #2 malformed CROWD_* exits via stack trace not `[FATAL]`; #3 no test for zero humans + crowd meeting the participant floor; #4 wiki readability table prints a >2^53 banked value as digits; #5 freeze UNIFORM; #6 wiki Q1 paragraph should say the naive `counter` reader sits at ~42% and `second` is the rule that clears 45%. Deferred-minor triage: none block merge. Rulings check: Task 11 band widening needs OWNER RATIFICATION at handoff; Task 4's two rulings are in tension (record the choice on world-throw § Config).
Final: fix wave dispatched (one implementer, items #1–#6 + the Task 4 config note)
Final: fix wave implementer a0727197c951dfa80 (opus) → 1f93533 (code) + 47635af (docs). Seeded tie-break shares the crowd's rng; [FATAL] on malformed CROWD_*; UNIFORM frozen; two RoundEngine tests (seeds 7 and 3 — seed 3 is the one that ties and goes red without the fix); wiki float caveat, Q1 counter-vs-second note, boot-refusal rule. Suite 582/582, tsc clean, lint 35/1 unchanged.
Final: re-reviewer a90179174d56f32a8 (opus): #1 #2 #3 #5 #6 + rulings note ADDRESSED; #4 NOT ADDRESSED — the float caveat names `second`/`oracle` but the row past 2^53 is `counter` (both columns). No new breakage. RoundEngine 30/30, lint 35/1.
Final: Ruling: residual #4 fixed by the controller directly (one-word row attribution in world-throw.md, verified against the table on the page: counter's 6765376709498072000 / 1350851717672992000 are the only figures past 2^53). Why: a known-false sentence on the authoritative page must not reach the owner, and a second fix wave for one word is disproportionate. Cost if wrong: a docs sentence, trivially re-edited.
Final: whole-branch review clean after the fix wave + one controller edit. Branch thread/crowd ready for finishing-a-development-branch. Owner items at handoff: ratify the Task 11 blind-band widening (29–34%); the dev flip (owner-run, deploy.md procedure); Q1 (twenty rounds on dev).
