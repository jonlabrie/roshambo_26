### Task 2: Profile fields for the ledger, the win gate and onboarding

Twelve new fields on `User`, all defaulted so existing documents keep working with no migration.

**Files:**
- Modify: `server/src/models/User.ts:14-30` (interface), `:44-62` (schema)
- Test: extend `server/src/models/models.test.ts` (exists — read it first, match its style)

**Interfaces:**
- Produces: `IUser` gains `unresolvedWin: boolean`, `escalationPrompts: boolean`, `seenBeats: string[]`, and counters `roundsPlayed`, `wins`, `safes`, `losses`, `lifetimeBanked`, `bestPot`, `throwsR`, `throwsP`, `throwsS` (all `number`).

- [ ] **Step 1: Write the failing test**

Add to `server/src/models/models.test.ts`, following its existing imports and setup hooks.
`new User({...})` applies schema defaults without touching the database, so these two cases need
no `connectTestDb`; if the surrounding file connects anyway, follow it.

```ts
describe('User defaults — play HUD fields', () => {
    it('defaults every new play-HUD field so existing docs need no migration', () => {
        const u = new User({ deviceId: 'd1' });
        expect(u.unresolvedWin).toBe(false);
        expect(u.escalationPrompts).toBe(true); // prompts are on until the player turns them off
        expect(u.seenBeats).toEqual([]);
        for (const k of ['roundsPlayed', 'wins', 'safes', 'losses', 'lifetimeBanked', 'bestPot',
                         'throwsR', 'throwsP', 'throwsS'] as const) {
            expect(u[k]).toBe(0);
        }
    });

    it('unresolvedWin is independent of pointsAtStake', () => {
        // the whole reason it needs its own field: after choosing RISK the pot still rides,
        // so pointsAtStake > 0 is true in BOTH the bound and unbound states
        const u = new User({ deviceId: 'd2', pointsAtStake: 27, unresolvedWin: false });
        expect(u.pointsAtStake).toBe(27);
        expect(u.unresolvedWin).toBe(false);
    });
});
```

- [ ] **Step 2: Run it to verify it fails**

Run from `server/`: `npm test -- models`
Expected: FAIL — `u.unresolvedWin` is `undefined`.

- [ ] **Step 3: Add the fields**

In the `IUser` interface, after `pointsAtStake: number;`:

```ts
    // Play HUD (2026-08-02). unresolvedWin is NOT derivable from pointsAtStake: after choosing
    // RISK the pot still rides, so that value is identical in the bound and unbound states.
    unresolvedWin: boolean;
    escalationPrompts: boolean;
    seenBeats: string[];
    roundsPlayed: number;
    wins: number;
    safes: number;
    losses: number;
    lifetimeBanked: number;
    bestPot: number;
    throwsR: number;
    throwsP: number;
    throwsS: number;
```

In the schema, after `pointsAtStake: { type: Number, default: 0 },`:

```ts
    unresolvedWin: { type: Boolean, default: false },
    escalationPrompts: { type: Boolean, default: true },
    seenBeats: { type: [String], default: [] },
    roundsPlayed: { type: Number, default: 0 },
    wins: { type: Number, default: 0 },
    safes: { type: Number, default: 0 },
    losses: { type: Number, default: 0 },
    lifetimeBanked: { type: Number, default: 0 },
    bestPot: { type: Number, default: 0 },
    throwsR: { type: Number, default: 0 },
    throwsP: { type: Number, default: 0 },
    throwsS: { type: Number, default: 0 },
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `npm test -- models` → PASS.

- [ ] **Step 5: Commit**

```bash
git add server/src/models/User.ts server/src/models/models.test.ts
git commit -m "feat(server): profile fields for the ledger, win gate and onboarding"
```

---

