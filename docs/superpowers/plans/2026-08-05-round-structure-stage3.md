# Round Structure Stage 3 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the round's three phases to `OPEN` / `LOCK` / `REVEAL` across the server, the Roblox game server, the Roblox client and the PWA, so the phase names describe what actually happens in them — and make the durations env-configurable so the 60-second launch round is a config change rather than a code edit.

**Architecture:** `RoundEngine` is the single source of the phase. It gains a `LOCK` phase that replaces `TALLY`, and the world throw moves from the end of `ACTIVE` to the end of `LOCK` — which is the same wall-clock instant, since `ACTIVE`'s last two seconds already were the lockout. Everything downstream is a rename plus two semantic changes: the API accepts throws during `OPEN` **and** `LOCK` (rejecting only in `REVEAL`), and the Roblox lockout instant stops being `phaseEndsAt - 2000` and becomes simply the end of `OPEN`.

**Tech Stack:** TypeScript + Express + Socket.io + Vitest (`server/`); Luau + Rojo + a bespoke Lune test harness (`roblox/`); React + Vite (repo root, no tests).

## Global Constraints

- **Phase names are exactly `OPEN`, `LOCK`, `REVEAL`** — uppercase, no other spelling. `TALLY` and `ACTIVE` must not survive anywhere as a phase value.
- **Default durations: `OPEN` 51s, `LOCK` 2s, `REVEAL` 7s** — 60s total, the launch round. **This deviates from the spec's §1, which says `OPEN` 18 for a 27s round.** The spec was written against the test-length round; the owner has since settled on 60s for launch (2026-08-05). `LOCK` and `REVEAL` are unchanged from the spec because neither scales with round length — all of the growth goes to `OPEN`.
- **`REVEAL` is 7s because it is derived, not chosen:** 3.45s drum settle + 3.0s glyph hold + 0.4s fade = 6.85. Do not round it, scale it, or tie it to round length.
- **`LOCK` is 2s** regardless of round length — it is an HTTP flush window, not a fraction of the round.
- **Throw acceptance:** the server API accepts submissions during `OPEN` **and** `LOCK`, and rejects only during `REVEAL`. Getting this backwards closes throws two seconds early for every player.
- **Player input** (the Roblox `submitPick` path) closes at the end of `OPEN`. The API staying open through `LOCK` is what lets game servers flush picks already taken.
- **The wire contract moves in one commit range.** `phase` is consumed by `submitThrow`'s gate, `/throws`'s 409, `RoundCoordinator`, `ChoreographyMachine.phaseCues` and five Roblox client controllers. A mismatch fails silently as a phase nobody recognises.
- **`durations` on `/api/v1/state` is renamed** from `{ activeMs, tallyMs, revealMs }` to `{ openMs, lockMs, revealMs }`.
- Every Luau module under `roblox/src/` is dependency-injected and **never `require`s another module under `src/`** — that is what lets the same files run under Lune and under Roblox. Do not add cross-module requires.
- Run `stylua --check src tests tools && selene src tools` from `roblox/` before every Luau commit. **Selene fails on warnings.**

---

## File Structure

| File | Responsibility | Task |
| --- | --- | --- |
| `roblox/src/shared/HammerCurve.luau` | **DELETE** — dead code | 1 |
| `roblox/tests/HammerCurve.spec.luau` | **DELETE** — tests dead code | 1 |
| `server/src/engine/RoundEngine.ts` | The phase machine; owns `Phase`, durations, world-throw timing | 2 |
| `server/src/index.ts` | Composition root; reads durations from env | 3 |
| `server/src/routes/apiV1.ts` | `/state` durations shape; `/throws` phase gate | 3 |
| `server/src/transports/socketAdapter.ts` | PWA `sync`/`init` `timeLeft` gate | 3 |
| `src/hooks/useGameLoop.ts` | PWA reveal-overlay hold, derived from the wire | 4 |
| `roblox/src/shared/RoundMetronome.luau` | Client timeline; phase derivation, lockout instant | 5 |
| `roblox/src/shared/HudModel.luau` | HUD gates keyed on phase | 6 |
| `roblox/src/shared/ChoreographyMachine.luau` | Phase→effect cue table | 6 |
| `roblox/src/server/RoundCoordinator.luau` | Poll loop, pick gating, flush window, schedule publish | 7 |
| `roblox/src/server/main.server.luau` | Wires `lockoutMs` into the coordinator | 7 |
| `roblox/src/client/main.client.luau` | Client round state machine | 8 |
| `roblox/src/client/HudController.client.luau` | Ring span/known gate | 8 |
| `roblox/src/client/BoardController.client.luau` | Board phase reactions | 8 |
| `roblox/src/client/DrumController.client.luau` | Drum reset on new round | 8 |
| `roblox/src/client/TheaterController.client.luau` | Cue dispatch on phase change | 8 |
| `roblox/src/client/HammerController.client.luau` | Strike reset; stale duration fallbacks | 8 |
| `roblox/src/client/WheelController.client.luau` | Stale comment naming `HammerCurve` | 1 |

---

### Task 1: Delete the dead `HammerCurve` module

`HammerCurve` hardcodes `ACTIVE` and `TALLY` and has a 38-line test suite, so a careless rename would carefully port a module nothing calls. **Nothing requires it at runtime.** `HammerController` is driven by `RoundMetronome`'s `drawP`; its only mention of `HammerCurve` is a stale line-2 comment, and `WheelController` carries a second stale one. Delete it first so no later task has to think about it.

**Files:**
- Delete: `roblox/src/shared/HammerCurve.luau`
- Delete: `roblox/tests/HammerCurve.spec.luau`
- Modify: `roblox/src/client/HammerController.client.luau:2`
- Modify: `roblox/src/client/WheelController.client.luau:5`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing. This task only removes code.

- [ ] **Step 1: Prove nothing requires it**

Run from `roblox/`:

```bash
grep -rn "HammerCurve" src tests tools
```

