### Task 13: Full verification and the handoff to the owner

**Files:** none new.

- [ ] **Step 1: Everything green**

From `server/`: `npm test && npx tsc --noEmit && npm run sim -- --rounds 1000`
Expected: PASS, clean, a table.

- [ ] **Step 2: Push and watch CI**

`git push` from the repo root, then confirm the `server-ci` run is green (the repo's standing rule: a push is not done until its CI run is seen green — [[rojo-and-place]]). If `gh` is too old to `gh run watch`, open the Actions tab.

- [ ] **Step 3: STOP — the flip is the owner's**

Report to the owner: the readability table, whether the three Q0 targets held and at what mix, the blind-spread and effective-N results in one line each, and the flip procedure's location. Do not run the App Runner update. Q1 is the owner's twenty minutes on dev after the flip.

---

## Self-review against the spec

- §0 tally-vs-visible: Task 12 wiki text names it; no avatar work anywhere. ✔
- §1 seam in the engine, `crowdCounts` on `roundClosed`, `throws` human-only, `CrowdSource` shape: Task 5. ✔
- §2 module, archetypes, strength blend, default mix, determinism, exact allocation: Tasks 1–3; tuning Task 11. ✔
- §3 `totalPlayers` = world, `Round.synthetic` default 0, additive on `GlobalResult`/reveal/store/API/tape seed: Task 6 (the `reveal` payload and `/rounds/:id/result` both serialize `GlobalResult`, so they carry it without edits). ✔
- §4 settlement humans-only, READ gate opens: Task 6 test asserts `User.countDocuments() === 1` and one `PlayerRound`. ✔
- §5 three env vars, boot refusal, TEST_MODE guard, per-round log, environments: Tasks 4, 7, 12. ✔
- §6 simulator, humans as policies, `second` + `oracle`, three bank rules, five reporters: Tasks 8–10 (effective-N is an experiment over `winRates`, not a separate reporter). ✔
- §7 six questions: Q0 Task 11; Q1/Q2/Q6 live after the owner's flip (Task 12 procedure, Task 13 stop); Q3 readability's banked/maxPot columns; Q4 blind-spread; Q5 transitions. ✔
- §8 fitter: out of scope, named in the wiki text. ✔
- §9 tests: every bullet has a task; no fixture change. ✔
- §10 out of scope respected: no client edits, prod untouched, no bot persistence. ✔
- Type consistency: `CrowdSource` (engine) vs `Crowd` (module) — `Crowd` has the extra `size` and `expected()`, structurally assignable. `RoundRecord.humans[i]` indexes match `HumanSpec[]` order in `winRates`. `applyBank` signature identical in Task 8 test and impl. `parseArgs` defaults match `DEFAULT_MIX`/`DEFAULT_STRENGTH` until Task 11 moves them, at which point Task 11 Step 3 updates both tests.
