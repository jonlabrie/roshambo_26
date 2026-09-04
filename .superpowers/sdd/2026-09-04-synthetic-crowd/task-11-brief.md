### Task 11: Q0 — tune the default mix, record the result

**Files:**
- Modify (maybe): `server/src/engine/SyntheticCrowd.ts` (`DEFAULT_MIX`, `DEFAULT_STRENGTH`) and the two tests that pin them (`SyntheticCrowd.test.ts` "defaults to…", `experiments.test.ts` "has sensible defaults" — the latter reads `DEFAULT_MIX` so only the strength literal `0.7` may need editing)
- Modify: `docs/wiki/world/world-throw.md` (new section, see Task 12 for the full text — this task supplies its numbers)

This is a judgement step with pre-registered targets (spec §2): at the default mix, **some teachable rule (`counter`, `conform`, `wsls` or `second`) reaches BEAT WORLD ≥ 45%**, **`random` stays within 33% ± 1.5**, and **no non-oracle rule exceeds ~60%**.

- [ ] **Step 1: Run the readability experiment at three seeds**

```bash
npm run sim -- --rounds 20000 --seed 1
npm run sim -- --rounds 20000 --seed 2
npm run sim -- --rounds 20000 --seed 3
```

- [ ] **Step 2: Judge against the targets**

If all three hold across seeds, go to Step 4. If not, adjust in this order, one change at a time, re-running after each: (a) raise `counter`'s weight toward 30 (makes the world rotate, which `second` reads); (b) raise `DEFAULT_STRENGTH` toward 0.8; (c) lower `random` toward 10. Stop at the first mix that meets all three targets. Do not exceed strength 0.85 — beyond that the crowd is a metronome, not a crowd.

- [ ] **Step 3: If anything changed, update the pinned constants and their tests**

Edit `DEFAULT_MIX` / `DEFAULT_STRENGTH` in `server/src/engine/SyntheticCrowd.ts`; update the `expect(DEFAULT_MIX).toEqual(…)` and `expect(DEFAULT_STRENGTH).toBe(…)` lines in `SyntheticCrowd.test.ts`; update the `strength: 0.7` literal in `experiments.test.ts` if strength moved; re-derive the `allocate(10, DEFAULT_MIX)` expectation by hand (largest remainder, `POLICY_IDS` order) and update it. Run `npm test`.

- [ ] **Step 4: Run the other two experiments at the settled mix and keep the outputs**

```bash
npm run sim -- --rounds 20000 --seed 1 > /tmp/readability.txt
npm run sim -- --experiment blind-spread --rounds 360 --seed 1 > /tmp/blind.txt
npm run sim -- --experiment effective-n --rounds 5000 --seed 1 > /tmp/effn.txt
```

These three outputs are pasted into the wiki in Task 12.

- [ ] **Step 5: Commit (only if constants changed)**

```bash
git add src/engine/SyntheticCrowd.ts src/engine/SyntheticCrowd.test.ts src/sim/experiments.test.ts
git commit -m "tune(crowd): default mix settled by the readability experiment -- <state the three rates>

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