Expected: exactly four hits — `src/shared/HammerCurve.luau` (the module's own `local HammerCurve = {}`, its `function HammerCurve.state`, and its `return HammerCurve`), `tests/HammerCurve.spec.luau`, plus the two comment lines named above. **No `require(...HammerCurve...)` anywhere.** If you find a real `require`, STOP and report — this task's premise is wrong.

- [ ] **Step 2: Delete the module and its spec**

```bash
git rm src/shared/HammerCurve.luau tests/HammerCurve.spec.luau
```

- [ ] **Step 3: Fix the stale comment in HammerController**

In `roblox/src/client/HammerController.client.luau`, replace line 2:

```lua
-- Animates the placeholder hammer arm from HammerCurve and fires the gong
```

with:

```lua
-- Animates the placeholder hammer arm from the RoundMetronome timeline and fires the gong
```

- [ ] **Step 4: Fix the stale comment in WheelController**

In `roblox/src/client/WheelController.client.luau`, replace line 5:

```lua
-- draw/latch is driven by the clock (HammerCurve), not the wheel's real rotation,
```

with:

```lua
-- draw/latch is driven by the clock (RoundMetronome), not the wheel's real rotation,
```

- [ ] **Step 5: Run the test suite**

Run from `roblox/`: `lune run tests/run`

Expected: PASS, with the total test count **reduced** by however many `HammerCurve.spec.luau` contributed. No failures.

- [ ] **Step 6: Lint and format**

Run from `roblox/`: `stylua --check src tests tools && selene src tools`

Expected: both clean, zero warnings.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor(roblox): delete HammerCurve, which nothing has called since the metronome landed"
```

---

### Task 2: `RoundEngine` — OPEN / LOCK / REVEAL

The phase machine itself. `LOCK` replaces `TALLY`, and the world throw is picked at the **end of `LOCK`** instead of the end of `ACTIVE`. `roundClosed` and `revealStarted` consequently fire on the same transition; `socketAdapter`'s existing `revealPending` guard already handles that ordering (whichever of settlement-completing and reveal-firing lands last performs the emit), so no change is needed there for the race.

**Files:**
- Modify: `server/src/engine/RoundEngine.ts`
- Test: `server/src/engine/RoundEngine.test.ts`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `export type Phase = 'OPEN' | 'LOCK' | 'REVEAL'`
  - `EngineConfig` fields `openSeconds: number`, `lockSeconds: number`, `revealSeconds: number` (replacing `activeSeconds` / `tallySeconds`)
  - `durationsMs(): { openMs: number; lockMs: number; revealMs: number }`
  - `submitThrow` rejects with `'PICKS_CLOSED'` only when `phase === 'REVEAL'`

- [ ] **Step 1: Write the failing tests**

This file already has a `makeEngine(overrides)` helper at the top with `activeSeconds: 3, tallySeconds: 2, revealSeconds: 2`. **Rename its keys to `openSeconds` / `lockSeconds` / `revealSeconds`, keeping the same values**, then add these tests using it. Add a `tickTo` helper next to `makeEngine`:

```typescript
function tickTo(engine: RoundEngine, phase: Phase, maxTicks = 50): void {
    for (let i = 0; i < maxTicks; i++) {
        if (engine.snapshot().phase === phase) return;
        engine.tick();
    }
    throw new Error(`never reached ${phase}`);
}

describe('the phase structure', () => {
    it('reports durations as openMs/lockMs/revealMs', () => {
        expect(makeEngine().durationsMs()).toEqual({ openMs: 3000, lockMs: 2000, revealMs: 2000 });
    });
});

describe('throw acceptance by phase', () => {
    const entry = () => ({ throw: 'R' as const, seq: 1, platform: 'pwa' as const, deviceId: 'd1' });

    it('accepts during OPEN', () => {
        expect(makeEngine().submitThrow('k', entry())).toEqual({ accepted: true });
    });

    it('accepts during LOCK — game servers are still flushing', () => {
        const e = makeEngine();
        tickTo(e, 'LOCK');
        expect(e.submitThrow('k', entry())).toEqual({ accepted: true });
    });

    it('rejects during REVEAL', () => {
        const e = makeEngine();
        tickTo(e, 'REVEAL');
        expect(e.submitThrow('k', entry())).toEqual({ accepted: false, reason: 'PICKS_CLOSED' });
    });
});

describe('the world throw is decided at the end of LOCK', () => {
    it('does not emit roundClosed at the end of OPEN', () => {
        const e = makeEngine();
        const closed: unknown[] = [];
        e.on('roundClosed', ev => closed.push(ev));
        tickTo(e, 'LOCK');
        expect(closed).toHaveLength(0);
    });

    it('emits roundClosed then revealStarted on the same transition', () => {
        const e = makeEngine();
        const order: string[] = [];
        e.on('roundClosed', () => order.push('roundClosed'));
        e.on('revealStarted', () => order.push('revealStarted'));
        tickTo(e, 'REVEAL');
        expect(order).toEqual(['roundClosed', 'revealStarted']);
    });

    it('counts a throw submitted during LOCK', () => {
        const e = makeEngine();
        tickTo(e, 'LOCK');
        e.submitThrow('late', { throw: 'S', seq: 1, platform: 'roblox', robloxUserId: '7' });
        let counts: Record<string, number> | undefined;
        e.on('roundClosed', ev => { counts = ev.counts; });
        tickTo(e, 'REVEAL');
        expect(counts).toEqual({ R: 0, P: 0, S: 1 });
    });
});
```

Also update every pre-existing test in this file that names the old keys or phases. In particular the phase-walk test's expectation becomes:

```typescript
        expect(phases).toEqual(['OPEN', 'OPEN', 'LOCK', 'LOCK', 'REVEAL', 'REVEAL', 'OPEN']);
```

with its comment updated to "3 OPEN ticks (3->2->1->0 transitions on the 3rd), 2 LOCK, 2 REVEAL". Find the rest with:

```bash
grep -n "activeSeconds\|tallySeconds\|'ACTIVE'\|'TALLY'\|activeMs\|tallyMs" server/src/engine/RoundEngine.test.ts
```

There are roughly 20 references. **Note that any existing test asserting `roundClosed` fires at the end of the first phase must move by one transition** — that is the real behaviour change, not a rename.

- [ ] **Step 2: Run the tests to verify they fail**

Run from `server/`: `npx vitest run src/engine/RoundEngine.test.ts`

Expected: FAIL. TypeScript errors on the unknown `openSeconds`/`lockSeconds` config keys, plus assertion failures reporting `'ACTIVE'` where `'OPEN'` was expected.

- [ ] **Step 3: Rename the phase type and config**

In `server/src/engine/RoundEngine.ts`, replace:

```typescript
export type Phase = 'ACTIVE' | 'TALLY' | 'REVEAL';
```

with:

```typescript
// OPEN: throws accepted and changeable — the round as a player experiences it.
// LOCK: player input closed, game servers flush their buffers, the API STILL ACCEPTS.
//       The world throw is decided at the END of LOCK.
// REVEAL: the ceremony. The only phase that rejects throws.
// Named for what happens in them, 2026-08-05. The previous names (ACTIVE/TALLY/REVEAL)
// were offset by one from the events: ACTIVE's last 2s were the lockout, and TALLY
// tallied nothing — the count is a synchronous loop that finishes in microseconds.
export type Phase = 'OPEN' | 'LOCK' | 'REVEAL';
```

In `EngineConfig`, replace:

```typescript
    activeSeconds: number;
    tallySeconds: number;
    revealSeconds: number;
```

with:

```typescript
    openSeconds: number;
    lockSeconds: number;
    // Derived, not chosen: 3.45s drum settle + 3.0s glyph hold + 0.4s fade = 6.85.
    // It does not scale with round length — the drum takes 3.45s at any period.
    revealSeconds: number;
```

- [ ] **Step 4: Rename the constructor and durations**

Replace the constructor body's phase initialisation:

```typescript
    private phase: Phase = 'ACTIVE';
```

with:

```typescript
    private phase: Phase = 'OPEN';
```

Replace in the constructor:

```typescript
        this.secondsLeft = cfg.activeSeconds;
        this.roundCount = initialRoundCount;
        this.roundId = cfg.makeRoundId();
        this.stampPhaseEnd(cfg.activeSeconds);
```

with:

```typescript
        this.secondsLeft = cfg.openSeconds;
        this.roundCount = initialRoundCount;
        this.roundId = cfg.makeRoundId();
        this.stampPhaseEnd(cfg.openSeconds);
```

Replace `durationsMs()` entirely:

```typescript
    durationsMs(): { openMs: number; lockMs: number; revealMs: number } {
        return {
            openMs: this.cfg.openSeconds * 1000,
            lockMs: this.cfg.lockSeconds * 1000,
            revealMs: this.cfg.revealSeconds * 1000,
        };
    }
```

- [ ] **Step 5: Invert the submit gate**

Replace:

```typescript
        if (this.phase !== 'ACTIVE') return { accepted: false, reason: 'PICKS_CLOSED' };
```

with:

```typescript
        // OPEN *and* LOCK. LOCK exists precisely so game servers can flush picks that
        // were already taken before player input closed — rejecting here would discard
        // every held pick in the arena.
        if (this.phase === 'REVEAL') return { accepted: false, reason: 'PICKS_CLOSED' };
```

- [ ] **Step 6: Move the world throw to the end of LOCK**

Replace the whole `if (this.secondsLeft <= 0) { ... }` block inside `tick()`:

```typescript
        if (this.secondsLeft <= 0) {
            if (this.phase === 'OPEN') {
                // Player input closes; the API stays open so game servers can flush.
                // Nothing is decided here.
                this.phase = 'LOCK';
                this.secondsLeft = this.cfg.lockSeconds;
                this.stampPhaseEnd(this.cfg.lockSeconds);
            } else if (this.phase === 'LOCK') {
                // THE ANSWER IS DECIDED HERE, at round close, and REVEAL begins on the
                // same transition. roundClosed is async (settlement); revealStarted is
                // synchronous. socketAdapter's revealPending guard makes whichever
                // finishes last perform the broadcast, so the zero gap is safe.
                const counts = this.countThrows();
                const worldThrow = this.cfg.pickWorldThrow(this.roundCount, counts);
                this.phase = 'REVEAL';
                this.secondsLeft = this.cfg.revealSeconds;
                this.stampPhaseEnd(this.cfg.revealSeconds);
                const event: RoundClosedEvent = {
                    roundId: this.roundId, worldThrow, counts, throws: new Map(this.throws),
                };
                this.emit('roundClosed', event);
                this.emit('revealStarted', { roundId: this.roundId });
            } else {
                this.roundCount++;
                this.roundId = this.cfg.makeRoundId();
                this.throws.clear();
                this.phase = 'OPEN';
                this.secondsLeft = this.cfg.openSeconds;
                this.stampPhaseEnd(this.cfg.openSeconds);
                this.emit('roundStarted', this.snapshot());
            }
        }
```

- [ ] **Step 7: Run the tests to verify they pass**

Run from `server/`: `npx vitest run src/engine/RoundEngine.test.ts`

Expected: PASS, all tests including the new ones.

- [ ] **Step 8: Commit**

```bash
git add server/src/engine/RoundEngine.ts server/src/engine/RoundEngine.test.ts
git commit -m "feat(server): name the phases for what happens in them — OPEN, LOCK, REVEAL"
```

---

### Task 3: Server consumers — env durations, the `/throws` gate, the socket adapter

Three consumers of the engine, plus the durations becoming configurable so a 60s launch round and a short test round differ by env rather than by commit. **The defaults are the launch values**, so a deploy with no env set runs 60-second rounds.

**Files:**
- Modify: `server/src/index.ts:39-53`
- Modify: `server/src/routes/apiV1.ts:84-86`
- Modify: `server/src/transports/socketAdapter.ts:22-23,58-59,111-112`
- Test: `server/src/routes/apiV1.test.ts`
- Test: `server/src/transports/socketAdapter.test.ts`

**Interfaces:**
- Consumes: `Phase = 'OPEN' | 'LOCK' | 'REVEAL'`; `EngineConfig.openSeconds` / `.lockSeconds` / `.revealSeconds`; `durationsMs(): { openMs, lockMs, revealMs }` (Task 2).
- Produces: `/api/v1/state` responds with `durations: { openMs, lockMs, revealMs }` and `phase` one of `OPEN`/`LOCK`/`REVEAL`. Env vars `ROUND_OPEN_SECONDS`, `ROUND_LOCK_SECONDS`, `ROUND_REVEAL_SECONDS`.

- [ ] **Step 1: Write the failing tests**

`server/src/routes/apiV1.test.ts` has `makeApp(engine, store)` and a no-argument `makeEngine()` building `activeSeconds: 20, tallySeconds: 2, revealSeconds: 3`. Give `makeEngine` an overrides parameter and rename its keys:

```typescript
function makeEngine(overrides: Partial<ConstructorParameters<typeof RoundEngine>[0]> = {}) {
    let n = 0;
    return new RoundEngine({
        openSeconds: 20, lockSeconds: 2, revealSeconds: 3,
        pickWorldThrow: () => 'S',
        makeRoundId: () => `round-${++n}`,
        ...overrides,
    });
}
```

Then add these tests. `API_KEY` and the `body()` builder already exist in the `POST /throws` describe block:

```typescript
        it('202 accepts a batch during LOCK — game servers are still flushing', async () => {
            const engine = makeEngine({ openSeconds: 1, lockSeconds: 5 });
            engine.tick(); // OPEN (1s) expires -> LOCK
            expect(engine.snapshot().phase).toBe('LOCK');
            const res = await request(makeApp(engine, new ResultsStore()))
                .post('/api/v1/throws').set('X-API-Key', API_KEY).send(body()).expect(202);
            expect(res.body).toEqual({ accepted: 2, rejected: [] });
        });

        it('409 PICKS_CLOSED during REVEAL', async () => {
            const engine = makeEngine({ openSeconds: 1, lockSeconds: 1, revealSeconds: 5 });
            engine.tick(); // -> LOCK
            engine.tick(); // -> REVEAL
            expect(engine.snapshot().phase).toBe('REVEAL');
            const res = await request(makeApp(engine, new ResultsStore()))
                .post('/api/v1/throws').set('X-API-Key', API_KEY).send(body()).expect(409);
            expect(res.body).toEqual({ error: 'PICKS_CLOSED' });
        });
```

**Note `body()` sends `roundId: 'round-1'`**, which matches `makeEngine`'s first id — so the round-mismatch guard passes and the phase gate is what these tests actually exercise. Do not tick past the end of REVEAL, or the roundId advances and you get a 409 for the wrong reason.

Add to the `GET /state` describe block:

```typescript
        it('names the durations openMs/lockMs/revealMs', async () => {
            const engine = makeEngine({ openSeconds: 51, lockSeconds: 2, revealSeconds: 7 });
            const res = await request(makeApp(engine, new ResultsStore()))
                .get('/api/v1/state').set('X-API-Key', API_KEY).expect(200);
            expect(res.body.durations).toEqual({ openMs: 51000, lockMs: 2000, revealMs: 7000 });
            expect(res.body.phase).toBe('OPEN');
        });
```

`server/src/transports/socketAdapter.test.ts` builds a **real** socket.io client in `beforeEach` against a module-scope `engine` created with `activeSeconds: 2, tallySeconds: 1, revealSeconds: 1`. Rename those keys to `openSeconds: 2, lockSeconds: 1, revealSeconds: 1`, update the existing `phase: 'ACTIVE'` assertions to `'OPEN'`, and add:

```typescript
    it('zeroes timeLeft once OPEN has closed', async () => {
        await initPromise;
        engine.tick(); // 2 -> 1, still OPEN
        const sync = waitFor<any>(client, 'sync');
        engine.tick(); // OPEN expires -> LOCK
        expect(await sync).toMatchObject({ phase: 'LOCK', timeLeft: 0 });
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run from `server/`: `npx vitest run src/routes/apiV1.test.ts src/transports/socketAdapter.test.ts`

Expected: FAIL — the LOCK POST returns 409, and `durations` still reports `activeMs`/`tallyMs`.

- [ ] **Step 3: Make the durations env-driven**

In `server/src/index.ts`, replace the whole `makeEngine` function (lines 39-53, including the multi-line comment about `revealSeconds: 5`, which this supersedes):

```typescript
// Round durations, env-overridable so a short test round and the 60s launch round
// differ by config rather than by commit — a duration edit used to mean a push, and
// a push auto-deploys the dev App Runner service under any live Studio session.
//
// The DEFAULTS ARE THE LAUNCH VALUES: OPEN 51 + LOCK 2 + REVEAL 7 = a 60s round.
// REVEAL's 7 is derived (3.45s drum settle + 3.0s glyph hold + 0.4s fade = 6.85) and
// does not scale with round length; LOCK's 2 is an HTTP flush window, likewise fixed.
// Lengthening a round therefore means lengthening OPEN and nothing else.
function envSeconds(name: string, fallback: number): number {
    const raw = process.env[name];
    if (raw === undefined) return fallback;
    const n = Number(raw);
    if (!Number.isFinite(n) || n <= 0) {
        console.warn(`[SYS] ${name}="${raw}" is not a positive number - using ${fallback}`);
        return fallback;
    }
    return n;
}

function makeEngine(initialRoundCount: number): RoundEngine {
    const openSeconds = envSeconds('ROUND_OPEN_SECONDS', 51);
    const lockSeconds = envSeconds('ROUND_LOCK_SECONDS', 2);
    const revealSeconds = envSeconds('ROUND_REVEAL_SECONDS', 7);
    console.log(`[SYS] round: OPEN ${openSeconds}s / LOCK ${lockSeconds}s / REVEAL ${revealSeconds}s`);
    return new RoundEngine({
        openSeconds,
        lockSeconds,
        revealSeconds,
        pickWorldThrow: roundCount =>
            TEST_MODE ? THROWS[roundCount % 3] : THROWS[Math.floor(Math.random() * 3)],
        makeRoundId: () => Math.random().toString(36).substring(2, 7),
        nowMs: () => Date.now(),
    }, initialRoundCount);
}
```

**Careful:** keep `makeRoundId`'s substring bounds exactly as they are in the current file — copy that line from the existing source rather than from this plan, which may not match.

- [ ] **Step 4: Invert the `/throws` gate**

In `server/src/routes/apiV1.ts`, replace:

```typescript
        if (snap.phase !== 'ACTIVE') {
            res.status(409).json({ error: 'PICKS_CLOSED' });
            return;
        }
```

with:

```typescript
        // REVEAL only. Submissions during LOCK are the whole point of LOCK: player
        // input has closed, but game servers are flushing picks already taken.
        if (snap.phase === 'REVEAL') {
            res.status(409).json({ error: 'PICKS_CLOSED' });
            return;
        }
```

- [ ] **Step 5: Update the socket adapter**

In `server/src/transports/socketAdapter.ts`, replace both occurrences of:

```typescript
            timeLeft: snap.phase === 'ACTIVE' ? snap.secondsLeft : 0,
```

with:

```typescript
            timeLeft: snap.phase === 'OPEN' ? snap.secondsLeft : 0,
```

There are two — one in the `tick` handler (~line 59) and one in the `connection` `init` emit (~line 111). Replace both.

Then replace the comment at line 22-23:

```typescript
    // PWA submits arriving during TALLY/REVEAL are held for the next round
```

with:

```typescript
    // PWA submits arriving during REVEAL are held for the next round
```

Also update the `revealPending` comment block (lines 25-31), replacing:

```typescript
    // roundClosed is async (DB writes); revealStarted is a later tick.
    // In production a full 1s tick separates them so settlement is always done,
    // but if a slow DB ever pushed settlement past the reveal tick the broadcast
    // would be silently lost. These guard against that race: whichever of the two
    // fires last performs the emit.
```

with:

```typescript
    // roundClosed is async (DB writes); revealStarted now fires on the SAME
    // transition, synchronously after it — the gap that used to be a full TALLY
    // tick is zero. That is safe, and always was: these guards make whichever of
    // the two finishes last perform the emit, which is why the two seconds could
    // be deleted without anything else moving.
```

- [ ] **Step 6: Run the full server suite**

Run from `server/`: `npm test`

Expected: PASS, all 211+ tests. Any failure naming `activeMs`, `tallyMs`, `'ACTIVE'` or `'TALLY'` is a test that still needs updating — update it.

- [ ] **Step 7: Typecheck**

Run from `server/`: `npm run build`

Expected: clean compile into `dist/`.

- [ ] **Step 8: Commit**

```bash
git add server/src/index.ts server/src/routes/apiV1.ts server/src/transports/socketAdapter.ts server/src/routes/apiV1.test.ts server/src/transports/socketAdapter.test.ts
git commit -m "feat(server): accept throws through LOCK, and take round durations from env"
```

---

### Task 4: The PWA stops hardcoding the reveal length

The PWA's `GameState` is its **own two-value UI enum** (`'ACTIVE' | 'REVEAL'`) set from which socket event arrived — it never reads the server's `phase` field. So no rename is needed there. What does need fixing is a hardcoded `5000` that holds the result overlay: its own comment records that it already drifted once when the server went 3s → 5s, and REVEAL is now 7s. Put the real number on the wire instead of writing it down twice.

**Files:**
- Modify: `server/src/transports/socketAdapter.ts` (add `revealMs` to the `init` payload)
- Modify: `src/hooks/useGameLoop.ts:317-326`
- Test: `server/src/transports/socketAdapter.test.ts`

**Interfaces:**
- Consumes: `durationsMs(): { openMs, lockMs, revealMs }` (Task 2); the `init` socket event (Task 3).
- Produces: the `init` socket payload gains `revealMs: number`.

- [ ] **Step 1: Write the failing test**

Add to `server/src/transports/socketAdapter.test.ts`:

Add to `server/src/transports/socketAdapter.test.ts`. The `beforeEach` there already captures the `init` emit into `initPromise`, and builds the engine with `revealSeconds: 1`:

```typescript
    it('sends revealMs on init so the client need not hardcode the reveal length', async () => {
        const init = await initPromise;
        expect(init.revealMs).toBe(1000); // revealSeconds: 1 in beforeEach
    });
```

- [ ] **Step 2: Run the test to verify it fails**

Run from `server/`: `npx vitest run src/transports/socketAdapter.test.ts`

Expected: FAIL — `expected undefined to be 7000`.

- [ ] **Step 3: Add `revealMs` to the init payload**

In `server/src/transports/socketAdapter.ts`, in the `io.on('connection', ...)` handler, replace:

```typescript
        socket.emit('init', {
            phase: snap.phase,
            timeLeft: snap.phase === 'OPEN' ? snap.secondsLeft : 0,
            roundCount: snap.roundCount,
            history: store.tape(10),
        });
```

with:

```typescript
        socket.emit('init', {
            phase: snap.phase,
            timeLeft: snap.phase === 'OPEN' ? snap.secondsLeft : 0,
            roundCount: snap.roundCount,
            history: store.tape(10),
            // The reveal's length, so the client's result overlay can hold for exactly
            // as long as the phase lasts. It used to be a literal in useGameLoop.ts and
            // silently went stale when the server changed (3s -> 5s -> 7s).
            revealMs: engine.durationsMs().revealMs,
        });
```

- [ ] **Step 4: Run the test to verify it passes**

Run from `server/`: `npx vitest run src/transports/socketAdapter.test.ts`

Expected: PASS.

- [ ] **Step 5: Consume it in the PWA**

In `src/hooks/useGameLoop.ts`, add a ref alongside the other refs near the top of the hook (place it with the existing `useRef` declarations, around line 13-40):

```typescript
    // Server-reported REVEAL length, arriving on `init`. The fallback matches the
    // server's default (7s) but should never be the number in use.
    const revealMsRef = useRef(7000)
```

In the `socket.on('init', ...)` handler, immediately after `setGameState('ACTIVE')`, add:

```typescript
            if (typeof data.revealMs === 'number') revealMsRef.current = data.revealMs
```

Then replace the overlay-hold block (lines ~318-326):

```typescript
        // TRACKS THE SERVER'S REVEAL PHASE (`revealSeconds` in server/src/index.ts) — the overlay should hold for the whole reveal and hand straight over to the
        // next round, not clear early and leave a "Waiting…" gap. It went 3s → 5s and this literal
        // did not follow, because nothing links them: grep revealSeconds does not reach into this
        // file. If the server's reveal phase changes again, change this with it.
        setTimeout(() => {
            setShowResult(false)
            setHistory(prev => [roundData, ...prev].slice(0, 30))
        }, 5000)
```

with:

```typescript
        // The overlay holds for the whole reveal and hands straight over to the next
        // round, rather than clearing early and leaving a "Waiting…" gap. The length
        // comes off the wire (`revealMs` on init) because the literal that used to live
        // here went stale twice — nothing links a number here to the server's config.
        setTimeout(() => {
            setShowResult(false)
            setHistory(prev => [roundData, ...prev].slice(0, 30))
        }, revealMsRef.current)
```

- [ ] **Step 6: Verify the dependency array**

`handleServerReveal` is wrapped in `useCallback` with deps `[calculateResult, playGongSound]`. `revealMsRef` is a ref, so it must **not** be added — refs are stable and adding one would be wrong. Confirm the deps array is unchanged:

```bash
grep -n "\[calculateResult, playGongSound\]" src/hooks/useGameLoop.ts
```

Expected: one hit, unchanged.

- [ ] **Step 7: Build and lint the frontend**

Run from the repo root (**`nvm use` first** — the shell defaults to an old Node):

```bash
nvm use && npm run build && npm run lint
```

Expected: clean build, zero eslint warnings.

- [ ] **Step 8: Commit**

```bash
git add server/src/transports/socketAdapter.ts server/src/transports/socketAdapter.test.ts src/hooks/useGameLoop.ts
git commit -m "fix(pwa): hold the result overlay for the reveal the server actually has"
```

---

### Task 5: `RoundMetronome` — the client timeline

The client's single source of round position. Three changes: the phase names, the `Schedule` field names, and the lockout — which stops being `openEnd - LOCKOUT_SECONDS` and becomes simply the end of `OPEN`. `RoundMetronome.LOCKOUT_SECONDS` is deleted; the lock duration now comes from the schedule.

**Files:**
- Modify: `roblox/src/shared/RoundMetronome.luau`
- Test: `roblox/tests/RoundMetronome.spec.luau`

**Interfaces:**
- Consumes: `/api/v1/state`'s `durations: { openMs, lockMs, revealMs }` (Task 3), relayed as schedule fields.
- Produces:
  - `Schedule = { roundId: string?, strikeAt: number, periodSec: number, openSec: number, lockSec: number, revealSec: number }`
  - `Reading.phase` is one of `"OPEN"` / `"LOCK"` / `"REVEAL"`
  - `Reading.lockoutIn` is seconds until the end of `OPEN`, and `0` in every other phase
  - `RoundMetronome.LOCKOUT_SECONDS` **no longer exists**

- [ ] **Step 1: Write the failing tests**

This spec's helper is `sched(strikeAt)`, returning a fixed `{ roundId = "r", strikeAt = strikeAt, periodSec = 25, activeSec = 20, tallySec = 2, revealSec = 3 }`. Rename its keys:

```lua
local function sched(strikeAt: number)
    return { roundId = "r", strikeAt = strikeAt, periodSec = 25, openSec = 20, lockSec = 2, revealSec = 3 }
end
```

Note the harness matcher is `toBeCloseTo(expected, eps)` — **the second argument is a tolerance, not decimal places.** Add a launch-shaped helper and these tests:

```lua
    -- A 60s round: OPEN 51 / LOCK 2 / REVEAL 7. The strike is reveal-start, so putting
    -- it at t=53 anchors round start at t=0 and every offset below reads directly.
    local function launchRound()
        local m = RoundMetronome.new()
        m:setSchedule({
            roundId = "r", strikeAt = 53, periodSec = 60,
            openSec = 51, lockSec = 2, revealSec = 7,
        }, 0)
        return m
    end

    test("the phases tile the round: OPEN, LOCK, REVEAL, then OPEN again", function()
        local m = launchRound()
        expect(m:read(0).phase).toBe("OPEN")
        expect(m:read(50.9).phase).toBe("OPEN")
        expect(m:read(51).phase).toBe("LOCK")
        expect(m:read(52.9).phase).toBe("LOCK")
        expect(m:read(53).phase).toBe("REVEAL")
        expect(m:read(59.9).phase).toBe("REVEAL")
        expect(m:read(60).phase).toBe("OPEN")
    end)

    test("lockoutIn counts to the END of OPEN, with no lead subtracted", function()
        local m = launchRound()
        expect(m:read(0).lockoutIn).toBeCloseTo(51, 0.0001)
        expect(m:read(50).lockoutIn).toBeCloseTo(1, 0.0001)
    end)

    test("lockoutIn is zero once OPEN has closed", function()
        local m = launchRound()
        expect(m:read(51).lockoutIn).toBe(0)
        expect(m:read(55).lockoutIn).toBe(0)
    end)

    test("inside OPEN, secondsLeft and lockoutIn are the same number", function()
        local m = launchRound()
        local r = m:read(20)
        expect(r.secondsLeft).toBeCloseTo(r.lockoutIn, 0.0001)
    end)
```

Then delete the test asserting `RoundMetronome.LOCKOUT_SECONDS` and `RoundCoordinator.DEFAULT_LOCKOUT_MS` agree — both constants are going away (Task 7 deletes the second). If that was the file's only use of `RoundCoordinator`, **delete its `require` too**, or selene will flag the unused local:

```bash
grep -n "LOCKOUT_SECONDS\|DEFAULT_LOCKOUT_MS\|RoundCoordinator" roblox/tests/RoundMetronome.spec.luau
```

Update every other test in the file that passes `activeSec`/`tallySec` or asserts `"ACTIVE"`/`"TALLY"`. The existing "maps the timeline" test has a comment reading `-- (active+tally)/period`; change it to `-- (open+lock)/period`.

- [ ] **Step 2: Run the tests to verify they fail**

Run from `roblox/`: `lune run tests/run`

Expected: FAIL — readings report `"ACTIVE"` where `"OPEN"` is expected, and `lockoutIn` is 2 seconds short.

- [ ] **Step 3: Rename the schedule fields and internal state**

In `roblox/src/shared/RoundMetronome.luau`, delete the `LOCKOUT_SECONDS` block entirely — the comment at lines 13-19 **and** the constant:

```lua
-- THE LOCKOUT LEAD, and it lives here because the timeline is the one thing both sides of the
-- game share. Picks close this many seconds before ACTIVE ends (spec §4). RoundCoordinator owned
-- it privately and shipped the client a `secondsToLockout` on each RoundUpdate — which is to say
-- the client learned its own deadline only when a 1-1.25s poll got round to telling it. With the
-- constant here the client derives the same instant off the published schedule, and there is one
-- number rather than two that agree until someone retunes one of them.
RoundMetronome.LOCKOUT_SECONDS = 2
```

Replace it with:

```lua
-- THE LOCKOUT IS NO LONGER A LEAD SUBTRACTED FROM ANYTHING. Picks close when OPEN closes,
-- which the server now publishes as a phase boundary rather than leaving the client to infer
-- it two seconds before the end of a longer phase. `lockoutIn` below is therefore just the
-- time remaining in OPEN, and there is no constant to keep in agreement with anyone.
```

Replace the `Schedule` type:

```lua
export type Schedule = {
    roundId: string?,
    strikeAt: number,
    periodSec: number,
    openSec: number,
    lockSec: number,
    revealSec: number,
}
```

In `RoundMetronome.new()`, replace:

```lua
        _activeSec = 0,
        _tallySec = 0,
        _revealSec = 0,
```

with:

```lua
        _openSec = 0,
        _lockSec = 0,
        _revealSec = 0,
```

In `setSchedule`, replace:

```lua
    self._activeSec = sched.activeSec
    self._tallySec = sched.tallySec
    self._revealSec = sched.revealSec
```

with:

```lua
    self._openSec = sched.openSec
    self._lockSec = sched.lockSec
    self._revealSec = sched.revealSec
```

- [ ] **Step 4: Rename the phase derivation and rebase the lockout**

In `read()`, replace:

```lua
    -- the round containing `now`: starts active+tally before its own strike
    local anchorStart = strike - (self._activeSec + self._tallySec)
```

with:

```lua
    -- the round containing `now`: starts open+lock before its own strike
    local anchorStart = strike - (self._openSec + self._lockSec)
```

Replace the phase block:

```lua
    local elapsed = now - roundStart
    local openEnd = self._openSec
    local lockEnd = openEnd + self._lockSec
    local phase, phaseEndsAt
    if elapsed < openEnd then
        phase, phaseEndsAt = "OPEN", openEnd
    elseif elapsed < lockEnd then
        phase, phaseEndsAt = "LOCK", lockEnd
    else
        phase, phaseEndsAt = "REVEAL", period
    end

    -- The lockout instant, derived rather than delivered. It IS the end of OPEN, so inside
    -- OPEN this equals `secondsLeft`; everywhere else it is zero. Never negative, because
    -- the throw gate is `> 0` and a negative would read as time remaining.
    local lockoutIn = 0
    if phase == "OPEN" then
        lockoutIn = math.max(0, openEnd - elapsed)
    end
```

Leave the half-open-boundary comment above `elapsed` in place — it is still correct and still load-bearing.

- [ ] **Step 5: Run the tests to verify they pass**

Run from `roblox/`: `lune run tests/run`

Expected: `RoundMetronome.spec` PASSES. Other specs may still fail — Tasks 6-8 fix them. If only `RoundMetronome.spec` is green, that is the correct state here.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/RoundMetronome.luau roblox/tests/RoundMetronome.spec.luau
git commit -m "feat(roblox): the metronome's phases are OPEN/LOCK/REVEAL, and the lockout is a boundary"
```

---

### Task 6: `HudModel` and `ChoreographyMachine`

Two pure shared modules whose gates key on the phase string. Both are straight renames — no semantics change.

**Files:**
- Modify: `roblox/src/shared/HudModel.luau:84,156,181`
- Modify: `roblox/src/shared/ChoreographyMachine.luau:13-17`
- Test: `roblox/tests/HudModel.spec.luau`
- Test: `roblox/tests/ChoreographyMachine.spec.luau`

**Interfaces:**
- Consumes: `Reading.phase` values `"OPEN"` / `"LOCK"` / `"REVEAL"` (Task 5).
- Produces: `HudModel.view(inputs, session)` and `HudModel.sendAtLockout(inputs)` both treat `inputs.phase == "OPEN"` as the live round. `ChoreographyMachine.phaseCues("OPEN")` and `("LOCK")` return the cue lists formerly keyed `ACTIVE` and `TALLY`.

- [ ] **Step 1: Write the failing tests**

Add to `roblox/tests/ChoreographyMachine.spec.luau`:

```lua
test("OPEN carries the ambient cues", function()
    expect(ChoreographyMachine.phaseCues("OPEN")).toEqual({
        "lanternsAmbient", "hammerReset", "tickerCountdown",
    })
end)

test("LOCK carries the wind-up cues", function()
    expect(ChoreographyMachine.phaseCues("LOCK")).toEqual({
        "lanternsDim", "drumrollStart", "heroTileSpin", "tickerCascade",
    })
end)

test("the retired names cue nothing", function()
    expect(#ChoreographyMachine.phaseCues("ACTIVE")).toBe(0)
    expect(#ChoreographyMachine.phaseCues("TALLY")).toBe(0)
end)
```

`roblox/tests/HudModel.spec.luau` has an `inputs(over)` builder whose base sets `phase = "ACTIVE"`. **Change that base to `phase = "OPEN"`** — most of the file's tests inherit it and will then pass unchanged. Then add, inside an existing `describe` block:

```lua
    test("throws are enabled in OPEN and in no other phase", function()
        expect(HudModel.view(inputs({ secondsLeft = 10 }), session(0)).throwsEnabled).toBe(true)
        for _, p in { "LOCK", "REVEAL" } do
            local v = HudModel.view(inputs({ phase = p, secondsLeft = 10 }), session(0))
            expect(v.throwsEnabled).toBe(false)
        end
    end)

    test("sendAtLockout releases a held pick the moment OPEN is over", function()
        expect(HudModel.sendAtLockout(inputs({ phase = "LOCK", secondsLeft = 0, chosen = "R" }))).toBe("R")
    end)

    test("sendAtLockout holds while OPEN still has time", function()
        expect(HudModel.sendAtLockout(inputs({ secondsLeft = 10, chosen = "R" }))).toBeNil()
    end)
```

`inputs` and `session(misses)` are this file's existing helpers — use them, do not add new ones. Then find any test that overrides the phase explicitly:

```bash
grep -n '"ACTIVE"\|"TALLY"' roblox/tests/HudModel.spec.luau roblox/tests/ChoreographyMachine.spec.luau
```

and update each.

- [ ] **Step 2: Run the tests to verify they fail**

Run from `roblox/`: `lune run tests/run`

Expected: FAIL — `phaseCues("OPEN")` returns an empty table, and `throwsEnabled` is false for `"OPEN"`.

- [ ] **Step 3: Rename in HudModel**

In `roblox/src/shared/HudModel.luau`, replace line 84:

```lua
    return inputs.phase == "ACTIVE" and inputs.secondsLeft > 0 and not inputs.sent
```

with:

```lua
    return inputs.phase == "OPEN" and inputs.secondsLeft > 0 and not inputs.sent
```

Replace line 156:

```lua
    if inputs.phase ~= "ACTIVE" then
```

with:

```lua
    if inputs.phase ~= "OPEN" then
```

Replace line 181:

```lua
        and inputs.phase == "ACTIVE"
```

with:

```lua
        and inputs.phase == "OPEN"
```

Then fix the three comments in this file that name the old phases. Replace, in the comment above `throwsEnabledFor` (lines 78-82):

```lua
-- Taps stay live for as long as the choice can still be honoured. That is NOT the whole of
-- ACTIVE: it ends the moment the pick goes on the wire (`sendAtLockout`, roughly the last
```

with:

```lua
-- Taps stay live for as long as the choice can still be honoured. That is NOT the whole of
-- OPEN: it ends the moment the pick goes on the wire (`sendAtLockout`, roughly the last
```

And in the `chosen` comment inside `view` (around line 195):

```lua
        -- The choice OUTLIVES the round: after the lockout it is what was thrown, and the tile
        -- stays lit through TALLY/REVEAL saying so. main.client clears it when ACTIVE reopens.
```

with:

```lua
        -- The choice OUTLIVES the round: after the lockout it is what was thrown, and the tile
        -- stays lit through LOCK/REVEAL saying so. main.client clears it when OPEN reopens.
```

- [ ] **Step 4: Rename in ChoreographyMachine**

In `roblox/src/shared/ChoreographyMachine.luau`, replace the cue table:

```lua
local PHASE_CUES: { [string]: { string } } = {
    OPEN = { "lanternsAmbient", "hammerReset", "tickerCountdown" },
    LOCK = { "lanternsDim", "drumrollStart", "heroTileSpin", "tickerCascade" },
    REVEAL = {},
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run from `roblox/`: `lune run tests/run`

Expected: `HudModel.spec` and `ChoreographyMachine.spec` PASS. `RoundCoordinator.spec` may still fail — Task 7 fixes it.

- [ ] **Step 6: Lint and format**

Run from `roblox/`: `stylua --check src tests tools && selene src tools`

Expected: both clean.

- [ ] **Step 7: Commit**

```bash
git add roblox/src/shared/HudModel.luau roblox/src/shared/ChoreographyMachine.luau roblox/tests/HudModel.spec.luau roblox/tests/ChoreographyMachine.spec.luau
git commit -m "feat(roblox): HUD gates and phase cues follow the round's new names"
```

---

### Task 7: `RoundCoordinator` — pick gating, the flush window, the schedule

The Roblox game server. **This task carries the plan's sharpest edge:** picks and flushes need *different* gates. Player input closes at the end of `OPEN`, but the flush must keep working through `LOCK` — that is what `LOCK` is for. Gate them the same way and either players throw two seconds too long or every buffered pick is stranded.

**Files:**
- Modify: `roblox/src/server/RoundCoordinator.luau:2-20,40-41,55,72,113,142,179,222-223,231,247-274`
- Modify: `roblox/src/server/main.server.luau:327`
- Test: `roblox/tests/RoundCoordinator.spec.luau`

**Interfaces:**
- Consumes: `/api/v1/state`'s `phase` (`OPEN`/`LOCK`/`REVEAL`) and `durations: { openMs, lockMs, revealMs }` (Task 3).
- Produces:
  - `submitPick(userId, throwValue)` accepts only in `OPEN`
  - the `onSchedule` callback payload becomes `{ roundId, roundCount, strikeAtMs, periodMs, openMs, lockMs, revealMs }`
  - `RoundCoordinator.DEFAULT_LOCKOUT_MS` and `Deps.lockoutMs` **no longer exist**

- [ ] **Step 1: Write the failing tests**

This spec's helpers are `makeFakes(states, results, opts)` (a *list* of state responses, one consumed per `pollOnce()`), `makeCoordinator(f, callbacks?)`, `okState(roundId, phase, roundCount, phaseEndsAt?)`, and — for the schedule tests — a separate `makeScheduleRig(states)` with `stateOk(over)` and a module-level `DUR`. Note `pollOnce()`, **not** `poll()`, and the schedule rig's clock is offset (`toLocalTime = serverMs - 500`) while `makeFakes`' clock is identity.

Rename `DUR` and `stateOk`'s default phase:

```lua
    local DUR = { openMs = 20000, lockMs = 2000, revealMs = 3000 }
```

with `stateOk`'s `phase = "ACTIVE"` becoming `phase = "OPEN"`. Then add these tests:

```lua
    test("picks are refused once OPEN has closed", function()
        local f = makeFakes({ okState("r1", "OPEN", 1), okState("r1", "LOCK", 1) }, {}, {})
        local c = makeCoordinator(f)
        c:pollOnce()
        expect(select(1, c:submitPick("u1", "R"))).toBe(true)
        c:pollOnce()
        local ok, reason = c:submitPick("u2", "R")
        expect(ok).toBe(false)
        expect(reason).toBe("PICKS_CLOSED")
    end)

    test("the buffer still flushes during LOCK — that is what LOCK is for", function()
        local f = makeFakes({ okState("r1", "OPEN", 1), okState("r1", "LOCK", 1) }, {}, {})
        local c = makeCoordinator(f)
        c:pollOnce()
        c:submitPick("u1", "R")
        local before = #f.postCalls
        c:pollOnce() -- now LOCK
        expect(#f.postCalls).toBe(before + 1)
        expect(f.postCalls[#f.postCalls].throws[1].robloxUserId).toBe("u1")
    end)

    test("the lockout instant is the end of OPEN, with no lead subtracted", function()
        -- makeFakes' clock is identity, so local time == phaseEndsAt.
        local f = makeFakes({ okState("r1", "OPEN", 1, 90000) }, {}, {})
        local c = makeCoordinator(f)
        c:pollOnce()
        expect(c._lockoutAtMs).toBe(90000)
    end)
```

For the reveal fetch, follow whatever the file's existing `_fetchRevealIfDue` tests do — they already prove `TALLY`/`REVEAL` fetch and `ACTIVE` does not; **rename those three phase strings in place** rather than writing a new test.

Add to the schedule-publish describe block:

```lua
    test("the published schedule names the durations openMs/lockMs/revealMs", function()
        local c, schedules = makeScheduleRig({ stateOk({}) })
        c:pollOnce()
        expect(schedules[1].openMs).toBe(20000)
        expect(schedules[1].lockMs).toBe(2000)
        expect(schedules[1].revealMs).toBe(3000)
        -- toLocalTime(100000) = 99500; the strike is reveal-start, so + lockMs 2000
        expect(schedules[1].strikeAtMs).toBe(101500)
        expect(schedules[1].periodMs).toBe(25000)
    end)
```

Then rename in place across the whole file: `okState(..., "ACTIVE", ...)` → `"OPEN"`, `"TALLY"` → `"LOCK"`, the log assertions (`"[ROUND 7] r1 ACTIVE"` → `"[ROUND 7] r1 OPEN"`), and `schedules[1].activeMs` → `.openMs`.

- [ ] **Step 2: Run the tests to verify they fail**

Run from `roblox/`: `lune run tests/run`

Expected: FAIL — picks are accepted during LOCK, nothing flushes during LOCK, `_lockoutAtMs` is 2000 short.

- [ ] **Step 3: Delete the lockout-lead machinery**

In `roblox/src/server/RoundCoordinator.luau`, delete the comment block at lines 9-19 **and** the constant at line 20:

```lua
-- THE LOCKOUT LEAD IS NOT THIS FILE'S ANY MORE. It belongs to RoundMetronome (shared), so the
-- client can derive the same instant off the published timeline instead of waiting to be told it
-- on a RoundUpdate. Modules under src/ are dependency-injected and never require one another —
-- that is what lets the same files run under Lune and under Roblox — so main.server.luau reads
-- RoundMetronome.LOCKOUT_SECONDS and hands it in as `deps.lockoutMs`; at runtime the Roblox
-- server and every client are reading ONE number.
--
-- The value below is only the fallback the Lune tests construct against (they build Deps by hand
-- and there is no ReplicatedStorage to require through). RoundMetronome.spec asserts the two
-- agree, so a retune of the shared constant cannot leave this suite testing a lockout the game no
-- longer has.
RoundCoordinator.DEFAULT_LOCKOUT_MS = 2000
```

Replace with:

```lua
-- THERE IS NO LOCKOUT LEAD ANY MORE. Picks close when OPEN closes — a phase boundary the
-- server publishes — so the instant is read off `phaseEndsAt` rather than computed by
-- subtracting a constant that two files had to agree on.
```

Delete the `lockoutMs` field from the `Deps` type (lines 40-41):

```lua
    -- Lune tests can build Deps without it; see DEFAULT_LOCKOUT_MS above.
    lockoutMs: number?,
```

Delete the initialiser at line 55:

```lua
        _lockoutMs = deps.lockoutMs or RoundCoordinator.DEFAULT_LOCKOUT_MS,
```

Update the file header comment at line 3, replacing:

```lua
-- picks until the T0-2s lockout (spec §4), delta-flushes throws (5s cadence /
```

with:

```lua
-- picks until OPEN closes, delta-flushes throws (5s cadence /
```

And line 5, replacing:

```lua
-- and reconciles authoritative per-player results on the next ACTIVE.
```

with:

```lua
-- and reconciles authoritative per-player results on the next OPEN.
```

- [ ] **Step 4: Gate picks on OPEN only**

Replace line 72 in `submitPick`:

```lua
    if self._phase ~= "ACTIVE" or self._picksClosed then
```

with:

```lua
    -- OPEN ONLY. This is the asymmetry that makes LOCK work: player input ends here,
    -- while _maybeFlush below keeps posting through LOCK so the picks already taken
    -- reach the server. Gating both the same way either lets players throw two seconds
    -- past the deadline or strands every buffered pick.
    if self._phase ~= "OPEN" or self._picksClosed then
```

- [ ] **Step 5: Let the flush run through LOCK**

Replace line 113 in `_maybeFlush`:

```lua
    if self._phase ~= "ACTIVE" or self._picksClosed then
```

with:

```lua
    if (self._phase ~= "OPEN" and self._phase ~= "LOCK") or self._picksClosed then
```

- [ ] **Step 6: Rename the remaining phase reads**

Replace line 142 in `_fetchRevealIfDue`:

```lua
    if not (state.phase == "TALLY" or state.phase == "REVEAL") or self._resultLogged then
```

with:

```lua
    if not (state.phase == "LOCK" or state.phase == "REVEAL") or self._resultLogged then
```

Replace line 179 in `_reconcileIfDue`:

```lua
    if not self._pendingReconcileRoundId or self._phase ~= "ACTIVE" then
```

with:

```lua
    if not self._pendingReconcileRoundId or self._phase ~= "OPEN" then
```

- [ ] **Step 7: Rebase the lockout instant on the end of OPEN**

Replace lines 222-223:

```lua
    if state.phase == "ACTIVE" and d.clock:hasSync() then
        self._lockoutAtMs = d.clock:toLocalTime(state.phaseEndsAt) - self._lockoutMs
    end
```

with:

```lua
    -- The lockout IS the end of OPEN. Same wall-clock instant it always was — OPEN's
    -- duration is what ACTIVE's was minus the two seconds that are now LOCK — but read
    -- off the schedule instead of inferred from it.
    if state.phase == "OPEN" and d.clock:hasSync() then
        self._lockoutAtMs = d.clock:toLocalTime(state.phaseEndsAt)
    end
```

Replace line 231:

```lua
            if state.phase == "ACTIVE" and self._lockoutAtMs then
```

with:

```lua
            if state.phase == "OPEN" and self._lockoutAtMs then
```

- [ ] **Step 8: Rename the schedule publish**

Replace the schedule block (lines 245-274), keeping its structure:

```lua
    -- Publish the round's absolute schedule (round-metronome spec): the strike is
    -- reveal start = end of OPEN + the whole of LOCK. Republish on roundId change or
    -- when sync refinement moves the strike > 150ms; clients slew, so small edits are cheap.
    local dur = state.durations
    if dur and d.clock:hasSync() then
        local endLocal = d.clock:toLocalTime(state.phaseEndsAt)
        local strikeAtMs
        if state.phase == "OPEN" then
            strikeAtMs = endLocal + dur.lockMs
        elseif state.phase == "LOCK" then
            strikeAtMs = endLocal
        else -- REVEAL: the NEXT round's strike
            strikeAtMs = endLocal + dur.openMs + dur.lockMs
        end
        if
            self._publishedStrikeMs == nil
            or self._publishedRoundId ~= state.roundId
            or math.abs(strikeAtMs - self._publishedStrikeMs) > 150
        then
            self._publishedStrikeMs = strikeAtMs
            self._publishedRoundId = state.roundId
            if d.callbacks and d.callbacks.onSchedule then
                d.callbacks.onSchedule({
                    roundId = state.roundId,
                    roundCount = state.roundCount,
                    strikeAtMs = strikeAtMs,
                    periodMs = dur.openMs + dur.lockMs + dur.revealMs,
                    openMs = dur.openMs,
                    lockMs = dur.lockMs,
                    revealMs = dur.revealMs,
                })
            end
        end
    end
```

- [ ] **Step 9: Drop `lockoutMs` from the server entry**

In `roblox/src/server/main.server.luau`, delete line 327:

```lua
    lockoutMs = RoundMetronome.LOCKOUT_SECONDS * 1000,
```

Then check whether `RoundMetronome` is still required by that file for anything else:

```bash
grep -n "RoundMetronome" roblox/src/server/main.server.luau
```

If that line was its only use, delete the `require` too. If other uses remain, leave it.

- [ ] **Step 10: Rename the schedule attributes the server publishes**

`main.server.luau:375-378` is the **only writer** of the stage attributes every client reads. Replace:

```lua
            roundScheduleConfig:SetAttribute("PeriodSec", s.periodMs / 1000)
            roundScheduleConfig:SetAttribute("ActiveSec", s.activeMs / 1000)
            roundScheduleConfig:SetAttribute("TallySec", s.tallyMs / 1000)
            roundScheduleConfig:SetAttribute("RevealSec", s.revealMs / 1000)
```

with:

```lua
            roundScheduleConfig:SetAttribute("PeriodSec", s.periodMs / 1000)
            roundScheduleConfig:SetAttribute("OpenSec", s.openMs / 1000)
            roundScheduleConfig:SetAttribute("LockSec", s.lockMs / 1000)
            roundScheduleConfig:SetAttribute("RevealSec", s.revealMs / 1000)
```

**Leave the `StrikeAtServerTime` write last** — the comment on line 379 records why (clients pull the whole schedule on its change signal, so it must be written after everything it announces).

Also update the comment at line 340, replacing `DrumStep.SETTLE_SECONDS + TallySec` with `DrumStep.SETTLE_SECONDS + LockSec`.

**A stale attribute does not error — it reads `nil` and silently falls back.** Task 8 renames every reader; if this step lands without it, the clients quietly run on their hardcoded defaults.

- [ ] **Step 11: Run the tests to verify they pass**

Run from `roblox/`: `lune run tests/run`

Expected: PASS — the whole Luau suite, since Task 8's files carry no tests.

- [ ] **Step 12: Lint and format**

Run from `roblox/`: `stylua --check src tests tools && selene src tools`

Expected: both clean, zero warnings.

- [ ] **Step 13: Commit**

```bash
git add roblox/src/server/RoundCoordinator.luau roblox/src/server/main.server.luau roblox/tests/RoundCoordinator.spec.luau
git commit -m "feat(roblox): picks close with OPEN, flushes run through LOCK"
```

---

### Task 8: The Roblox client

Six client files. **None of them are covered by any test** — `lune run tests/run` never loads a `.client.luau`, `selene` does not resolve cross-module field types, and `stylua` only formats. A wrong phase string here compiles, lints, passes CI, and fails silently in Studio as a phase nobody recognises. Read every hit before changing it.

**Files:**
- Modify: `roblox/src/client/main.client.luau` (many; enumerate with grep)
- Modify: `roblox/src/client/HudController.client.luau:1711,1719`
- Modify: `roblox/src/client/BoardController.client.luau:153,155`
- Modify: `roblox/src/client/DrumController.client.luau:209`
- Modify: `roblox/src/client/TheaterController.client.luau:193`
- Modify: `roblox/src/client/HammerController.client.luau:33-37,218-223,297,409`

**Interfaces:**
- Consumes: `Reading.phase` / `Reading.lockoutIn` (Task 5); `HudModel.view` / `.sendAtLockout` keyed on `"OPEN"` (Task 6); the `onSchedule` payload `{ roundId, roundCount, strikeAtMs, periodMs, openMs, lockMs, revealMs }` and the `RoundUpdate` `phase` field (Task 7).
- Produces: nothing consumed by a later task — this is the last one.

- [ ] **Step 1: Enumerate every phase literal in the client**

Run from `roblox/`:

```bash
grep -rn '"ACTIVE"\|"TALLY"' src/client/
```

Record the full list. Every hit must be gone by the end of this task. Note that hits fall into two kinds — **code** (a comparison) and **prose** (a comment naming a phase) — and both need changing, because the comments in `main.client.luau` are the only documentation this logic has.

- [ ] **Step 2: Rename the schedule attributes in HammerController**

In `roblox/src/client/HammerController.client.luau`, replace the schedule pull (lines 33-37):

```lua
        activeSec = (scheduleConfig:GetAttribute("ActiveSec") :: number?) or 20,
        tallySec = (scheduleConfig:GetAttribute("TallySec") :: number?) or 2,
        -- Fallbacks mirror the server's configured phase durations (server/src/index.ts); only
        -- used until the first schedule attributes replicate, but a stale one is a wrong schedule.
        revealSec = (scheduleConfig:GetAttribute("RevealSec") :: number?) or 5,
```

with:

```lua
        openSec = (scheduleConfig:GetAttribute("OpenSec") :: number?) or 51,
        lockSec = (scheduleConfig:GetAttribute("LockSec") :: number?) or 2,
        -- Fallbacks mirror the server's DEFAULT phase durations (server/src/index.ts, now
        -- env-overridable); only used until the first schedule attributes replicate, but a
        -- stale one is a wrong schedule — it put the strike on the wrong part of the cam once.
        revealSec = (scheduleConfig:GetAttribute("RevealSec") :: number?) or 7,
```

Replace the cam-geometry block (lines 216-224):

```lua
        -- The PERIOD default is derived from the three phase defaults rather than
        -- written out: it said 25 against a 20+2+5 = 27s round, and a stale period
        -- skews where the strike lands until the first attributes replicate.
        local openSec = (scheduleConfig:GetAttribute("OpenSec") :: number?) or 51
        local lockSec = (scheduleConfig:GetAttribute("LockSec") :: number?) or 2
        local revealSec = (scheduleConfig:GetAttribute("RevealSec") :: number?) or 7
        local periodSec = (scheduleConfig:GetAttribute("PeriodSec") :: number?)
            or (openSec + lockSec + revealSec)
        local strikeP = (openSec + lockSec) / periodSec
```

Replace line 297:

```lua
    if info.phase == "ACTIVE" then
```

with:

```lua
    if info.phase == "OPEN" then
```

Replace the comment at line 409:

```lua
    -- Self-timed backstop: RoundUpdate("ACTIVE") normally clears `striking`, but a
```

with:

```lua
    -- Self-timed backstop: RoundUpdate("OPEN") normally clears `striking`, but a
```

- [ ] **Step 3: Rename the attribute reads in the other two clients**

Task 7 renamed the **writer** (`main.server.luau`). `HammerController` is done above. Two more clients read these attributes, and a missed one reads `nil` and silently falls back to a hardcoded default — no error, no warning.

`roblox/src/client/main.client.luau` has its own `pullSchedule` at lines 296-309, duplicating HammerController's. Replace lines 305-309:

```lua
            activeSec = (scheduleConfig:GetAttribute("ActiveSec") :: number?) or 20,
            tallySec = (scheduleConfig:GetAttribute("TallySec") :: number?) or 2,
```

and its `revealSec` fallback, with:

```lua
            openSec = (scheduleConfig:GetAttribute("OpenSec") :: number?) or 51,
            lockSec = (scheduleConfig:GetAttribute("LockSec") :: number?) or 2,
```

and `revealSec = (scheduleConfig:GetAttribute("RevealSec") :: number?) or 7,`. Keep the comment between them, updated to say the fallbacks mirror the server's **defaults**, which are now env-overridable.

`roblox/src/client/main.client.luau:88` and `roblox/src/client/TheaterController.client.luau:136` each read `TallySec` into a local named `tally`:

```lua
    local tally = if cfg then cfg:GetAttribute("TallySec") else nil
```

Replace both with:

```lua
    local lock = if cfg then cfg:GetAttribute("LockSec") else nil
```

and rename the local's uses in the lines that follow. Update the comments above them (`main.client.luau:83`, `TheaterController.client.luau:131`), which read "the strike is scheduled TallySec after ACTIVE ends" — it is now "scheduled LockSec after OPEN ends". The meaning and the value are unchanged; only the names move.

- [ ] **Step 3a: Verify no attribute name is left behind**

```bash
grep -rn "ActiveSec\|TallySec" roblox/src/
```

Expected: **no output.**

- [ ] **Step 4: Rename the four single-line controller hits**

`roblox/src/client/HudController.client.luau` lines 1711 and 1719 — replace both `inputs.phase == "ACTIVE"` with `inputs.phase == "OPEN"`.

`roblox/src/client/DrumController.client.luau` line 209 — replace `info.phase == "ACTIVE"` with `info.phase == "OPEN"`.

`roblox/src/client/TheaterController.client.luau` line 193 — replace `info.phase == "ACTIVE"` with `info.phase == "OPEN"`.

`roblox/src/client/BoardController.client.luau` lines 153-155 — replace:

```lua
    if info.phase == "ACTIVE" then
```

with `if info.phase == "OPEN" then`, and:

```lua
    elseif info.phase == "TALLY" then
```

with `elseif info.phase == "LOCK" then`.

- [ ] **Step 5: Rename in main.client.luau**

Work through the list from Step 1. The **code** changes are:

- Line ~339-344, in the one writer of `phase` / `localPhase` / `lockoutAt`:

```lua
        lockoutAt = if reading.phase == "OPEN" then os.clock() + reading.lockoutIn else nil
```

- Line ~366, in `secondsLeft()`:

```lua
    if phase ~= "OPEN" then
```

- Lines ~434-438, in `throwPhase()`:

```lua
local function throwPhase(): string
    if localPhase == "OPEN" and serverPhase ~= "OPEN" then
        return serverPhase
```

Keep the rest of that function exactly as it is.

- Line ~818 and its surroundings: the `serverPhase` edge detection. Replace any `"ACTIVE"` comparison with `"OPEN"`.

Then run the grep from Step 1 again and change every remaining **prose** hit — the comments at lines ~82, 84, 104, 157-167, 192, 318-325, 348, 356, 402-434, 561, 563, 590, 654-683, 795, 818-822. These describe the logic in terms of phase names; leaving them stale is how the next reader gets it wrong. Two need more than a word swap:

Line ~82-84:

```lua
-- can land as early as the start of LOCK (RoundCoordinator fetches on LOCK as well as REVEAL)
```

Line ~679-680:

```lua
        -- or more BEFORE the strike (RoundCoordinator:_fetchRevealIfDue accepts LOCK as well as
        -- REVEAL), so a window measured from its arrival is measured from an event with no fixed
```

- [ ] **Step 6: Verify no phase literal survives**

Run from `roblox/`:

```bash
grep -rn '"ACTIVE"\|"TALLY"\|ActiveSec\|TallySec\|activeMs\|tallyMs\|activeSec\|tallySec' src/ tests/
```

Expected: **no output at all.** Any hit is an unfinished rename.

- [ ] **Step 7: Run the full Luau suite, lint and format**

Run from `roblox/`:

```bash
lune run tests/run && stylua --check src tests tools && selene src tools
```

Expected: all tests PASS, stylua clean, selene zero warnings.

- [ ] **Step 8: Commit**

```bash
git add roblox/src/client/
git commit -m "feat(roblox): the client speaks OPEN, LOCK and REVEAL"
```

- [ ] **Step 9: Run every gate across all three codebases**

```bash
cd server && npm test && npm run build && cd ..
cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools && cd ..
nvm use && npm run build && npm run lint
```

Expected: green everywhere.

---

## The Studio gate

**This plan is not finished when the tests are green.** No automated gate in this repo can see the Roblox UI: `lune run tests/run` never loads a `.client.luau`, `selene` does not resolve cross-module field types, and `stylua` only formats. Everything in Task 8 is unverified until someone watches it.

**Pushing is what deploys.** `roshambo_server_dev` auto-deploys every push to `m4b-zendojo-art-pass`, and this branch now changes the round's phase names *and* its length. Push server and client together, re-sync Rojo in the same sitting, and expect the round to become 60 seconds the moment the deploy lands.

Hand the owner this checklist:

1. **Throws open on time and close on time.** The ring should count 51 down to 0, and the throw buttons should go dead exactly as it reaches 0 — not before, not two seconds after.
2. **A pick taken in the last second still counts.** Tap at ~1s remaining; the result toast must agree with what was tapped. This is the flush-through-`LOCK` path, and it is the one thing a wrong gate breaks silently.
3. **The bell rings at round close** — two seconds earlier in the round's shape than it used to, since the bell now lands at the `LOCK`→`REVEAL` boundary rather than after a `TALLY` pause. The bell engine was signed off with that pause in it.
4. **The glyph appears when the drum comes to rest**, holds ~3s, fades, and the tape tile lands after it — all now *inside* `REVEAL` rather than spilling across the round boundary.
5. **The cam turns visibly slower.** ω = 2π/period, so at 60s the snail cam runs at 1 rpm against roughly 2.2 before, while the waterwheels keep their fixed speed. Nothing is broken if it looks wrong — but whether the mechanism still reads as *the wheel drives the bell* is a judgement only the owner can make.
6. **The PWA's result overlay holds for the whole reveal** and hands straight to the next round, with no "Waiting…" gap.

Items 1, 2 and 4 are correctness. Items 3 and 5 are taste, and may send Stage 4 somewhere this plan does not anticipate.
