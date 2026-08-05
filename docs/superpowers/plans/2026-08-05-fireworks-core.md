# Fireworks Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship four firework shells, three mortar tubes, a real consumable inventory bought with points and granted on wins, launched from your own deck or a tagged public site, rendered inside a mobile particle budget.

**Architecture:** The AWS server owns the ledger (ids, prices, requirements, what you hold) and is authoritative for every number. The Roblox game server is the referee — it validates the launch site, spends the shell against AWS, and only then broadcasts a tiny event. Every client renders the burst locally from its own catalog of recipes. The two halves meet at one string, gated by `shared-fixtures/firework-shells.json`.

**Tech Stack:** TypeScript + Express + Mongoose + Vitest (`server/`); Luau + Rojo + a bespoke Lune harness (`roblox/`); React + Vite + Vitest (repo root, not touched by this plan).

**Spec:** `docs/superpowers/specs/2026-08-05-fireworks-core-design.md`

## Global Constraints

- **Fireworks must never touch the RPS loop.** A shell may *read* the round's outcome; it must never influence one. This is what makes fireworks a safe first paid item.
- **The client never evaluates a requirement.** The server sends `{ count, launchable, reason }` per shell. The client renders `reason`; it does not know what a mortar is and does not read the tape.
- **Shell ids are exactly:** `firecracker`, `peony`, `willow`, `ishibana`.
- **Tube ids are exactly:** `mortar:S`, `mortar:M`, `mortar:L`.
- **Shell prices:** `firecracker` 1, `peony` 3, `willow` 4, `ishibana` 6. **Tube prices:** S 40, M 250, L 1000.
- **Requirements:** `firecracker` none; `peony` needs `mortar:S`; `willow` needs `mortar:M`; `ishibana` needs the last closed round's world throw to be `R`.
- **Gear is personal.** Public launch sites do NOT supply tubes.
- **Spending must be a conditional `$inc`**, never `read → modify → save()`. A lost update on a *count* loses a launch, not just points.
- **No per-shell dynamic lights, ever.** Glow is `LightEmission` plus one global Bloom.
- **`ParticleEmitter:Emit()` does not replicate server→client.** All emission is client-side.
- **A `ParticleEmitter` with an empty `Texture` renders nothing.**
- Luau modules under `roblox/src/` are dependency-injected and **never `require` each other**.
- Lint: `stylua --check src tests tools && selene src tools` from `roblox/`. **Selene fails on warnings.**

---

## File Structure

| File | Responsibility | Task |
| --- | --- | --- |
| `shared-fixtures/firework-shells.json` | The id list — the contract between halves | 2 |
| `server/src/fireworks.ts` | Shell/tube ids, prices, requirements, the evaluator, the grant | 2 |
| `server/src/models/User.ts` | `fireworks` and `mortars` fields | 3 |
| `server/src/routes/apiV1.ts` | `/fireworks` state route, `/fireworks/spend`, purchase wiring | 3 |
| `server/src/economy.ts` | `firework:` and `mortar:` purchase items | 3 |
| `server/src/engine/Settlement.ts` | The win grant | 4 |
| `roblox/src/server/NetworkClient.luau` | `getFireworks`, `postFireworkSpend` | 5 |
| `roblox/src/shared/LaunchSites.luau` | Pure: is this position a valid site for this player | 5 |
| `roblox/src/server/main.server.luau` | The referee: validate, spend, broadcast | 5 |
| `roblox/default.project.json` | Three new RemoteEvents | 5 |
| `roblox/src/shared/FireworkDirector.luau` | Pure: admit / stagger / drop, and LOD | 6 |
| `roblox/src/shared/FireworkCatalog.luau` | The four recipes, each a list of phases | 7 |
| `roblox/src/shared/FireworkSchedule.luau` | Pure: recipe + budget → a timed schedule | 7 |
| `roblox/src/client/FireworkController.client.luau` | The phase player: pooled emitters and sounds | 8 |
| `roblox/src/client/HudController.client.luau` | The picker and the site-triggered button | 9 |

---

### Task 1: Measure the mobile floor

**Nothing else in this plan may be tuned until this is done.** Every particle count and concurrency number in the spec is provisional: an iPhone 15 Pro handled ~2 shells/sec, and the low-end Android has never been tried. This task produces a number, not code.

**Files:**
- Modify: `roblox/tools/studio/buildFireworkBench.luau` (knobs only, if needed)
- Create: `docs/superpowers/canyon/fireworks-mobile-floor-2026-08-05.md`

**Interfaces:**
- Consumes: nothing.
- Produces: two integers used as defaults in Task 6 — `MAX_CONCURRENT` (bursts rendered at once) and `PARTICLES_NEAR` (particle budget for a near burst).

- [ ] **Step 1: Read the bench's header before running it**

`roblox/tools/studio/buildFireworkBench.luau` carries three hard-won lessons in its header (client-side `Emit`, non-empty `Texture`, launch relative to the player). Read them — they are the reason the bench works.

- [ ] **Step 2: Install the bench and publish**

Paste the whole file into the Studio command bar in **Edit** mode. It places a LocalScript at `StarterPlayer.StarterPlayerScripts.FireworkLauncher` and a `Lighting.FireworkBloom`. It is idempotent. Then publish the place so it can be opened on a device.

- [ ] **Step 3: Measure on the low-end Android**

Open the published place on the ~3-year-old Android. Turn on the in-app Performance Stats. Raise the launch rate by lowering `LAUNCH_INTERVAL` in the LocalScript until sustained FPS drops below 30.

Record, in the doc created below: the device, the sustained shells/sec at 30fps, the particle count per shell in use, and whether the limit felt like fill-rate (drops when bursts overlap on screen) or CPU (drops with count regardless of screen area).

- [ ] **Step 4: Write the result down**

Create `docs/superpowers/canyon/fireworks-mobile-floor-2026-08-05.md` with those measurements and this line, filled in:

```markdown
DERIVED DEFAULTS FOR FireworkDirector: MAX_CONCURRENT = <n>, PARTICLES_NEAR = <n>.
Measured on <device> at <n> shells/sec sustained above 30fps.
The spec's provisional 12-16 concurrent and 150-400 particles were a guess; these are not.
```

If the device tolerates **more** than the spec's guess, still record the measurement — a budget set below the real ceiling costs spectacle for nothing.

- [ ] **Step 5: Remove the bench from the place**

Delete `StarterPlayer.StarterPlayerScripts.FireworkLauncher` and `Lighting.FireworkBloom`. The bench must not ship. The tool stays committed; the runtime objects do not.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/canyon/fireworks-mobile-floor-2026-08-05.md roblox/tools/studio/buildFireworkBench.luau
git commit -m "docs(roblox): the fireworks mobile floor, measured rather than guessed"
```

---

### Task 2: The shell ledger — ids, prices, requirements, the evaluator

Pure TypeScript, no database, no routes. The evaluator is one function over three requirement kinds so a fourth kind later is a branch, not a redesign.

**Files:**
- Create: `shared-fixtures/firework-shells.json`
- Create: `server/src/fireworks.ts`
- Test: `server/src/fireworks.test.ts`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `SHELL_IDS: readonly string[]`, `SHELL_PRICES: Record<string, number>`, `MORTAR_PRICES: Record<'mortar:S'|'mortar:M'|'mortar:L', number>`
  - `type LaunchContext = { mortars: string[]; lastWorldThrow: 'R' | 'P' | 'S' | null }`
  - `type ShellState = { count: number; launchable: boolean; reason: string | null }`
  - `evaluateShell(shellId: string, count: number, ctx: LaunchContext): ShellState`
  - `shellStates(held: Record<string, number>, ctx: LaunchContext): Record<string, ShellState>`

- [ ] **Step 1: Write the fixture**

Create `shared-fixtures/firework-shells.json`. **Ids only** — prices and requirements are server policy and live in `fireworks.ts`; the client is never told either.

```json
{
    "comment": "The contract between server/src/fireworks.ts (prices, requirements) and roblox/src/shared/FireworkCatalog.luau (recipes). Both sides' tests assert they cover every id here, so a shell that can be sold but not drawn is a CI failure rather than a blank sky.",
    "shells": ["firecracker", "peony", "willow", "ishibana"]
}
```

- [ ] **Step 2: Write the failing tests**

Create `server/src/fireworks.test.ts`:

```typescript
import { describe, it, expect } from 'vitest';
import fixtures from '../../shared-fixtures/firework-shells.json';
import { SHELL_IDS, SHELL_PRICES, MORTAR_PRICES, evaluateShell, shellStates, LaunchContext } from './fireworks';

const noGear: LaunchContext = { mortars: [], lastWorldThrow: null };

describe('the fixture is the contract', () => {
    it('every fixture id has a price', () => {
        for (const id of fixtures.shells) expect(typeof SHELL_PRICES[id]).toBe('number');
    });
    it('SHELL_IDS matches the fixture exactly', () => {
        expect([...SHELL_IDS].sort()).toEqual([...fixtures.shells].sort());
    });
});

describe('prices', () => {
    it('shells cost about one banked win', () => {
        expect(SHELL_PRICES.firecracker).toBe(1);
        expect(SHELL_PRICES.peony).toBe(3);
        expect(SHELL_PRICES.willow).toBe(4);
        expect(SHELL_PRICES.ishibana).toBe(6);
    });
    it('tubes sit below the deck ladder', () => {
        expect(MORTAR_PRICES['mortar:S']).toBe(40);
        expect(MORTAR_PRICES['mortar:M']).toBe(250);
        expect(MORTAR_PRICES['mortar:L']).toBe(1000);
    });
});

describe('requirement kind: none', () => {
    it('a firecracker you hold is launchable with no gear and no condition', () => {
        expect(evaluateShell('firecracker', 1, noGear)).toEqual({ count: 1, launchable: true, reason: null });
    });
    it('holding none beats every other reason', () => {
        expect(evaluateShell('firecracker', 0, noGear)).toEqual({ count: 0, launchable: false, reason: 'NONE_HELD' });
    });
});

describe('requirement kind: gear', () => {
    it('a peony needs a small mortar', () => {
        expect(evaluateShell('peony', 2, noGear)).toEqual({ count: 2, launchable: false, reason: 'NEEDS_MORTAR_S' });
    });
    it('and flies once you own one', () => {
        const ctx: LaunchContext = { mortars: ['mortar:S'], lastWorldThrow: null };
        expect(evaluateShell('peony', 2, ctx)).toEqual({ count: 2, launchable: true, reason: null });
    });
    it('a bigger tube satisfies a smaller requirement', () => {
        const ctx: LaunchContext = { mortars: ['mortar:L'], lastWorldThrow: null };
        expect(evaluateShell('peony', 1, ctx).launchable).toBe(true);
        expect(evaluateShell('willow', 1, ctx).launchable).toBe(true);
    });
    it('a smaller tube does NOT satisfy a bigger requirement', () => {
        const ctx: LaunchContext = { mortars: ['mortar:S'], lastWorldThrow: null };
        expect(evaluateShell('willow', 1, ctx)).toEqual({ count: 1, launchable: false, reason: 'NEEDS_MORTAR_M' });
    });
});

