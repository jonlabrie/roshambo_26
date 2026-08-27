# Task 1 Report: Express `/state` publishes phase durations

## What Was Done

Implemented the round-metronome schedule source by publishing phase durations from the Express game server.

### Changes Made

1. **`server/src/engine/RoundEngine.ts`**: Added `durationsMs()` method (lines 62-69) that returns phase durations in milliseconds:
   - `activeMs: number` (activeSeconds × 1000)
   - `tallyMs: number` (tallySeconds × 1000)
   - `revealMs: number` (revealSeconds × 1000)

2. **`server/src/routes/apiV1.ts`**: Updated `/state` response handler (line 32) to include `durations: engine.durationsMs()` in the JSON payload.

3. **`server/src/routes/apiV1.test.ts`**: Added test case "states its phase durations (round-metronome schedule source)" (lines 55-58) in the `GET /state` describe block.

## Test Evidence

### Step 1: Initial Test (Expected Failure)
```bash
npx vitest run src/routes/apiV1.test.ts -t "phase durations"
```

**Result**: FAILED ✓
- Expected: `{ activeMs: 20000, tallyMs: 2000, revealMs: 3000 }`
- Received: `undefined`

This confirmed the test was written correctly before implementation.

### Step 2: After Implementation
```bash
npx vitest run src/routes/apiV1.test.ts -t "phase durations"
```

**Result**: PASSED ✓
- 1 test passed | 35 skipped

### Step 3: Full Test Suite
```bash
npm test
```

**Result**: ALL TESTS PASSED ✓
- Test Files: 13 passed
- Total Tests: 189 passed
- Duration: 3.99s

All existing tests continue to pass; no regressions introduced.

## Implementation Quality

- **Correctness**: The `durationsMs()` method correctly multiplies the configured seconds (20, 2, 3) by 1000 to produce milliseconds (20000, 2000, 3000).
- **API Contract**: The `/state` endpoint now provides the phase durations as a structured object, enabling clients to build absolute round schedules without relying on heuristics.
- **No Breaking Changes**: The new `durations` field is additive to the existing `/state` response; existing clients ignore it.
- **Configuration Awareness**: Durations are derived from the engine's config, so changes to phase timing automatically propagate.

## Self-Review Notes

- The implementation follows the brief's interface specification exactly.
- The test matches the expected values (20000, 2000, 3000) for ACTIVE, TALLY, and REVEAL phases.
- No files were modified outside the scope named in the brief.
- The commit message follows the project's conventional-commit style.
