### Task 7: Composition root — wire config → crowd → engine, and the per-round log

**Files:**
- Modify: `server/src/index.ts` (imports; `makeEngine` ~line 66-95; the `.then` block ~line 119-124)

**Interfaces:**
- Consumes: Task 4 `readCrowdConfig`; Task 3 `createCrowd`, `formatMix`; Task 1 `mulberry32`, `randomSeed`; Task 5 `CrowdSource`, `RoundClosedEvent`.
- Produces: nothing new; behaviour only.

There is no test harness for `index.ts` (it connects to Mongo on import); the pieces it composes are all tested in Tasks 1–6. Verification here is the boot log.

- [ ] **Step 1: Add the imports**

```ts
import { RoundEngine, CrowdSource, RoundClosedEvent } from './engine/RoundEngine';
import { readCrowdConfig } from './crowdConfig';
import { createCrowd, formatMix } from './engine/SyntheticCrowd';
import { mulberry32, randomSeed } from './engine/Prng';
```

(Replace the existing `import { RoundEngine } from './engine/RoundEngine';` line.)

- [ ] **Step 2: Build the crowd from env, right after `const TEST_MODE = …`**

```ts
// The synthetic crowd (spec §5). Refuses to boot on a malformed value, like MONGODB_URI does:
// a crowd that silently fell back to defaults would run an experiment nobody configured.
const crowdConfig = readCrowdConfig(process.env, {
    testMode: TEST_MODE,
    log: msg => console.warn(msg),
    randomSeed,
});
const crowd: CrowdSource | undefined = crowdConfig
    ? createCrowd({ size: crowdConfig.size, mix: crowdConfig.mix, rng: mulberry32(crowdConfig.seed) })
    : undefined;
console.log(crowdConfig
    ? `[CROWD] on: size ${crowdConfig.size}, seed ${crowdConfig.seed}, mix ${formatMix(crowdConfig.mix)}`
    : '[CROWD] off');
```

- [ ] **Step 3: Pass it into the engine**

In `makeEngine`, add `crowd,` to the `new RoundEngine({ … })` config object, after `pickWorldThrow`. The function closes over the module-level `crowd`; its signature is unchanged.

- [ ] **Step 4: Log each round the crowd took part in**

Immediately after `const engine = makeEngine(totalRounds, cycleShift);`:

```ts
        if (crowd) {
            // One line per round so a Studio session can read what the world did (spec §5).
            engine.on('roundClosed', (e: RoundClosedEvent) => {
                const bots = e.crowdCounts.R + e.crowdCounts.P + e.crowdCounts.S;
                console.log(`[CROWD] round ${e.roundId} humans ${e.throws.size} crowd ${bots} | R ${e.counts.R} P ${e.counts.P} S ${e.counts.S} → ${e.worldThrow}`);
            });
        }
```

- [ ] **Step 5: Type-check and run the suite**

Run: `npx tsc --noEmit && npm test`
Expected: clean, PASS.

- [ ] **Step 6: Boot-log check without a database**

The server exits before listening when `MONGODB_URI` is empty, but the crowd lines print first (the config is read before the fatal check, and `dotenv` does not override a variable that is already set, even to the empty string). Run:

```bash
npx tsc && (MONGODB_URI= TEST_MODE=false CROWD_SIZE=30 CROWD_SEED=1 node dist/index.js; true)
```

Expected output includes `[CROWD] on: size 30, seed 1, mix wsls:35,counter:20,conform:15,rocky:10,random:20` then `[FATAL] MONGODB_URI is not defined`. Then:

```bash
(MONGODB_URI= TEST_MODE=true CROWD_SIZE=30 node dist/index.js; true)
```

Expected: the `TEST_MODE cycles the World Throw` warning and `[CROWD] off`. And:

```bash
(MONGODB_URI= TEST_MODE=false CROWD_SIZE=5 CROWD_MIX=ninja:1 node dist/index.js; true)
```

Expected: the process throws `CROWD_MIX: unknown archetype "ninja" …` and exits non-zero.

- [ ] **Step 7: Commit**

```bash
git add src/index.ts
git commit -m "feat(server): wire the synthetic crowd from env into the engine; one [CROWD] line per round

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