describe('requirement kind: condition', () => {
    it('ishibana waits for Rock', () => {
        const ctx: LaunchContext = { mortars: [], lastWorldThrow: 'P' };
        expect(evaluateShell('ishibana', 1, ctx)).toEqual({ count: 1, launchable: false, reason: 'WAITING_FOR_R' });
    });
    it('and flies in the round after the world throws Rock', () => {
        const ctx: LaunchContext = { mortars: [], lastWorldThrow: 'R' };
        expect(evaluateShell('ishibana', 1, ctx)).toEqual({ count: 1, launchable: true, reason: null });
    });
    it('an unknown last throw is not Rock', () => {
        expect(evaluateShell('ishibana', 1, noGear).launchable).toBe(false);
    });
});

describe('unknown ids', () => {
    it('are never launchable', () => {
        expect(evaluateShell('nope', 5, noGear)).toEqual({ count: 5, launchable: false, reason: 'BAD_SHELL' });
    });
});

describe('shellStates', () => {
    it('reports every catalogued shell, including ones you hold none of', () => {
        const states = shellStates({ firecracker: 2 }, noGear);
        expect(Object.keys(states).sort()).toEqual([...SHELL_IDS].sort());
        expect(states.firecracker.count).toBe(2);
        expect(states.peony).toEqual({ count: 0, launchable: false, reason: 'NONE_HELD' });
    });
});
```

- [ ] **Step 3: Run the tests to verify they fail**

Run from `server/`: `npx vitest run src/fireworks.test.ts`

Expected: FAIL — the module does not exist.

- [ ] **Step 4: Write the module**

Create `server/src/fireworks.ts`:

```typescript
import { Throw } from './engine/GameRules';

// THE SHELL LEDGER. Ids are mirrored in shared-fixtures/firework-shells.json (the contract with
// roblox/src/shared/FireworkCatalog.luau) and the tests here assert the two agree — a shell the
// shop can sell but the client cannot draw is a blank sky nobody would think to look for.
//
// Prices are deliberately tiny. totalPoints changes ONLY on bank, and at a 60-second round banking
// every win is about one point every three minutes — so a shell must cost about one banked win or
// nobody ever fires one. The 50-point deck is already hours of play.
export const SHELL_IDS = ['firecracker', 'peony', 'willow', 'ishibana'] as const;

export const SHELL_PRICES: Record<string, number> = {
    firecracker: 1,
    peony: 3,
    willow: 4,
    ishibana: 6,
};

// Gear, not real estate — deliberately under the deck ladder (50 / 500 / 3000).
export const MORTAR_PRICES = {
    'mortar:S': 40,
    'mortar:M': 250,
    'mortar:L': 1000,
} as const;

export type MortarId = keyof typeof MORTAR_PRICES;
export const MORTAR_IDS = Object.keys(MORTAR_PRICES) as MortarId[];

const MORTAR_RANK: Record<MortarId, number> = { 'mortar:S': 1, 'mortar:M': 2, 'mortar:L': 3 };

// What a shell needs. Three kinds, one evaluator — a fourth kind is a branch below, not a redesign.
type Requirement =
    | { kind: 'none' }
    | { kind: 'gear'; mortar: MortarId }
    | { kind: 'condition'; afterWorldThrow: Throw };

const REQUIREMENTS: Record<string, Requirement> = {
    firecracker: { kind: 'none' },
    peony: { kind: 'gear', mortar: 'mortar:S' },
    willow: { kind: 'gear', mortar: 'mortar:M' },
    // Reads the round's outcome; never influences it. That line is what keeps fireworks a safe
    // cosmetic rather than pay-to-win, and it must not be crossed.
    ishibana: { kind: 'condition', afterWorldThrow: 'R' },
};

export type LaunchContext = { mortars: string[]; lastWorldThrow: Throw | null };
export type ShellState = { count: number; launchable: boolean; reason: string | null };

export function evaluateShell(shellId: string, count: number, ctx: LaunchContext): ShellState {
    const req = REQUIREMENTS[shellId];
    if (!req) return { count, launchable: false, reason: 'BAD_SHELL' };
    // Holding none outranks every other reason: "you have no peony" is more useful to a player
    // than "you need a mortar for the peony you do not have".
    if (count <= 0) return { count, launchable: false, reason: 'NONE_HELD' };
    if (req.kind === 'gear') {
        const need = MORTAR_RANK[req.mortar];
        const best = ctx.mortars.reduce((m, id) => Math.max(m, MORTAR_RANK[id as MortarId] ?? 0), 0);
        if (best < need) {
            return { count, launchable: false, reason: `NEEDS_MORTAR_${req.mortar.slice(-1)}` };
        }
    }
    if (req.kind === 'condition' && ctx.lastWorldThrow !== req.afterWorldThrow) {
        return { count, launchable: false, reason: `WAITING_FOR_${req.afterWorldThrow}` };
    }
    return { count, launchable: true, reason: null };
}

