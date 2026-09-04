### Task 5: The engine merge

**Files:**
- Modify: `server/src/engine/RoundEngine.ts` (`EngineConfig` ~line 22-37, `RoundClosedEvent` ~line 47-52, the LOCK→REVEAL branch ~line 125-139)
- Test: `server/src/engine/RoundEngine.test.ts` (append a `describe`)

**Interfaces:**
- Consumes: nothing from the crowd module directly — the engine takes a structural `CrowdSource` so it stays free of the crowd's internals.
- Produces:
  - `export interface CrowdSource { throws(roundCount: number): Record<Throw, number>; observe(worldThrow: Throw): void }` (Task 3's `Crowd` satisfies it).
  - `EngineConfig.crowd?: CrowdSource`.
  - `RoundClosedEvent.crowdCounts: Record<Throw, number>` (zeros when no crowd). `counts` now = human + crowd.

- [ ] **Step 1: Write the failing test**

Append to `server/src/engine/RoundEngine.test.ts`:

```ts
describe('the synthetic crowd merges into the tally at round close (spec §1)', () => {
    const human = (t: 'R' | 'P' | 'S') => ({ throw: t, seq: 1, platform: 'pwa' as const, deviceId: `d-${t}` });

    function fakeCrowd(counts: { R: number; P: number; S: number }) {
        const throws = vi.fn(() => counts);
        const observe = vi.fn();
        return { throws, observe };
    }

    it('pickWorldThrow sees human + crowd counts, and roundClosed carries both', () => {
        const crowd = fakeCrowd({ R: 10, P: 3, S: 0 });
        const picker = vi.fn(() => 'R' as const);
        const e = makeEngine({ pickWorldThrow: picker, crowd });
        const closed: any[] = [];
        e.on('roundClosed', ev => closed.push(ev));

        e.submitThrow('pwa:a', human('P'));
        e.submitThrow('pwa:b', human('S'));
        for (let i = 0; i < 5; i++) e.tick();

        expect(crowd.throws).toHaveBeenCalledWith(0);
        expect(picker).toHaveBeenCalledWith(0, { R: 10, P: 4, S: 1 });
        expect(closed).toHaveLength(1);
        expect(closed[0].counts).toEqual({ R: 10, P: 4, S: 1 });
        expect(closed[0].crowdCounts).toEqual({ R: 10, P: 3, S: 0 });
    });

    it('the throws map stays human-only — bots never reach settlement', () => {
        const e = makeEngine({ crowd: fakeCrowd({ R: 10, P: 3, S: 0 }) });
        const closed: any[] = [];
        e.on('roundClosed', ev => closed.push(ev));
        e.submitThrow('pwa:a', human('P'));
        for (let i = 0; i < 5; i++) e.tick();
        expect(closed[0].throws.size).toBe(1);
        expect([...closed[0].throws.keys()]).toEqual(['pwa:a']);
    });

    it('observe() receives the DECIDED World Throw, after the picker ran', () => {
        const crowd = fakeCrowd({ R: 0, P: 5, S: 0 });
        const e = makeEngine({ pickWorldThrow: () => 'S', crowd });
        for (let i = 0; i < 5; i++) e.tick();
        expect(crowd.observe).toHaveBeenCalledExactlyOnceWith('S');
        expect(crowd.throws.mock.invocationCallOrder[0]).toBeLessThan(crowd.observe.mock.invocationCallOrder[0]);
    });

    it('without a crowd, crowdCounts is zeros and counts are the humans alone', () => {
        const e = makeEngine();
        const closed: any[] = [];
        e.on('roundClosed', ev => closed.push(ev));
        e.submitThrow('pwa:a', human('R'));
        for (let i = 0; i < 5; i++) e.tick();
        expect(closed[0].counts).toEqual({ R: 1, P: 0, S: 0 });
        expect(closed[0].crowdCounts).toEqual({ R: 0, P: 0, S: 0 });
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/engine/RoundEngine.test.ts`
Expected: the four new tests FAIL (picker sees `{R:0,P:1,S:1}`; `crowdCounts` undefined). The existing tests still pass.

- [ ] **Step 3: Write minimal implementation**

In `server/src/engine/RoundEngine.ts`, add after the `ThrowEntry` interface:

```ts
// The synthetic crowd (spec §1). Structural on purpose: the engine needs "give me this round's
// bot tally" and "here is what the world did", nothing about archetypes or seeds.
export interface CrowdSource {
    throws(roundCount: number): Record<Throw, number>;
    observe(worldThrow: Throw): void;
}
```

Add to `EngineConfig`, after `pickWorldThrow`:

```ts
    // Optional bot crowd merged into the tally BEFORE pickWorldThrow, so the distribution the
    // player sees and the World Throw it produced always agree. Absent → today's behaviour.
    crowd?: CrowdSource;
```

Change `RoundClosedEvent`:

```ts
export interface RoundClosedEvent {
    roundId: string;
    worldThrow: Throw;
    counts: Record<Throw, number>;       // human + crowd: the world the player faced
    crowdCounts: Record<Throw, number>;  // the synthetic part of it, zeros when no crowd
    throws: Map<string, ThrowEntry>;     // humans only — the only thing settlement iterates
}
```

Replace the LOCK→REVEAL branch body (currently `const counts = this.countThrows(); const worldThrow = ...` through the `roundClosed` emit) with:

```ts
                // THE ANSWER IS DECIDED HERE, at round close, and REVEAL begins on the
                // same transition. roundClosed is async (settlement); revealStarted is
                // synchronous. socketAdapter's revealPending guard makes whichever
                // finishes last perform the broadcast, so the zero gap is safe.
                //
                // The crowd merges here and NOT inside pickWorldThrow: settlement builds the
                // persisted distribution from `counts`, so bots added in the picker would decide
                // the World Throw and then vanish from the card that explains it (spec §1).
                const humanCounts = this.countThrows();
                const crowdCounts = this.cfg.crowd ? this.cfg.crowd.throws(this.roundCount) : { R: 0, P: 0, S: 0 };
                const counts: Record<Throw, number> = {
                    R: humanCounts.R + crowdCounts.R,
                    P: humanCounts.P + crowdCounts.P,
                    S: humanCounts.S + crowdCounts.S,
                };
                const worldThrow = this.cfg.pickWorldThrow(this.roundCount, counts);
                this.cfg.crowd?.observe(worldThrow);
                this.phase = 'REVEAL';
                this.secondsLeft = this.cfg.revealSeconds;
                this.stampPhaseEnd(this.cfg.revealSeconds);
                const event: RoundClosedEvent = {
                    roundId: this.roundId, worldThrow, counts, crowdCounts, throws: new Map(this.throws),
                };
                this.emit('roundClosed', event);
                this.emit('revealStarted', { roundId: this.roundId });
```

- [ ] **Step 4: Run the whole suite**

Run: `npm test`
Expected: PASS. (`RoundToSettle` does not yet know `crowdCounts`, but `settleRound({ ...data, timestamp })` in `socketAdapter` passes an object with an extra property through a spread, which TypeScript allows. Task 6 adds the field.)

- [ ] **Step 5: Commit**

```bash
git add src/engine/RoundEngine.ts src/engine/RoundEngine.test.ts
git commit -m "feat(engine): merge the synthetic crowd into the tally at LOCK->REVEAL, before the World Throw is picked

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

