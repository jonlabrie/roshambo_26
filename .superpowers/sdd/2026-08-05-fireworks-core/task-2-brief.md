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

