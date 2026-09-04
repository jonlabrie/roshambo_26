# Task 5 report: The engine merge

**Commit:** `b1ac300` feat(engine): merge the synthetic crowd into the tally at LOCK->REVEAL, before the World Throw is picked

## What I implemented

`server/src/engine/RoundEngine.ts`, exactly as the brief specifies:

- New exported `CrowdSource` interface (`throws(roundCount)` / `observe(worldThrow)`) placed
  directly after `ThrowEntry`. Structural — the engine imports nothing from `SyntheticCrowd.ts`.
- `EngineConfig.crowd?: CrowdSource`, added after `pickWorldThrow`.
- `RoundClosedEvent.crowdCounts: Record<Throw, number>` — REQUIRED, zeros when no crowd is
  configured; `counts` is now human + crowd. Both fields carry the brief's inline comments.
- The LOCK→REVEAL branch now computes `humanCounts` from `countThrows()`, asks the crowd for its
  tally (or zeros), sums the two into `counts`, runs `pickWorldThrow(roundCount, counts)`, then
  calls `crowd?.observe(worldThrow)` — picker first, observe second. `throws: new Map(this.throws)`
  is untouched, so the per-participant map stays human-only.

The existing comment block above the transition (THE ANSWER IS DECIDED HERE / revealPending) is
preserved verbatim and extended with the crowd paragraph — not replaced.

No changes to timing, phases, the `revealPending` handshake, or any other file. No new packages.

## TDD evidence

### RED — `npx vitest run src/engine/RoundEngine.test.ts` (test block appended, no implementation)

```
 FAIL  ... > pickWorldThrow sees human + crowd counts, and roundClosed carries both
AssertionError: expected "vi.fn()" to be called with arguments: [ +0 ]
Number of calls: 0
   290|         expect(crowd.throws).toHaveBeenCalledWith(0);

 FAIL  ... > observe() receives the DECIDED World Throw, after the picker ran
AssertionError: expected "vi.fn()" to be called once with arguments: [ 'S' ]
Number of calls: 0
   311|         expect(crowd.observe).toHaveBeenCalledExactlyOnceWith('S');

 FAIL  ... > without a crowd, crowdCounts is zeros and counts are the humans alone
AssertionError: expected undefined to deeply equal { R: +0, P: +0, S: +0 }
   322|         expect(closed[0].crowdCounts).toEqual({ R: 0, P: 0, S: 0 });

 Test Files  1 failed (1)
      Tests  3 failed | 24 passed (27)
```

**Deviation from the brief's expected RED, and why it is correct:** the brief predicted four
failures; three failed. The fourth — *"the throws map stays human-only — bots never reach
settlement"* — passed at RED, because with no crowd merge implemented the map is trivially
human-only. It is a regression guard against a future implementation that pushes bot entries into
`this.throws`; it cannot fail before the feature exists. All 23 pre-existing tests passed at RED,
as required.

### GREEN — `npx vitest run src/engine/RoundEngine.test.ts`

```
 Test Files  1 passed (1)
      Tests  27 passed (27)
```

### Full suite — `npm test` (from `server/`)

```
 Test Files  25 passed (25)
      Tests  553 passed (553)
   Duration  8.79s
```

### Typecheck — `npx tsc --noEmit`

Clean, no output.

## Files changed

- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/crowd/server/src/engine/RoundEngine.ts` (+26 / −4)
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/crowd/server/src/engine/RoundEngine.test.ts` (+56)

Nothing else staged. `git status` after the commit shows only the pre-existing dirty
`.superpowers/sdd/.gitignore`, which I did not touch or stage.

## Self-review findings

Read the committed diff end to end:

- Names match the brief exactly: `CrowdSource`, `throws`, `observe`, `EngineConfig.crowd`,
  `RoundClosedEvent.crowdCounts`, local `humanCounts` / `crowdCounts` / `counts`.
- Ordering is right: `crowd.throws()` → sum → `pickWorldThrow` → `crowd.observe()`. The test
  asserts the invocation order directly, not just the values.
- `counts` is a freshly built object, so summing cannot mutate the crowd's or the engine's state.
- Absent `crowd`: `this.cfg.crowd ? ... : { R: 0, P: 0, S: 0 }` and `?.observe` — no calls, no
  behaviour change. All 23 pre-existing engine tests and the whole 553-test suite pass untouched.
- No overbuilding: no config validation, no crowd construction, no wiring in `index.ts` (not this
  task), no `Settlement`/`socketAdapter` edits (Task 6, and the adapter's spread already forwards
  the new field).

## Concerns

1. **`crowdCounts` aliases the crowd's returned object.** The engine emits whatever object
   `crowd.throws()` returned rather than a copy, so a `CrowdSource` implementation that returns a
   reused internal object would see it published on `roundClosed` and potentially observed later as
   mutated. This is the brief's exact code and Task 3's `Crowd` is expected to return a fresh
   object; flagging it as a contract the crowd side must honour, not a defect to fix here.
2. **`RoundToSettle` does not yet know `crowdCounts`.** As the brief predicted, this typechecks
   today because `socketAdapter` passes `{ ...data, timestamp }` through a spread. Task 6 makes the
   field explicit there.
