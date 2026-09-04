# Task 6 Report — Settlement, the Round document, and everything that carries a round

**Status:** DONE
**Commit:** `b10a33f` — feat(settlement): totalPlayers is the size of the world; Round.synthetic records the bots in it
**Branch:** `thread/crowd` (worktree `.worktrees/crowd`)

## What I implemented

Exactly the brief, verbatim, no additions:

- `server/src/engine/Settlement.ts`
  - `GlobalResult` gains required `synthetic: number`, and both it and `totalPlayers` carry the
    brief's comments (`the size of the WORLD the player faced…` / `how many of those were bots…`).
  - `RoundToSettle` gains optional `crowdCounts?: Record<Throw, number>`; `counts`, `crowdCounts`
    and `throws` carry the brief's `// human + crowd` / `// the crowd's share…` / `// humans only`
    comments.
  - `settleRound` now derives `totalPlayers` from `sum(counts)` instead of `throws.size`, with the
    brief's two-line comment explaining why, and computes `synthetic` from
    `data.crowdCounts ?? { R: 0, P: 0, S: 0 }`. The participant loop is **unchanged** — it still
    iterates only `data.throws`, so bots never reach settlement and no filter was added.
- `server/src/models/Round.ts` — `IRound.synthetic: number` (with the brief's comments on
  `totalPlayers` and `synthetic`) and schema field `synthetic: { type: Number, default: 0 }`.
- `server/src/engine/ResultsStore.test.ts:6` — helper literal gains `synthetic: 0`.
- `server/src/index.ts` (~line 112) — tape seed passes `synthetic: r.synthetic ?? 0`.
- `server/src/engine/Settlement.test.ts` — the brief's two tests appended, verbatim, inside the
  `settleRound` describe (inserted before its closing `});` at former line 250).

**No extra producers.** `npx tsc --noEmit` found none beyond the three the brief named; a
`grep -rn GlobalResult src` confirms the only construction sites are `settleRound` and the
`ResultsStore.test.ts` helper (everything else is a type reference in `ResultsStore.ts`).

## TDD evidence

### RED — `npx vitest run src/engine/Settlement.test.ts`

```
 FAIL  src/engine/Settlement.test.ts > settleRound > the synthetic crowd is part of the world, never a participant (spec §3, §4) > totalPlayers counts humans + bots, synthetic records the bots, and only humans settle
AssertionError: expected { Object (id, worldThrow, ...) } to match object { totalPlayers: 31, …(2) }
  {
    "distribution": {
-     "P": 19,
-     "R": 68,
-     "S": 13,
+     "P": 600,
+     "R": 2100,
+     "S": 400,
    },
-   "synthetic": 30,
-   "totalPlayers": 31,
+   "totalPlayers": 1,
  }

 FAIL  src/engine/Settlement.test.ts > settleRound > the synthetic crowd is part of the world, never a participant (spec §3, §4) > without crowdCounts, synthetic is 0 and totalPlayers is the humans, as before
AssertionError: expected { Object (id, worldThrow, ...) } to match object { totalPlayers: 2, synthetic: +0 }
  {
-   "synthetic": 0,
    "totalPlayers": 2,
  }

 Test Files  1 failed (1)
      Tests  2 failed | 24 passed (26)
```

Failed for exactly the predicted reasons: `totalPlayers` was `throws.size` (1), the distribution was
therefore computed against the wrong denominator, and `synthetic` did not exist. TypeScript did not
reject the `crowdCounts` property in the vitest run (esbuild transpile-only), which is why the
`tsc --noEmit` gate in step 4 matters.

### GREEN — `npx vitest run src/engine/Settlement.test.ts`

```
 Test Files  1 passed (1)
      Tests  26 passed (26)
   Duration  1.94s
```

### Full gate — `npm test && npx tsc --noEmit`

```
 Test Files  25 passed (25)
      Tests  555 passed (555)
   Duration  8.19s

=== TSC ===
TSC_EXIT=0
```

Pristine: no failures, no skips, no type errors, no console noise.

## Files changed

- `server/src/engine/Settlement.ts`
- `server/src/engine/Settlement.test.ts`
- `server/src/models/Round.ts`
- `server/src/engine/ResultsStore.test.ts`
- `server/src/index.ts`

Nothing else was staged. The pre-existing dirty `.superpowers/sdd/.gitignore` was left untouched.

## Self-review findings

Read the committed diff in full. Findings:

1. **Names match the brief exactly** — `synthetic`, `crowdCounts`, and every comment string is
   character-for-character what the brief specified.
2. **No overbuilding** — the `settleRound` participant loop is byte-identical to before; the diff
   touches only the header of the function. No filter, no bot-aware branch, nothing speculative.
3. **The existing distribution test still passes unchanged** — `counts 1/1/1` sums to 3, which is
   what `throws.size` used to be for that test, so `totalPlayers: 3, distribution 33/33/33` is
   preserved. Confirmed by the 26/26 pass, not by inspection alone.
4. **The `?? 0` in `index.ts` is load-bearing** — historical `Round` documents predate the field.
   Mongoose's `default: 0` fills it for documents written from now on, but documents already in the
   collection have no `synthetic` key until touched, so the read path needs the coalesce. Both
   halves of the "keeps every historical row honest" claim are actually implemented.
5. **The end-to-end wiring is already complete** — I checked the one non-test caller,
   `server/src/transports/socketAdapter.ts:145`, which does
   `settleRound({ ...data, timestamp: new Date() })`. Because it spreads the whole
   `RoundClosedEvent`, Task 5's `crowdCounts` reaches settlement with no change to that file. This
   is why the brief did not list it, and I verified rather than assumed.

## Concerns

None blocking. Two observations for the controller:

- **`GlobalResult.synthetic` is on the wire.** `ResultsStore` hands `GlobalResult` objects to the
  socket adapter and the `/api/v1` routes, so `synthetic` is now visible to PWA and Roblox clients.
  That is presumably intended (the field describes the world the player faced), but if any consumer
  is meant to keep the bot share hidden, that is a later task's decision, not something this task
  changed deliberately.
- **Historical rounds will read `synthetic: 0` and `totalPlayers` = old human count.** That is the
  honest answer — those rounds genuinely had no crowd — and no backfill is needed.