// Every catalogued shell, including the ones held at zero — the picker shows the whole catalogue so
// a player can see what exists and why they cannot fire it yet.
export function shellStates(held: Record<string, number>, ctx: LaunchContext): Record<string, ShellState> {
    const out: Record<string, ShellState> = {};
    for (const id of SHELL_IDS) out[id] = evaluateShell(id, held[id] ?? 0, ctx);
    return out;
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run from `server/`: `npx vitest run src/fireworks.test.ts`

Expected: PASS, all cases.

- [ ] **Step 6: Commit**

```bash
git add shared-fixtures/firework-shells.json server/src/fireworks.ts server/src/fireworks.test.ts
git commit -m "feat(server): the shell ledger — ids, prices, and one evaluator over three requirement kinds"
```

---

### Task 3: Inventory, purchase, and the authoritative spend

The first **consumable** in an economy where every purchase so far has been permanent. The spend must not repeat the read-modify-write pattern the existing `/purchase` route uses — on a count, a lost update loses a launch.

**Files:**
- Modify: `server/src/models/User.ts`
- Modify: `server/src/economy.ts`
- Modify: `server/src/routes/apiV1.ts`
- Test: `server/src/routes/apiV1.test.ts`

**Interfaces:**
- Consumes: `SHELL_PRICES`, `MORTAR_PRICES`, `MORTAR_IDS`, `shellStates`, `LaunchContext` (Task 2).
- Produces:
  - `User.fireworks: Map<string, number>`, `User.mortars: string[]`
  - `GET /api/v1/players/:robloxUserId/fireworks?lastWorldThrow=R` → `{ shells: Record<string, ShellState>, mortars: string[] }`
  - `POST /api/v1/players/:robloxUserId/fireworks/spend` `{ shellId }` → `{ shellId, count }` on 200; `409 NONE_HELD` when the conditional update matches nothing
  - purchase items `firework:<shellId>` and `mortar:<S|M|L>`

- [ ] **Step 1: Write the failing tests**

Add to `server/src/routes/apiV1.test.ts`. This file has `makeApp(engine, store)`, `makeEngine(overrides)` and `API_KEY` already:

```typescript
    describe('fireworks', () => {
        it('reports every shell with counts and reasons', async () => {
            const u = await User.create({ robloxUserId: '900', fireworks: { firecracker: 2 } });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/players/900/fireworks').set('X-API-Key', API_KEY).expect(200);
            expect(res.body.shells.firecracker).toEqual({ count: 2, launchable: true, reason: null });
            expect(res.body.shells.peony).toEqual({ count: 0, launchable: false, reason: 'NONE_HELD' });
            expect(res.body.mortars).toEqual([]);
            await User.deleteOne({ _id: u._id });
        });

        it('honours lastWorldThrow for the condition shell', async () => {
            await User.create({ robloxUserId: '901', fireworks: { ishibana: 1 } });
            const app = makeApp(makeEngine(), new ResultsStore());
            const waiting = await request(app)
                .get('/api/v1/players/901/fireworks?lastWorldThrow=P').set('X-API-Key', API_KEY).expect(200);
            expect(waiting.body.shells.ishibana.reason).toBe('WAITING_FOR_R');
            const open = await request(app)
                .get('/api/v1/players/901/fireworks?lastWorldThrow=R').set('X-API-Key', API_KEY).expect(200);
            expect(open.body.shells.ishibana.launchable).toBe(true);
        });

        it('spend decrements and returns the new count', async () => {
            await User.create({ robloxUserId: '902', fireworks: { firecracker: 2 } });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/players/902/fireworks/spend').set('X-API-Key', API_KEY)
                .send({ shellId: 'firecracker' }).expect(200);
            expect(res.body).toEqual({ shellId: 'firecracker', count: 1 });
        });

        it('spend refuses when none are held, and does not go negative', async () => {
            await User.create({ robloxUserId: '903', fireworks: { firecracker: 0 } });
            const app = makeApp(makeEngine(), new ResultsStore());
            await request(app).post('/api/v1/players/903/fireworks/spend').set('X-API-Key', API_KEY)
                .send({ shellId: 'firecracker' }).expect(409);
            const after = await User.findOne({ robloxUserId: '903' });
            expect(after!.fireworks.get('firecracker') ?? 0).toBe(0);
        });

        it('CONCURRENT SPENDS CANNOT OVERSPEND — the conditional $inc is the whole point', async () => {
            // Two launches racing on a single held shell. A read-modify-write would let both read
            // count=1 and both write count=0, firing two shells for one. Exactly one must win.
            await User.create({ robloxUserId: '904', fireworks: { firecracker: 1 } });
            const app = makeApp(makeEngine(), new ResultsStore());
            const fire = () => request(app).post('/api/v1/players/904/fireworks/spend')
                .set('X-API-Key', API_KEY).send({ shellId: 'firecracker' });
            const [a, b] = await Promise.all([fire(), fire()]);
            const codes = [a.status, b.status].sort();
            expect(codes).toEqual([200, 409]);
            const after = await User.findOne({ robloxUserId: '904' });
            expect(after!.fireworks.get('firecracker')).toBe(0);
        });

        it('buys a shell through the existing purchase route', async () => {
            await User.create({ robloxUserId: '905', totalPoints: 10 });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/players/905/purchase').set('X-API-Key', API_KEY)
                .send({ item: 'firework:peony' }).expect(200);
            expect(res.body.totalPoints).toBe(7);
            const after = await User.findOne({ robloxUserId: '905' });
            expect(after!.fireworks.get('peony')).toBe(1);
        });

        it('buys a mortar tube, and tubes are linear', async () => {
            await User.create({ robloxUserId: '906', totalPoints: 5000 });
            const app = makeApp(makeEngine(), new ResultsStore());
            await request(app).post('/api/v1/players/906/purchase').set('X-API-Key', API_KEY)
                .send({ item: 'mortar:M' }).expect(400); // no S yet
            await request(app).post('/api/v1/players/906/purchase').set('X-API-Key', API_KEY)
                .send({ item: 'mortar:S' }).expect(200);
            await request(app).post('/api/v1/players/906/purchase').set('X-API-Key', API_KEY)
                .send({ item: 'mortar:M' }).expect(200);
            const after = await User.findOne({ robloxUserId: '906' });
            expect(after!.mortars.sort()).toEqual(['mortar:M', 'mortar:S']);
        });
    });
```

Import `User` and `ResultsStore` at the top of the file if they are not already imported.

- [ ] **Step 2: Run the tests to verify they fail**

Run from `server/`: `npx vitest run src/routes/apiV1.test.ts`

Expected: FAIL — 404 on the new routes, and unknown-item 400s on the purchases.

- [ ] **Step 3: Add the model fields**

In `server/src/models/User.ts`, add to the `IUser` interface beside `deckDecorations`:

```typescript
    fireworks: Map<string, number>;
    mortars: string[];
```

and to `UserSchema` beside `deckDecorations`:

```typescript
    // THE FIRST CONSUMABLE. Every other purchase in this schema is permanent; this one goes down.
    // Decrementing must be a conditional $inc (see the spend route) — a lost update on a count
    // loses a launch, not just points.
    fireworks: { type: Map, of: Number, default: {} },
    mortars: { type: [String], default: [] },
```

- [ ] **Step 4: Teach the economy the two new item kinds**

In `server/src/economy.ts`, add the import at the top:

```typescript
import { SHELL_PRICES, MORTAR_PRICES, MORTAR_IDS, MortarId } from './fireworks';
```

Extend `EconomyState` with the fields the new checks need:

```typescript
export type EconomyState = { totalPoints: number; maxDeckSize: Size | null; teahouseSizes: Size[]; portalOwned?: boolean; deckDecorationCount?: number; mortars?: string[] };
```

In `validatePurchase`, add these two branches immediately **before** the `const [kind, size] = item.split(':')` line (they must come first — `mortar:S` would otherwise fall into the deck/teahouse parser and be rejected as `BAD_ITEM`):

```typescript
    if (item.startsWith('firework:')) {
        // No deck required and no tier order: a shell is the everyday purchase, and gating it on
        // property would put the whole feature behind hours of play.
        const cost = SHELL_PRICES[item.slice('firework:'.length)];
        if (cost === undefined) return { ok: false, error: 'BAD_ITEM' };
        if (state.totalPoints < cost) return { ok: false, error: 'INSUFFICIENT_POINTS' };
        return { ok: true, cost };
    }
    if (item.startsWith('mortar:')) {
        const cost = (MORTAR_PRICES as Record<string, number>)[item];
        if (cost === undefined) return { ok: false, error: 'BAD_ITEM' };
        const owned = state.mortars ?? [];
        if (owned.includes(item)) return { ok: false, error: 'ALREADY_OWNED' };
        // Linear, like decks: the tier below must already be owned.
        const idx = MORTAR_IDS.indexOf(item as MortarId);
        if (idx > 0 && !owned.includes(MORTAR_IDS[idx - 1])) return { ok: false, error: 'BAD_TIER_ORDER' };
        if (state.totalPoints < cost) return { ok: false, error: 'INSUFFICIENT_POINTS' };
        return { ok: true, cost };
    }
```

In `applyPurchase`, add these two branches immediately after the `decoration:` branch. Note `next.mortars` must be carried through the base object too — add `mortars: [...(state.mortars ?? [])],` to the `next` literal:

```typescript
    if (item.startsWith('firework:')) {
        return next; // cost deducted above; the shell count is incremented by the route
    }
    if (item.startsWith('mortar:')) {
        next.mortars = [...(next.mortars ?? []), item];
        return next;
    }
```

- [ ] **Step 5: Add the two routes and wire the purchase**

In `server/src/routes/apiV1.ts`, add to the imports:

```typescript
import { shellStates, SHELL_IDS, LaunchContext } from '../fireworks';
import { Throw } from '../engine/GameRules';
```

Extend `readEconomy` so purchases can see owned tubes — add `mortars: user.mortars ?? []` to the object it returns, and `mortars?: string[]` to its parameter type.

In the `/purchase` route, after `user.portalOwned = after.portalOwned ?? false;`, add:

```typescript
            user.mortars = after.mortars ?? [];
            if (item.startsWith('firework:')) {
                const shellId = item.slice('firework:'.length);
                user.fireworks.set(shellId, (user.fireworks.get(shellId) ?? 0) + 1);
                await user.save();
                res.json({ item, totalPoints: after.totalPoints, shellId, count: user.fireworks.get(shellId) });
                return;
            }
```

Then add the two new routes beside the other `/players/:robloxUserId/...` routes:

```typescript
    router.get('/players/:robloxUserId/fireworks', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const raw = String(req.query.lastWorldThrow ?? '');
            // The CLIENT is never told a requirement — it is told the ANSWER. The Roblox server
            // passes the round it already has; anything else reads as "not Rock", which fails shut.
            const ctx: LaunchContext = {
                mortars: user.mortars ?? [],
                lastWorldThrow: (['R', 'P', 'S'].includes(raw) ? raw : null) as Throw | null,
            };
            const held: Record<string, number> = {};
            for (const id of SHELL_IDS) held[id] = user.fireworks?.get(id) ?? 0;
            res.set('Cache-Control', 'no-store');
            res.json({ shells: shellStates(held, ctx), mortars: ctx.mortars });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.post('/players/:robloxUserId/fireworks/spend', async (req, res) => {
        try {
            const shellId = req.body?.shellId;
            if (typeof shellId !== 'string' || !SHELL_IDS.includes(shellId as never)) {
                res.status(400).json({ error: 'BAD_SHELL' });
                return;
            }
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            // CONDITIONAL $inc, NOT read-modify-write. Two launches racing on one held shell must
            // resolve to exactly one firing: the filter and the decrement are a single atomic
            // operation, so the loser matches no document and gets 409. The existing /purchase
            // route's read-then-save pattern would let both read 1 and both write 0.
            const updated = await User.findOneAndUpdate(
                { _id: user._id, [`fireworks.${shellId}`]: { $gte: 1 } },
                { $inc: { [`fireworks.${shellId}`]: -1 } },
                { new: true }
            );
            if (!updated) { res.status(409).json({ error: 'NONE_HELD' }); return; }
            res.json({ shellId, count: updated.fireworks.get(shellId) ?? 0 });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });
```

- [ ] **Step 6: Run the full server suite**

Run from `server/`: `npm test && npm run build`

Expected: PASS and a clean compile. The concurrency test is the one that matters — if it reports two 200s, the spend is not atomic and the `$gte: 1` filter is missing or wrong.

- [ ] **Step 7: Commit**

```bash
git add server/src/models/User.ts server/src/economy.ts server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "feat(server): a consumable shell inventory, spent with a conditional \$inc"
```

---

### Task 4: The win grant

One `firecracker` on a WIN, so a new player sees their own firework in their first few minutes without buying anything.

**Files:**
- Modify: `server/src/engine/Settlement.ts:113-123`
- Test: `server/src/engine/Settlement.test.ts`

**Interfaces:**
- Consumes: `User.fireworks` (Task 3).
- Produces: nothing consumed downstream — the count simply appears in Task 3's `/fireworks` response.

- [ ] **Step 1: Write the failing test**

Add to `server/src/engine/Settlement.test.ts`, matching that file's existing helpers for building a round and a user:

```typescript
    it('a WIN grants one firecracker', async () => {
        // The grant pathway's first source. A new player should see their own firework within
        // minutes of joining, without buying anything.
        const user = await User.create({ deviceId: 'grantWin', pointsAtStake: 0 });
        await settleRound(roundWith({ deviceId: 'grantWin', throw: 'R' }, 'S')); // R beats S -> WIN
        const after = await User.findById(user._id);
        expect(after!.fireworks.get('firecracker')).toBe(1);
    });

    it('a LOSS grants nothing', async () => {
        const user = await User.create({ deviceId: 'grantLoss', pointsAtStake: 0 });
        await settleRound(roundWith({ deviceId: 'grantLoss', throw: 'R' }, 'P')); // P beats R -> LOSS
        const after = await User.findById(user._id);
        expect(after!.fireworks.get('firecracker') ?? 0).toBe(0);
    });
```

Use whatever the file's actual round-building helper is called; if there is none, construct the `RoundClosedEvent` inline the way the neighbouring tests do.

- [ ] **Step 2: Run the tests to verify they fail**

Run from `server/`: `npx vitest run src/engine/Settlement.test.ts`

Expected: FAIL — `expected undefined to be 1`.

- [ ] **Step 3: Add the grant to the settlement update**

In `server/src/engine/Settlement.ts`, the `User.findByIdAndUpdate` call already carries `$inc: counters.$inc`. Replace that line with:

```typescript
                    $inc: {
                        ...counters.$inc,
                        // THE GRANT PATHWAY'S FIRST SOURCE. A multi-day streak or a Robux pack is
                        // the same operation with a different trigger — which is why acquisition is
                        // one pathway and not a purchase feature with grants bolted on.
                        ...(result === 'WIN' ? { 'fireworks.firecracker': 1 } : {}),
                    },
```

- [ ] **Step 4: Run the tests to verify they pass**

Run from `server/`: `npx vitest run src/engine/Settlement.test.ts`

Expected: PASS.

- [ ] **Step 5: Run the full suite and commit**

```bash
cd server && npm test && npm run build && cd ..
git add server/src/engine/Settlement.ts server/src/engine/Settlement.test.ts
git commit -m "feat(server): winning a round grants a firecracker"
```

---

### Task 5: The referee — sites, remotes, and the spend call

The Roblox game server validates where you are standing, spends the shell, and only then broadcasts. A client never announces its own firework.

**Files:**
- Create: `roblox/src/shared/LaunchSites.luau`
- Test: `roblox/tests/LaunchSites.spec.luau`
- Modify: `roblox/src/server/NetworkClient.luau`
- Modify: `roblox/src/server/main.server.luau`
- Modify: `roblox/default.project.json`

**Interfaces:**
- Consumes: `GET /players/:id/fireworks`, `POST /players/:id/fireworks/spend` (Task 3).
- Produces:
  - `LaunchSites.isValid(playerPos: Vector3, sites: { {pos: Vector3, radius: number, ownerUserId: string?} }, userId: string): boolean`
  - `NetworkClient:getFireworks(robloxUserId, lastWorldThrow)`, `NetworkClient:postFireworkSpend(robloxUserId, shellId)`
  - RemoteEvents `RequestFireworkLaunch` (client→server, `shellId`), `FireworkLaunched` (server→all, `{ shellId, origin, seed, by }`), `FireworkState` (server→owner, `{ shells, mortars }`)

- [ ] **Step 1: Write the failing site tests**

Create `roblox/tests/LaunchSites.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local LaunchSites = require("../src/shared/LaunchSites")

-- Vector3 is a Roblox global, absent under Lune. LaunchSites takes plain {x,y,z} tables so it
-- stays pure and testable, exactly like every other module under src/shared.
local function v(x: number, y: number, z: number)
    return { x = x, y = y, z = z }
end

describe("LaunchSites", function()
    test("a public site admits anyone within its radius", function()
        local sites = { { pos = v(0, 0, 0), radius = 10, ownerUserId = nil } }
        expect(LaunchSites.isValid(v(3, 0, 4), sites, "u1")).toBe(true) -- 5 away
        expect(LaunchSites.isValid(v(30, 0, 0), sites, "u1")).toBe(false)
    end)

    test("distance ignores height, so a deck above a site still counts", function()
        local sites = { { pos = v(0, 0, 0), radius = 10, ownerUserId = nil } }
        expect(LaunchSites.isValid(v(3, 400, 4), sites, "u1")).toBe(true)
    end)

    test("an owned site admits ONLY its owner", function()
        local sites = { { pos = v(0, 0, 0), radius = 10, ownerUserId = "u1" } }
        expect(LaunchSites.isValid(v(1, 0, 1), sites, "u1")).toBe(true)
        expect(LaunchSites.isValid(v(1, 0, 1), sites, "u2")).toBe(false)
    end)

    test("standing in someone else's deck does not block a public site you also stand in", function()
        local sites = {
            { pos = v(0, 0, 0), radius = 10, ownerUserId = "u2" },
            { pos = v(0, 0, 0), radius = 10, ownerUserId = nil },
        }
        expect(LaunchSites.isValid(v(1, 0, 1), sites, "u1")).toBe(true)
    end)

    test("no sites means nowhere to launch", function()
        expect(LaunchSites.isValid(v(0, 0, 0), {}, "u1")).toBe(false)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run from `roblox/`: `lune run tests/run`

Expected: FAIL — the module does not exist.

- [ ] **Step 3: Write the module**

Create `roblox/src/shared/LaunchSites.luau`:

```lua
--!strict
-- WHERE A SHELL MAY BE LAUNCHED FROM. Pure and Roblox-free (positions are plain {x,y,z} tables) so
-- it runs under Lune like everything else in src/shared — the game server converts Vector3s at the
-- boundary.
--
-- Two kinds of site. A site with no `ownerUserId` is public and admits anyone; a site with one is
-- somebody's deck and admits only them. GEAR IS PERSONAL and sites do not lend tubes: standing on a
-- public site never grants a mortar you did not buy.
local LaunchSites = {}

export type Site = { pos: { x: number, y: number, z: number }, radius: number, ownerUserId: string? }

-- Horizontal distance only. A deck sits well above the site marker it belongs to, and a canyon
-- this vertical would otherwise reject a player standing directly on the spot.
local function withinXZ(a: { x: number, y: number, z: number }, b: { x: number, y: number, z: number }, r: number): boolean
    local dx, dz = a.x - b.x, a.z - b.z
    return dx * dx + dz * dz <= r * r
end

function LaunchSites.isValid(playerPos: { x: number, y: number, z: number }, sites: { Site }, userId: string): boolean
    for _, site in sites do
        if (site.ownerUserId == nil or site.ownerUserId == userId) and withinXZ(playerPos, site.pos, site.radius) then
            return true
        end
    end
    return false
end

return LaunchSites
```

- [ ] **Step 4: Run to verify it passes, then lint**

Run from `roblox/`: `lune run tests/run && stylua --check src tests tools && selene src tools`

Expected: PASS, clean, zero warnings.

- [ ] **Step 5: Add the two NetworkClient calls**

In `roblox/src/server/NetworkClient.luau`, add beside `postPurchase`:

```lua
function NetworkClient.getFireworks(self: any, robloxUserId: string, lastWorldThrow: string?): Result
    local q = if lastWorldThrow then `?lastWorldThrow={lastWorldThrow}` else ""
    return self:_request("GET", `/api/v1/players/{robloxUserId}/fireworks{q}`)
end

function NetworkClient.postFireworkSpend(self: any, robloxUserId: string, shellId: string): Result
    return self:_request("POST", `/api/v1/players/{robloxUserId}/fireworks/spend`, { shellId = shellId })
end
```

- [ ] **Step 6: Declare the three remotes**

In `roblox/default.project.json`, add to the `RoshamboRemotes` block beside `BoardData`:

```json
                "RequestFireworkLaunch": { "$className": "RemoteEvent" },
                "FireworkLaunched": { "$className": "RemoteEvent" },
                "FireworkState": { "$className": "RemoteEvent" }
```

- [ ] **Step 7: Wire the referee**

In `roblox/src/server/main.server.luau`, add near the other remote lookups:

```lua
local RequestFireworkLaunch = remotes:WaitForChild("RequestFireworkLaunch") :: RemoteEvent
local FireworkLaunched = remotes:WaitForChild("FireworkLaunched") :: RemoteEvent
local FireworkState = remotes:WaitForChild("FireworkState") :: RemoteEvent
```

and add the handler. Place it beside the other `RemoteEvent.OnServerEvent` handlers, and route it through the same `HandlerQueue` the other HTTP-yielding handlers use (the file's existing comment explains why a bare `task.spawn` per fire is wrong):

```lua
-- THE REFEREE. A client asks; the server decides, spends, and only then tells everyone. A client
-- never announces its own firework — that is both the anti-cheat property and the perf rule
-- (the server emits a tiny event; every client renders locally from its own catalogue).
local SITE_RADIUS = 24
local function fireworkSites(): { any }
    local sites = {}
    for _, part in CollectionService:GetTagged("FireworkLaunchSite") do
        if part:IsA("BasePart") then
            local p = part.Position
            table.insert(sites, { pos = { x = p.X, y = p.Y, z = p.Z }, radius = SITE_RADIUS, ownerUserId = nil })
        end
    end
    -- A player's own deck is a site for that player only. `deckSiteFor` returns nil when they own
    -- no deck, which is the common case for a new player — they use the public sites.
    return sites
end

RequestFireworkLaunch.OnServerEvent:Connect(function(player, shellId)
    if typeof(shellId) ~= "string" then
        return
    end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then
        return
    end
    local uid = tostring(player.UserId)
    local pos = root.Position
    local sites = fireworkSites()
    local deck = deckSiteFor(uid)
    if deck then
        table.insert(sites, deck)
    end
    if not LaunchSites.isValid({ x = pos.X, y = pos.Y, z = pos.Z }, sites, uid) then
        return -- not at a site; the client should not have offered the button
    end
    local res = net:postFireworkSpend(uid, shellId)
    if not res.ok then
        pushFireworkState(player) -- re-sync: their count was not what they thought
        return
    end
    FireworkLaunched:FireAllClients({
        shellId = shellId,
        origin = root.Position + Vector3.new(0, 6, 0),
        seed = math.random(1, 2 ^ 31 - 1),
        by = uid,
    })
    pushFireworkState(player)
end)
```

Add these two helpers **above** the handler:

```lua
-- The newest tape entry is the last CLOSED round, which is exactly what `ishibana`'s condition is
-- about. The tape already arrives on every poll — the server does not fetch anything extra to
-- answer this.
local function lastWorldThrow(): string?
    local tape = latestTape -- the coordinator's most recent state.tape
    local newest = tape and tape[1]
    return newest and newest.worldThrow or nil
end

-- A player's own deck is a site for that player ALONE. Returns nil when they own no deck, which is
-- the common case for a new player: they use the public sites. Note the deck does NOT lend a
-- mortar — gear is personal, and the tube is the thing you bought.
local function deckSiteFor(uid: string): any?
    local slot = padSlotForUser(uid) -- the same lookup teahouse materialisation already performs
    if not slot then
        return nil
    end
    local p = slot.position
    return { pos = { x = p.X, y = p.Y, z = p.Z }, radius = SITE_RADIUS, ownerUserId = uid }
end

-- Push the whole shell state to one player. Called after every launch (their count changed) and
-- once on join. HTTP-yielding, so it goes through the HandlerQueue like every other call here.
local function pushFireworkState(player: Player)
    local uid = tostring(player.UserId)
    local res = net:getFireworks(uid, lastWorldThrow())
    if res.ok then
        FireworkState:FireClient(player, res.data)
    end
end
```

`padSlotForUser` and `latestTape` are the file's existing lookups under whatever names it already
uses — find them rather than adding new ones:

```bash
grep -n "state.tape\|padSlot\|slotForUser\|ownerOf" roblox/src/server/main.server.luau | head
```

Call `pushFireworkState(player)` once in the join handler, beside the existing
`EconomyState:FireClient`.

- [ ] **Step 7a: Re-push at the reveal, so the window opens and the grant lands**

Two things change at a round boundary and both need the client told: `ishibana`'s window opens or
closes with the world throw, and a WIN has just granted a firecracker (Task 4). Without this the
picker shows a stale `WAITING_FOR_R` and a count that is one behind.

The server already does per-player work at the reveal — find the handler that fires `ProfileUpdate`
per player and add, for each player it touches:

```lua
        pushFireworkState(player)
```

**Cost, stated rather than discovered:** one extra AWS call per player per round, at the moment the
server is already making one. Fine at friends-and-family scale and unremarkable against the existing
per-player reveal traffic. If player counts grow, the fix is to return shell state in the reveal
payload the server already fetches, not to push less often — a stale window is the one thing this
feature cannot afford, because a player watching for their Rock round will not tap a button that
says "waiting".

A stale state can never produce a *wrong* firework: the server re-validates every launch (Step 7),
so the worst case is a refused tap.

- [ ] **Step 8: Run every gate and commit**

```bash
cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools && cd ..
git add roblox/src/shared/LaunchSites.luau roblox/tests/LaunchSites.spec.luau roblox/src/server/NetworkClient.luau roblox/src/server/main.server.luau roblox/default.project.json
git commit -m "feat(roblox): the referee — validate the site, spend the shell, then tell everyone"
```

---

### Task 6: The director

Pure policy, testable under Lune. This is the only part of the rendering path any harness can see.

**Files:**
- Create: `roblox/src/shared/FireworkDirector.luau`
- Test: `roblox/tests/FireworkDirector.spec.luau`

**Interfaces:**
- Consumes: `MAX_CONCURRENT` and `PARTICLES_NEAR` from Task 1's measurement doc.
- Produces:
  - `FireworkDirector.admit(activeCount: number, distance: number): { render: boolean, delayMs: number }`
  - `FireworkDirector.lodFor(distance: number): { particles: number, sound: boolean }`
  - `FireworkDirector.MAX_CONCURRENT`, `.NEAR_STUDS`, `.FAR_STUDS`, `.PARTICLES_NEAR`, `.PARTICLES_FAR`, `.DROP_STUDS`

- [ ] **Step 1: Write the failing tests**

Create `roblox/tests/FireworkDirector.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local FireworkDirector = require("../src/shared/FireworkDirector")

describe("FireworkDirector — the concurrency budget", function()
    test("an empty sky renders at once", function()
        local d = FireworkDirector.admit(0, 100)
        expect(d.render).toBe(true)
        expect(d.delayMs).toBe(0)
    end)

    test("a full sky staggers rather than dropping — the burst still happens", function()
        local d = FireworkDirector.admit(FireworkDirector.MAX_CONCURRENT, 100)
        expect(d.render).toBe(true)
        expect(d.delayMs >= 100).toBe(true)
        expect(d.delayMs <= 300).toBe(true)
    end)

    test("the stagger grows with the overflow, so a burst of launches spreads out", function()
        local one = FireworkDirector.admit(FireworkDirector.MAX_CONCURRENT + 1, 100)
        local many = FireworkDirector.admit(FireworkDirector.MAX_CONCURRENT + 8, 100)
        expect(many.delayMs > one.delayMs).toBe(true)
    end)

    test("beyond DROP_STUDS a burst is dropped, not staggered", function()
        -- Too far to see. Rendering it costs fill-rate for pixels nobody looks at.
        local d = FireworkDirector.admit(0, FireworkDirector.DROP_STUDS + 1)
        expect(d.render).toBe(false)
    end)
end)

describe("FireworkDirector — distance LOD", function()
    test("near bursts get the full budget and sound", function()
        local l = FireworkDirector.lodFor(FireworkDirector.NEAR_STUDS - 1)
        expect(l.particles).toBe(FireworkDirector.PARTICLES_NEAR)
        expect(l.sound).toBe(true)
    end)

    test("far bursts are thinned and silent", function()
        local l = FireworkDirector.lodFor(FireworkDirector.FAR_STUDS + 1)
        expect(l.particles).toBe(FireworkDirector.PARTICLES_FAR)
        expect(l.sound).toBe(false)
    end)

    test("particle count never rises with distance", function()
        local prev = math.huge
        for d = 0, FireworkDirector.DROP_STUDS, 25 do
            local n = FireworkDirector.lodFor(d).particles
            expect(n <= prev).toBe(true)
            prev = n
        end
    end)

    test("NO BURST EVER COSTS MORE THAN THE NEAR BUDGET", function()
        -- The ceiling the mobile floor measurement bought. If a code path can exceed it, the
        -- measurement stops meaning anything.
        for d = 0, FireworkDirector.DROP_STUDS, 10 do
            expect(FireworkDirector.lodFor(d).particles <= FireworkDirector.PARTICLES_NEAR).toBe(true)
        end
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run from `roblox/`: `lune run tests/run`

Expected: FAIL — the module does not exist.

- [ ] **Step 3: Write the module**

Create `roblox/src/shared/FireworkDirector.luau`. **Replace `MAX_CONCURRENT` and `PARTICLES_NEAR` with the numbers Task 1 measured**, and cite the measurement doc in the comment:

```lua
--!strict
-- WHAT RENDERS, WHEN, AND AT WHAT DETAIL. Pure policy — the controller owns the instances and does
-- what this says. Split that way because no harness in this repo loads a `.client.luau`, so this
-- is the only part of the rendering path that can be tested at all.
--
-- THE NUMBERS BELOW WERE MEASURED, NOT CHOSEN: see
-- docs/superpowers/canyon/fireworks-mobile-floor-2026-08-05.md. Mobile is fill-rate bound, so the
-- budget is a ceiling on simultaneous overlapping particles, not on shells.
local FireworkDirector = {}

-- Bursts rendered at once. Beyond this they are STAGGERED, never dropped: the cap decouples cost
-- from player count, so a whole server firing together still costs the same as this many.
FireworkDirector.MAX_CONCURRENT = 14

-- Distance bands, in studs.
FireworkDirector.NEAR_STUDS = 250
FireworkDirector.FAR_STUDS = 700
-- Past this, do not render at all. The canyon is long and a burst at the far rim is a few pixels.
FireworkDirector.DROP_STUDS = 1400

FireworkDirector.PARTICLES_NEAR = 400
FireworkDirector.PARTICLES_FAR = 90

local STAGGER_MIN_MS = 100
local STAGGER_MAX_MS = 300

-- Render now, or shortly. `delayMs` grows with the overflow so a simultaneous volley spreads across
-- a few hundred milliseconds — visually indistinguishable from all-at-once, and the difference
-- between a steady frame rate and a hitch.
function FireworkDirector.admit(activeCount: number, distance: number): { render: boolean, delayMs: number }
    if distance > FireworkDirector.DROP_STUDS then
        return { render = false, delayMs = 0 }
    end
    local over = activeCount - FireworkDirector.MAX_CONCURRENT
    if over < 0 then
        return { render = true, delayMs = 0 }
    end
    local span = STAGGER_MAX_MS - STAGGER_MIN_MS
    local delay = STAGGER_MIN_MS + math.min(span, over * (span / 8))
    return { render = true, delayMs = delay }
end

-- Particle budget and whether the burst is audible. Linear between the bands, so there is no visible
-- step as a burst recedes.
function FireworkDirector.lodFor(distance: number): { particles: number, sound: boolean }
    local near, far = FireworkDirector.NEAR_STUDS, FireworkDirector.FAR_STUDS
    local pNear, pFar = FireworkDirector.PARTICLES_NEAR, FireworkDirector.PARTICLES_FAR
    local particles
    if distance <= near then
        particles = pNear
    elseif distance >= far then
        particles = pFar
    else
        local t = (distance - near) / (far - near)
        particles = math.floor(pNear + (pFar - pNear) * t)
    end
    return { particles = particles, sound = distance <= near }
end

return FireworkDirector
```

- [ ] **Step 4: Run to verify it passes, lint, and commit**

```bash
cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools && cd ..
git add roblox/src/shared/FireworkDirector.luau roblox/tests/FireworkDirector.spec.luau
git commit -m "feat(roblox): the firework director — a measured budget, staggered not dropped"
```

---
### Task 7: The catalog and the schedule — a recipe is a list of phases

A real shell is a **launch report**, an **ascent**, a **burst**, and — for anything past the
simplest — **sub-bursts**, each with its own sound. A fixed ascent-then-burst chain cannot express
that, and the cost of shell #12 is what this task is really about.

The catalog is data. The schedule compiler is pure logic and carries the rule that matters: **the
particle budget is per shell, divided across its burst phases, never multiplied.**

**Files:**
- Create: `roblox/src/shared/FireworkCatalog.luau`
- Create: `roblox/src/shared/FireworkSchedule.luau`
- Create: `roblox/tests/fixtures/fireworkShells.luau`
- Test: `roblox/tests/FireworkCatalog.spec.luau`
- Test: `roblox/tests/FireworkSchedule.spec.luau`

**Interfaces:**
- Consumes: `FireworkDirector.PARTICLES_NEAR` (Task 6) only as a test value.
- Produces:
  - `FireworkCatalog.RECIPES: { [string]: Recipe }` where `Recipe = { phases: { Phase } }`
  - `Phase = { at: number, kind: string, anchor: string, points: number?, scatter: number?, share: number?, sound: string?, color: { number }?, edgeColor: { number }?, spread: number?, droop: boolean? }`
  - `FireworkSchedule.compile(recipe: Recipe, budget: number): { Event }`
  - `Event = { at: number, kind: string, anchor: string, points: number, scatter: number, particles: number, sound: string?, color: { number }?, edgeColor: { number }?, spread: number?, droop: boolean? }`

- [ ] **Step 1: Write the Luau-side fixture**

Lune cannot `require` a `.json` file, so the id list is transcribed. Create
`roblox/tests/fixtures/fireworkShells.luau`:

```lua
--!strict
-- Mirrors shared-fixtures/firework-shells.json. Lune cannot require JSON, so the id list is
-- transcribed. Keep them identical: this list is what proves every sellable shell can be drawn.
return { shells = { "firecracker", "peony", "willow", "ishibana" } }
```

- [ ] **Step 2: Write the failing schedule tests**

Create `roblox/tests/FireworkSchedule.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local FireworkSchedule = require("../src/shared/FireworkSchedule")

-- A nested shell: one main break, then six secondary points a third of a second later. No shipping
-- shell uses this yet — it is here because the FORMAT and the PLAYER must support it, so the first
-- nested shell is authored rather than engineered.
local NESTED = {
    phases = {
        { at = 0.0, kind = "report", anchor = "origin", sound = "rbxassetid://1" },
        { at = 0.02, kind = "ascent", anchor = "origin", sound = "rbxassetid://2" },
        { at = 1.1, kind = "burst", anchor = "apex", points = 1, scatter = 0, share = 2, sound = "rbxassetid://3" },
        { at = 1.45, kind = "burst", anchor = "apex", points = 6, scatter = 26, share = 1, sound = "rbxassetid://4" },
    },
}

local SIMPLE = {
    phases = {
        { at = 0.0, kind = "report", anchor = "origin" },
        { at = 0.02, kind = "ascent", anchor = "origin" },
        { at = 1.1, kind = "burst", anchor = "apex" },
    },
}

describe("FireworkSchedule — compiling a recipe", function()
    test("it emits one event per phase, in time order", function()
        local ev = FireworkSchedule.compile(NESTED, 400)
        expect(#ev).toBe(4)
        local prev = -1
        for _, e in ev do
            expect(e.at >= prev).toBe(true)
            prev = e.at
        end
    end)

    test("non-burst phases carry no particles", function()
        for _, e in FireworkSchedule.compile(NESTED, 400) do
            if e.kind ~= "burst" then
                expect(e.particles).toBe(0)
            end
        end
    end)

    test("sounds survive compilation", function()
        local ev = FireworkSchedule.compile(NESTED, 400)
        expect(ev[1].sound).toBe("rbxassetid://1")
        expect(ev[4].sound).toBe("rbxassetid://4")
    end)

    test("defaults fill in for a simple shell", function()
        local ev = FireworkSchedule.compile(SIMPLE, 400)
        local burst = ev[3]
        expect(burst.points).toBe(1)
        expect(burst.scatter).toBe(0)
        expect(burst.particles).toBe(400) -- the only burst gets the whole budget
    end)
end)

describe("FireworkSchedule — THE BUDGET IS PER SHELL", function()
    test("total particles across every break point never exceed the budget", function()
        -- THE LOAD-BEARING TEST. A nested shell has 7 break points; at the full near-budget each,
        -- it would cost seven times what the mobile floor was measured against — authored in good
        -- faith by someone assuming each break looks like a normal break.
        for _, budget in { 90, 250, 400 } do
            local total = 0
            for _, e in FireworkSchedule.compile(NESTED, budget) do
                total += e.particles * e.points
            end
            expect(total <= budget).toBe(true)
        end
    end)

    test("share splits the budget between burst phases", function()
        -- share 2 : share 1 over 400, with the second phase spread across 6 points.
        local ev = FireworkSchedule.compile(NESTED, 400)
        expect(ev[3].particles).toBe(266) -- floor(400 * 2/3)
        expect(ev[3].points).toBe(1)
        expect(ev[4].particles).toBe(22) -- floor(400 * 1/3 / 6)
        expect(ev[4].points).toBe(6)
    end)

    test("a break point always gets at least one particle", function()
        -- At the far LOD a heavily nested shell could round to zero and vanish silently, which
        -- reads as a bug rather than as distance.
        for _, e in FireworkSchedule.compile(NESTED, 8) do
            if e.kind == "burst" then
                expect(e.particles >= 1).toBe(true)
            end
        end
    end)

    test("a recipe with no burst phases does not divide by zero", function()
        local ev = FireworkSchedule.compile({ phases = { { at = 0, kind = "report", anchor = "origin" } } }, 400)
        expect(#ev).toBe(1)
        expect(ev[1].particles).toBe(0)
    end)
end)
```

- [ ] **Step 3: Write the failing catalog tests**

Create `roblox/tests/FireworkCatalog.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local FireworkCatalog = require("../src/shared/FireworkCatalog")
local FireworkSchedule = require("../src/shared/FireworkSchedule")
local fixture = require("./fixtures/fireworkShells")

describe("FireworkCatalog — the other half of the contract", function()
    test("EVERY SHELL THE SERVER CAN SELL HAS A RECIPE", function()
        -- The gate this fixture exists for. A shell in the shop with no recipe here is a blank sky
        -- — no error, no log, and nobody would think to look for it.
        for _, id in fixture.shells do
            expect(FireworkCatalog.RECIPES[id] ~= nil).toBe(true)
        end
    end)

    test("and no recipe exists for a shell the server cannot sell", function()
        local known = {}
        for _, id in fixture.shells do
            known[id] = true
        end
        for id in FireworkCatalog.RECIPES do
            expect(known[id]).toBe(true)
        end
    end)

    test("every shell has a launch report, an ascent and at least one burst", function()
        -- A shell that skips the report has no thump at the tube and reads as a firework that
        -- started halfway through.
        for _, recipe in FireworkCatalog.RECIPES do
            local kinds = {}
            for _, ph in recipe.phases do
                kinds[ph.kind] = true
            end
            expect(kinds.report).toBe(true)
            expect(kinds.ascent).toBe(true)
            expect(kinds.burst).toBe(true)
        end
    end)

    test("every burst names a texture — an empty Texture renders NOTHING", function()
        for _, recipe in FireworkCatalog.RECIPES do
            for _, ph in recipe.phases do
                if ph.kind == "burst" then
                    expect(typeof(ph.texture)).toBe("string")
                    expect(#ph.texture > 0).toBe(true)
                end
            end
        end
    end)

    test("every recipe compiles, and stays inside a budget", function()
        for _, recipe in FireworkCatalog.RECIPES do
            local total = 0
            for _, e in FireworkSchedule.compile(recipe, 400) do
                total += e.particles * e.points
            end
            expect(total <= 400).toBe(true)
        end
    end)

    test("it holds no Roblox globals — colours are plain {r,g,b} arrays", function()
        for _, recipe in FireworkCatalog.RECIPES do
            for _, ph in recipe.phases do
                if ph.color then
                    expect(typeof(ph.color)).toBe("table")
                    expect(#ph.color).toBe(3)
                end
            end
        end
    end)
end)
```

- [ ] **Step 4: Run both to verify they fail**

Run from `roblox/`: `lune run tests/run`

Expected: FAIL — neither module exists.

- [ ] **Step 5: Write the schedule compiler**

Create `roblox/src/shared/FireworkSchedule.luau`:

```lua
--!strict
-- A RECIPE IS A LIST OF PHASES; THIS TURNS ONE INTO A TIMED SCHEDULE. Pure, so it runs under Lune —
-- which matters because the rule it carries cannot be checked any other way.
--
-- THE RULE: the particle budget is PER SHELL. A nested shell divides it across its burst phases and
-- across each phase's break points; it never multiplies. Six break points at the full near-budget
-- is six times the fill-rate the mobile floor was measured against, and it would be authored in
-- perfectly good faith by someone assuming each break looks like a normal break. The recipe cannot
-- opt out of the division, which is why `share` is a weight and not a count.
local FireworkSchedule = {}

export type Phase = {
    at: number,
    kind: string, -- "report" | "ascent" | "burst"
    anchor: string, -- "origin" (the tube) | "apex" (where the shell broke)
    points: number?, -- break points; 1 = a simple break, 6 = a nested one
    scatter: number?, -- how far those points spread from the anchor, in studs
    share: number?, -- this burst's weight in the shell's budget
    sound: string?,
    texture: string?,
    color: { number }?,
    edgeColor: { number }?,
    spread: number?,
    droop: boolean?,
}
export type Recipe = { phases: { Phase } }

export type Event = {
    at: number,
    kind: string,
    anchor: string,
    points: number,
    scatter: number,
    particles: number, -- PER BREAK POINT, not per phase
    sound: string?,
    texture: string?,
    color: { number }?,
    edgeColor: { number }?,
    spread: number?,
    droop: boolean?,
}

function FireworkSchedule.compile(recipe: Recipe, budget: number): { Event }
    local totalShare = 0
    for _, ph in recipe.phases do
        if ph.kind == "burst" then
            totalShare += ph.share or 1
        end
    end

    local out: { Event } = {}
    for _, ph in recipe.phases do
        local points = ph.points or 1
        local particles = 0
        if ph.kind == "burst" and totalShare > 0 then
            local slice = budget * ((ph.share or 1) / totalShare)
            -- Floor, then floor again per point: rounding UP anywhere here would let a nested
            -- shell creep over the budget the floor measurement bought.
            particles = math.floor(slice / points)
            -- ...but never to nothing. At the far LOD a heavily nested shell would otherwise round
            -- to zero and vanish silently, which reads as a bug rather than as distance.
            if particles < 1 then
                particles = 1
            end
        end
        table.insert(out, {
            at = ph.at,
            kind = ph.kind,
            anchor = ph.anchor,
            points = points,
            scatter = ph.scatter or 0,
            particles = particles,
            sound = ph.sound,
            texture = ph.texture,
            color = ph.color,
            edgeColor = ph.edgeColor,
            spread = ph.spread,
            droop = ph.droop,
        })
    end
    table.sort(out, function(a, b)
        return a.at < b.at
    end)
    return out
end

return FireworkSchedule
```

**Note on the floor:** the `particles < 1` clamp can push a heavily nested shell fractionally over
budget at very small budgets. That is deliberate — one particle per point is the difference between
"far away" and "broken" — and the schedule test asserts the bound at realistic budgets (90 and
above), not at pathological ones.

- [ ] **Step 6: Write the catalog**

Create `roblox/src/shared/FireworkCatalog.luau`:

```lua
--!strict
-- HOW EACH SHELL LOOKS AND SOUNDS. The other half of the contract with server/src/fireworks.ts:
-- that side owns ids, prices and requirements; this side owns the recipe. They meet at one string,
-- and FireworkCatalog.spec asserts this table covers every id the server can sell.
--
-- A RECIPE IS A LIST OF PHASES — report, ascent, burst, and (for shells beyond these four)
-- sub-bursts. FireworkController just walks the list, so adding a shell never touches it. That is
-- the whole reason for the format: the memory is explicit that many distinct shells matter to this
-- game's economics, and a fixed chain would make every new break a code change.
--
-- Pure data, no Roblox globals (colours are {r,g,b} 0-255 arrays), so it runs under Lune.
--
-- THE TEXTURE IS NOT OPTIONAL. A ParticleEmitter with Texture == "" renders nothing at all — no
-- error, no warning. Learned on the 2026-07-20 bench; see the roshambo-fireworks memory.
local FireworkCatalog = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
-- Built-in stand-ins, replaced at the art pass. Named here rather than inline so the swap is one
-- edit per sound rather than one per shell.
local S_REPORT = "rbxasset://sounds/collide.wav"
local S_ASCENT = "rbxasset://sounds/swoosh.wav"
local S_BURST = "rbxasset://sounds/impact_explosion_03.mp3"

FireworkCatalog.RECIPES = {
    -- Hand-launched: low, fast, cheap. Deliberately the least spectacular — it is the one everybody
    -- has, and the mortar shells must feel like an upgrade.
    firecracker = {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin", sound = S_REPORT },
            { at = 0.02, kind = "ascent", anchor = "origin", sound = S_ASCENT, color = { 255, 200, 120 } },
            {
                at = 0.7,
                kind = "burst",
                anchor = "apex",
                sound = S_BURST,
                texture = SPARKLE,
                color = { 255, 236, 170 },
                edgeColor = { 255, 200, 120 },
                spread = 18,
                droop = false,
            },
        },
    },
    -- The bench's proven radial break.
    peony = {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin", sound = S_REPORT },
            { at = 0.02, kind = "ascent", anchor = "origin", sound = S_ASCENT, color = { 255, 190, 200 } },
            {
                at = 1.1,
                kind = "burst",
                anchor = "apex",
                sound = S_BURST,
                texture = SPARKLE,
                color = { 255, 120, 140 },
                edgeColor = { 255, 190, 200 },
                spread = 42,
                droop = false,
            },
        },
    },
    -- The bench's proven drooping break.
    willow = {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin", sound = S_REPORT },
            { at = 0.02, kind = "ascent", anchor = "origin", sound = S_ASCENT, color = { 220, 240, 255 } },
            {
                at = 1.2,
                kind = "burst",
                anchor = "apex",
                sound = S_BURST,
                texture = SPARKLE,
                color = { 180, 220, 255 },
                edgeColor = { 220, 240, 255 },
                spread = 34,
                droop = true,
            },
        },
    },
    -- 石花, stone flower — the Rock shell. Stone-pale and slow, so the shell that only flies after
    -- an R round reads differently from the ones that fly any time.
    ishibana = {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin", sound = S_REPORT },
            { at = 0.02, kind = "ascent", anchor = "origin", sound = S_ASCENT, color = { 198, 194, 186 } },
            {
                at = 1.3,
                kind = "burst",
                anchor = "apex",
                sound = S_BURST,
                texture = SPARKLE,
                color = { 226, 222, 210 },
                edgeColor = { 198, 194, 186 },
                spread = 26,
                droop = false,
            },
        },
    },
} :: { [string]: any }

return FireworkCatalog
```

- [ ] **Step 7: Run to verify both pass, lint, and commit**

```bash
cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools && cd ..
git add roblox/src/shared/FireworkCatalog.luau roblox/src/shared/FireworkSchedule.luau roblox/tests/FireworkCatalog.spec.luau roblox/tests/FireworkSchedule.spec.luau roblox/tests/fixtures/fireworkShells.luau
git commit -m "feat(roblox): a recipe is a list of phases, and the budget divides across them"
```

---

### Task 8: The phase player — the show

Walks a compiled schedule and renders it from pools. Owns instances and nothing else: every
decision about *what* and *how much* was made in Tasks 6 and 7, both of which are tested. This file
is not, because no harness loads a `.client.luau`.

**Files:**
- Create: `roblox/src/client/FireworkController.client.luau`
- Modify: `roblox/default.project.json` (only if client scripts are listed individually)

**Interfaces:**
- Consumes: `FireworkSchedule.compile`, `FireworkCatalog.RECIPES` (Task 7); `FireworkDirector.admit/lodFor` (Task 6); the `FireworkLaunched` remote (Task 5).
- Produces: nothing downstream.

- [ ] **Step 1: Write the controller**

Create `roblox/src/client/FireworkController.client.luau`:

```lua
--!strict
-- THE PHASE PLAYER. Compiles a recipe against the distance-appropriate budget and executes the
-- resulting schedule from fixed pools. It knows nothing about any particular shell — a new shell is
-- a row in FireworkCatalog and this file does not change.
--
-- THREE LESSONS THE 2026-07-20 BENCH PAID FOR, none of them optional:
--   1. ParticleEmitter:Emit() does NOT replicate server->client. Emission happens HERE, on each
--      client, from a tiny server event. A server-side :Emit() is simply invisible.
--   2. An emitter with Texture == "" renders nothing. Every burst phase names one.
--   3. Launch relative to something real. The bench's first pass fired at the world origin, 110
--      studs below the player, and showed nothing.
--
-- NO PER-SHELL DYNAMIC LIGHTS. The single biggest killer on mobile. Glow is LightEmission plus the
-- one global Bloom; a PointLight per burst would undo the entire budget.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local FireworkCatalog = require(shared:WaitForChild("FireworkCatalog"))
local FireworkSchedule = require(shared:WaitForChild("FireworkSchedule"))
local FireworkDirector = require(shared:WaitForChild("FireworkDirector"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local FireworkLaunched = remotes:WaitForChild("FireworkLaunched") :: RemoteEvent

-- One global Bloom, created once. This is the glow; per-shell lights are forbidden.
if not Lighting:FindFirstChild("FireworkBloom") then
    local bloom = Instance.new("BloomEffect")
    bloom.Name = "FireworkBloom"
    bloom.Intensity = 0.6
    bloom.Size = 24
    bloom.Threshold = 0.95
    bloom.Parent = Lighting
end

local folder = Instance.new("Folder")
folder.Name = "FireworkPool"
folder.Parent = workspace

-- MAX_POINTS burst parts per slot, because a nested break happens at several places AT ONCE and
-- :Emit() fires wherever its part currently is — one part cannot be in six places in one frame.
local MAX_POINTS = 8
local POOL_SIZE = FireworkDirector.MAX_CONCURRENT + 4

type Slot = { shell: BasePart, trail: Trail, points: { BasePart }, emitters: { ParticleEmitter }, sound: Sound }
local pool: { Slot } = {}
local poolNext = 1
local active = 0

for _ = 1, POOL_SIZE do
    local shell = Instance.new("Part")
    shell.Anchored, shell.CanCollide, shell.CanQuery, shell.CanTouch = true, false, false, false
    shell.Transparency = 1
    shell.Size = Vector3.new(1, 1, 1)
    shell.Parent = folder

    -- The ascent comet. A Trail is property-driven rather than :Emit()-driven, so unlike the burst
    -- it WOULD have replicated from the server — it lives here anyway so a shell is one pooled
    -- object with one lifetime.
    local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
    a0.Position, a1.Position = Vector3.new(0, -0.5, 0), Vector3.new(0, 0.5, 0)
    a0.Parent, a1.Parent = shell, shell
    local trail = Instance.new("Trail")
    trail.Attachment0, trail.Attachment1 = a0, a1
    trail.Lifetime = 0.45
    trail.LightEmission = 1
    trail.Enabled = false
    trail.Parent = shell

    -- ONE Sound per slot, not one per phase. A shell's phases never overlap in time, and a
    -- sub-burst volley plays ONE report rather than six — six voices of one clip is noise and six
    -- times the mixer cost.
    local snd = Instance.new("Sound")
    snd.RollOffMode = Enum.RollOffMode.InverseTapered
    snd.RollOffMaxDistance = FireworkDirector.NEAR_STUDS
    snd.Parent = shell

    local points, emitters = {}, {}
    for _ = 1, MAX_POINTS do
        local p = Instance.new("Part")
        p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
        p.Transparency = 1
        p.Size = Vector3.new(1, 1, 1)
        p.Parent = folder
        local em = Instance.new("ParticleEmitter")
        em.Enabled = false -- burst-only; :Emit() drives it
        em.LightEmission = 1
        em.Rate = 0
        em.Speed = NumberRange.new(20, 60)
        em.Lifetime = NumberRange.new(1.2, 2.4)
        em.Parent = p
        table.insert(points, p)
        table.insert(emitters, em)
    end

    table.insert(pool, { shell = shell, trail = trail, points = points, emitters = emitters, sound = snd })
end

local function colorOf(rgb: { number }): Color3
    return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function playSound(slot: Slot, id: string?, audible: boolean)
    if id and audible then
        slot.sound.SoundId = id
        slot.sound:Play()
    end
end

local function fireBurst(slot: Slot, ev: any, anchorPos: Vector3, rng: Random)
    -- `points` break locations scattered around the anchor. `particles` is PER POINT — the schedule
    -- already divided the shell's budget, so this must never multiply it back up.
    local n = math.min(ev.points, MAX_POINTS)
    for i = 1, n do
        local p, em = slot.points[i], slot.emitters[i]
        local off = if ev.scatter > 0
            then Vector3.new(
                rng:NextNumber(-ev.scatter, ev.scatter),
                rng:NextNumber(-ev.scatter, ev.scatter) * 0.6,
                rng:NextNumber(-ev.scatter, ev.scatter)
            )
            else Vector3.zero
        p.Position = anchorPos + off
        em.Texture = ev.texture
        em.Color = ColorSequence.new(colorOf(ev.color), colorOf(ev.edgeColor or ev.color))
        em.Size = NumberSequence.new((ev.spread or 30) / 40)
        em.Acceleration = if ev.droop then Vector3.new(0, -28, 0) else Vector3.new(0, -6, 0)
        em:Emit(ev.particles)
    end
end

local function play(payload: any, distance: number)
    local recipe = FireworkCatalog.RECIPES[payload.shellId]
    if not recipe then
        return -- the contract test exists so this cannot happen in a shipped build
    end
    local slot = pool[poolNext]
    poolNext = (poolNext % POOL_SIZE) + 1

    local lod = FireworkDirector.lodFor(distance)
    local schedule = FireworkSchedule.compile(recipe, lod.particles)

    -- THE SEED IS WHY EVERY CLIENT SEES THE SAME SHOW. Without it each machine rolls its own
    -- apex and its own scatter, and two people watching one firework cannot talk about what they
    -- saw. The server sends one per launch.
    local rng = Random.new(payload.seed)
    local origin = payload.origin
    local apex = origin
        + Vector3.new(rng:NextNumber(-8, 8), 46 + rng:NextNumber(-6, 6), rng:NextNumber(-8, 8))

    local last = 0
    for _, ev in schedule do
        last = math.max(last, ev.at)
    end

    active += 1
    for _, ev in schedule do
        task.delay(ev.at, function()
            local anchorPos = if ev.anchor == "apex" then apex else origin
            if ev.kind == "report" then
                slot.shell.Position = origin
                playSound(slot, ev.sound, lod.sound)
            elseif ev.kind == "ascent" then
                slot.shell.Position = origin
                slot.trail.Color = ColorSequence.new(colorOf(ev.color or { 255, 255, 255 }))
                slot.trail.Enabled = true
                playSound(slot, ev.sound, lod.sound)
                -- The comet rises to the apex over whatever time the next phase leaves it.
                local rise = math.max(0.05, last - ev.at)
                TweenService
                    :Create(
                        slot.shell,
                        TweenInfo.new(rise, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        { Position = apex }
                    )
                    :Play()
            elseif ev.kind == "burst" then
                slot.trail.Enabled = false
                playSound(slot, ev.sound, lod.sound)
                fireBurst(slot, ev, anchorPos, rng)
            end
        end)
    end

    -- Released after the last phase plus the longest particle lifetime, so the slot is not reused
    -- while its own sparks are still on screen.
    task.delay(last + 2.6, function()
        active -= 1
        slot.trail.Enabled = false
    end)
end

FireworkLaunched.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" or typeof(payload.origin) ~= "Vector3" or typeof(payload.seed) ~= "number" then
        return
    end
    local cam = workspace.CurrentCamera
    local distance = if cam then (cam.CFrame.Position - payload.origin).Magnitude else 0
    local decision = FireworkDirector.admit(active, distance)
    if not decision.render then
        return
    end
    if decision.delayMs > 0 then
        task.delay(decision.delayMs / 1000, function()
            play(payload, distance)
        end)
    else
        play(payload, distance)
    end
end)

local _ = Players -- required for the picker in the next task; kept to avoid churning this file
```

- [ ] **Step 2: Confirm the Rojo mapping**

```bash
grep -n "src/client" roblox/default.project.json
```

If the directory is mapped wholesale, no change is needed. If scripts are listed individually, add
`FireworkController` alongside the others.

- [ ] **Step 3: Run every gate**

```bash
cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools && cd ..
```

Expected: PASS, clean, zero warnings. **Note what this does and does not prove:** the suite never
loads this file. Green here means Tasks 6 and 7 still pass, not that a firework appears.

- [ ] **Step 4: Commit**

```bash
git add roblox/src/client/FireworkController.client.luau roblox/default.project.json
git commit -m "feat(roblox): the phase player — report, ascent, burst, sub-bursts, and their sounds"
```

---

### Task 9: The picker

The site-triggered button and the four tiles. This is the last task and none of it is testable — read every line.

**Files:**
- Modify: `roblox/src/client/HudController.client.luau`
- Modify: `roblox/src/client/main.client.luau`

**Interfaces:**
- Consumes: the `FireworkState` remote (Task 5) — `{ shells = { [id] = { count, launchable, reason } }, mortars = { string } }`; `RequestFireworkLaunch` (Task 5).
- Produces: nothing downstream.

- [ ] **Step 1: Relay the state to the HUD**

In `roblox/src/client/main.client.luau`, add beside the other remote lookups:

```lua
local FireworkState = remotes:WaitForChild("FireworkState") :: RemoteEvent
local RequestFireworkLaunch = remotes:WaitForChild("RequestFireworkLaunch") :: RemoteEvent
```

Hold the latest state and publish it on `aux`, exactly as `openSeconds` is published — render-only, never a `HudModel` input:

```lua
-- The server's answer about every shell: how many you hold, whether it can fly, and if not, why.
-- THE CLIENT NEVER EVALUATES A REQUIREMENT. It does not know what a mortar is and does not read the
-- tape; it renders `reason`. A requirement that depends on round history is exactly the kind of
-- fact this codebase has repeatedly re-derived client-side and got wrong.
local fireworkShells: any = nil
FireworkState.OnClientEvent:Connect(function(state)
    if typeof(state) == "table" then
        fireworkShells = state.shells
        publish()
    end
end)
```

Add `fireworkShells = fireworkShells,` to the `aux` table in `publish()`, and update the `aux` doc comment at the top of both `main.client.luau` and `HudController.client.luau` to list it.

Add a launch bridge beside the other `EventBus` subscriptions:

```lua
EventBus.HudFireworkLaunch.Event:Connect(function(shellId: string)
    RequestFireworkLaunch:FireServer(shellId)
end)
```

Add `HudFireworkLaunch` to `roblox/src/client/EventBus.luau` following the pattern of the existing signals there.

- [ ] **Step 2: Track whether the player is at a launch site**

In `roblox/src/client/HudController.client.luau`, the button must appear only where it works. Add near the other `CollectionService` usage, or add the service if absent:

```lua
-- THE AFFORDANCE APPEARS WHERE IT WORKS. Stepping onto a site is what tells a player they can
-- launch — no copy required, which matters more than usual with onboarding deferred. Checked on a
-- timer rather than per frame: the answer changes at walking pace, and this runs on phones.
local CollectionService = game:GetService("CollectionService")
local SITE_RADIUS = 24
local atLaunchSite = false

task.spawn(function()
    while true do
        local char = Players.LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local near = false
        if root then
            for _, part in CollectionService:GetTagged("FireworkLaunchSite") do
                if part:IsA("BasePart") then
                    local d = part.Position - root.Position
                    if d.X * d.X + d.Z * d.Z <= SITE_RADIUS * SITE_RADIUS then
                        near = true
                        break
                    end
                end
            end
        end
        atLaunchSite = near
        task.wait(0.5)
    end
end)
```

**The client's site check is an affordance, not a gate.** The server re-validates every launch (Task 5) and a player's own deck is only a site server-side — so this check being generous or stale can never let an invalid launch through, only offer a button that gets refused.

- [ ] **Step 3: Build the picker**

Add this near the other panel builders in `HudController.client.luau`:

```lua
-- THE PICKER. Fixed order, built once, painted per render — the same shape the throw buttons and
-- the tape tiles use. Four tiles is the whole catalogue: a player should be able to see what exists
-- and why they cannot fire it yet, which is why a shell held at zero still gets a tile.
local SHELL_ORDER = { "firecracker", "peony", "willow", "ishibana" }
local SHELL_NAME: { [string]: string } = {
    firecracker = "Firecracker",
    peony = "Peony",
    willow = "Willow",
    ishibana = "Ishibana",
}
-- Reasons arrive as symbols from the server and are turned into copy HERE. An unmapped reason
-- falls back to the symbol rather than to an empty label: a player seeing "NEEDS_MORTAR_XL" learns
-- something; a player seeing a blank tile learns nothing and reports a bug that is really a typo.
local REASON_COPY: { [string]: string } = {
    NONE_HELD = "none left",
    NEEDS_MORTAR_S = "needs a small mortar",
    NEEDS_MORTAR_M = "needs a medium mortar",
    NEEDS_MORTAR_L = "needs a large mortar",
    WAITING_FOR_R = "waiting for Rock",
    BAD_SHELL = "unavailable",
}

local fireworkPanel = Instance.new("Frame")
fireworkPanel.Name = "FireworkPicker"
fireworkPanel.AnchorPoint = Vector2.new(0.5, 1)
fireworkPanel.Position = UDim2.new(0.5, 0, 1, -HudLayout.CLUSTER_TOP_FROM_BOTTOM - HudLayout.BANK_GAP)
fireworkPanel.Size = UDim2.fromOffset(BTN_W * 4 + 8 * 3, BTN_H)
fireworkPanel.BackgroundTransparency = 1
fireworkPanel.Visible = false
fireworkPanel.ZIndex = 6
fireworkPanel.Parent = gui

local shellTiles: { [string]: { button: TextButton, count: TextLabel, sub: TextLabel } } = {}
-- Declared BEFORE the loop so the click handlers close over it. `paintFireworkTiles` is the only
-- writer, so a tap always tests exactly the state the tile was painted from.
local shellStates: any = nil

for i, id in SHELL_ORDER do
    local b = Instance.new("TextButton")
    b.Name = id
    b.Size = UDim2.fromOffset(BTN_W, BTN_H)
    b.Position = UDim2.fromOffset((i - 1) * (BTN_W + 8), 0)
    b.BackgroundColor3 = IVORY
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = SHELL_NAME[id]
    b.TextColor3 = INK
    b.TextSize = 15
    b.ZIndex = 6
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = b
    b.Parent = fireworkPanel

    local count = Instance.new("TextLabel")
    count.Size = UDim2.new(1, 0, 0, 16)
    count.Position = UDim2.new(0, 0, 0, 4)
    count.BackgroundTransparency = 1
    count.TextColor3 = INK
    count.TextSize = 14
    count.ZIndex = 6
    count.Parent = b

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -6, 0, 26)
    sub.Position = UDim2.new(0, 3, 1, -28)
    sub.BackgroundTransparency = 1
    sub.TextColor3 = INK
    sub.TextSize = 11
    sub.TextWrapped = true
    sub.ZIndex = 6
    sub.Parent = b

    -- Only a launchable shell fires. The check is repeated on the server (Task 5), so this is an
    -- affordance rather than a gate — but a tile that does nothing when tapped reads as broken, so
    -- the greyed state has to be visibly un-tappable, not silently inert.
    b.MouseButton1Click:Connect(function()
        local st = shellStates and shellStates[id]
        if st and st.launchable then
            EventBus.HudFireworkLaunch:Fire(id)
        end
    end)

    shellTiles[id] = { button = b, count = count, sub = sub }
end

local function paintFireworkTiles(states: any)
    shellStates = states
    for _, id in SHELL_ORDER do
        local st = states[id]
        local tile = shellTiles[id]
        local live = st ~= nil and st.launchable == true
        tile.count.Text = if st then `×{st.count}` else ""
        tile.sub.Text = if live then "" else REASON_COPY[st and st.reason or ""] or (st and st.reason or "")
        -- Dim rather than hide: the catalogue stays visible so a player can see what a mortar buys.
        tile.button.BackgroundTransparency = if live then 0 else 0.55
        tile.button.TextTransparency = if live then 0 else 0.35
        tile.count.TextTransparency = tile.button.TextTransparency
    end
end
```

`BTN_W`, `BTN_H`, `IVORY`, `INK` and `gui` are this file's existing constants and root — use them
rather than introducing new ones.

- [ ] **Step 4: Show the panel only at a site**

In `render`, add:

```lua
    -- The picker is the only HUD element gated on WHERE the player is standing. Everything else in
    -- this cluster is about the round; this is about the ground under their feet.
    fireworkPanel.Visible = atLaunchSite and aux.fireworkShells ~= nil
    if fireworkPanel.Visible then
        paintFireworkTiles(aux.fireworkShells)
    end
```

`paintFireworkTiles` sets each tile's count, fill and label from the state table — and reads `launchable` and `reason` **as given**, deriving nothing.

- [ ] **Step 5: Verify no requirement logic leaked into the client**

Run from `roblox/`:

```bash
grep -rn "mortar\|lastWorldThrow\|WAITING_FOR" src/client/ | grep -v REASON_COPY
```

Expected: **no output except the copy table.** Any comparison against a mortar id or a world throw in client code means a requirement is being evaluated in two places, which is the defect this plan's global constraints exist to prevent.

- [ ] **Step 6: Run every gate**

```bash
cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools && cd ..
cd server && npm test && npm run build && cd ..
```

Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add roblox/src/client/ roblox/src/shared/
git commit -m "feat(roblox): the firework picker, offered where it works"
```

---

## The Studio gate

**Nothing in tasks 5, 8 and 9 is covered by any test.** No harness loads a `.client.luau`, selene does not resolve cross-module field types, and `main.server.luau` is invisible to the Lune runner. The suite being green says nothing about whether a firework appears.

Push server and Roblox together — a version mismatch here is the same hazard as the round rename, and the poll loop is still not `pcall`-wrapped.

Then, in Studio:

1. **Tag some launch sites.** Add `FireworkLaunchSite` to parts at the falls dock, the clearing edge and the high mid-canyon bridge — the three places the canyon was designed around as viewing perches. Save the place.
2. **The button appears when you step on, and goes when you step off.**
3. **A firecracker fires and the count goes down.** Win a round first, or buy one for a point.
4. **The peony is greyed with "needs a small mortar"** until you buy `mortar:S`, then flies.
5. **`ishibana` is greyed with "waiting for Rock"**, and becomes launchable in the round after the world throws `R` — the one thing here that cannot be checked without waiting for the right round.
6. **Two people firing at once** still looks right and holds frame rate.
7. **The far rim.** Walk up-canyon and confirm distant bursts thin out rather than vanishing abruptly, and that nothing renders past the drop distance.

Items 3–5 are correctness. Item 6 is the whole perf argument, and item 7 is the only way to see whether the LOD bands are in the right place.
