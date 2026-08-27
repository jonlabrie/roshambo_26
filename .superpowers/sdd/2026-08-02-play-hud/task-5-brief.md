### Task 5: Expose the ledger fields on the profile route

The Roblox client reads the profile via `GET /players/:robloxUserId`. It must carry the counters, the gate and the preference, or the ledger has nothing to render.

**Files:**
- Modify: `server/src/routes/apiV1.ts:85-107` (the `GET /players/:robloxUserId` handler)
- Modify: `server/src/routes/apiV1.ts` (add `PUT /players/:robloxUserId/preferences-hud`)
- Test: extend `server/src/routes/apiV1.test.ts` (exists — read it first, match its style)

**Interfaces:**
- Produces: the profile response gains `unresolvedWin`, `escalationPrompts`, `seenBeats`, and a
  `counters` object `{ roundsPlayed, wins, safes, losses, lifetimeBanked, bestPot, throwsR, throwsP, throwsS }`.
- Produces: `PUT /players/:robloxUserId/preferences-hud`, body `{ escalationPrompts?: boolean, seenBeat?: string }`.

- [ ] **Step 1: Write the failing test**

Add to `server/src/routes/apiV1.test.ts`. `buildProfilePayload` is pure, so these cases need no
database — add it to that file's existing import from `./apiV1`.

```ts
describe('buildProfilePayload', () => {
    it('carries the gate, the preference and every counter', () => {
        const p = buildProfilePayload({
            totalPoints: 1240, pointsAtStake: 27, currentStreak: 3, stakingStreak: 3, bestStreak: 6,
            unresolvedWin: true, escalationPrompts: false, seenBeats: ['drum'],
            roundsPlayed: 386, wins: 131, safes: 92, losses: 163,
            lifetimeBanked: 1240, bestPot: 243, throwsR: 181, throwsP: 120, throwsS: 85,
        } as never);
        expect(p.unresolvedWin).toBe(true);
        expect(p.escalationPrompts).toBe(false);
        expect(p.seenBeats).toEqual(['drum']);
        expect(p.counters.roundsPlayed).toBe(386);
        expect(p.counters.throwsS).toBe(85);
    });

    it('tolerates a document written before these fields existed', () => {
        // no migration was run, so old docs simply lack the keys
        const p = buildProfilePayload({ totalPoints: 5, pointsAtStake: 0, currentStreak: 0,
            stakingStreak: 0, bestStreak: 0 } as never);
        expect(p.unresolvedWin).toBe(false);
        expect(p.escalationPrompts).toBe(true);
        expect(p.seenBeats).toEqual([]);
        expect(p.counters.roundsPlayed).toBe(0);
    });
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `npm test -- apiV1`
Expected: FAIL — `buildProfilePayload` is not exported.

- [ ] **Step 3: Extract and extend the payload builder**

Add to `apiV1.ts`, above `createApiV1Router` (or wherever the router factory begins), and export it:

```ts
// Extracted so the shape is testable without a request. Every field is defaulted: no migration
// was run for the 2026-08-02 play-HUD fields, so documents written before them lack the keys.
export function buildProfilePayload(user: IUser) {
    return {
        totalPoints: user.totalPoints,
        pointsAtStake: user.pointsAtStake,
        currentStreak: user.currentStreak,
        stakingStreak: user.stakingStreak,
        bestStreak: user.bestStreak,
        unresolvedWin: user.unresolvedWin ?? false,
        escalationPrompts: user.escalationPrompts ?? true,
        seenBeats: user.seenBeats ?? [],
        counters: {
            roundsPlayed: user.roundsPlayed ?? 0,
            wins: user.wins ?? 0,
            safes: user.safes ?? 0,
            losses: user.losses ?? 0,
            lifetimeBanked: user.lifetimeBanked ?? 0,
            bestPot: user.bestPot ?? 0,
            throwsR: user.throwsR ?? 0,
            throwsP: user.throwsP ?? 0,
            throwsS: user.throwsS ?? 0,
        },
    };
}
```

Replace the body of the existing `GET /players/:robloxUserId` `res.json({...})` with
`res.json(buildProfilePayload(user));`, preserving any fields that handler already returns which
are not in the list above (read it before editing — do not drop anything).

- [ ] **Step 4: Add the preference route**

```ts
    router.put('/players/:robloxUserId/preferences-hud', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: String(req.params.robloxUserId) });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const set: Record<string, unknown> = {};
            if (typeof req.body?.escalationPrompts === 'boolean') {
                set.escalationPrompts = req.body.escalationPrompts;
            }
            // seenBeat is add-only: a beat can be marked seen but never un-seen from the client
            const addToSet = typeof req.body?.seenBeat === 'string'
                ? { seenBeats: req.body.seenBeat } : undefined;
            if (!Object.keys(set).length && !addToSet) {
                res.status(400).json({ error: 'BAD_REQUEST' });
                return;
            }
            const updated = await User.findByIdAndUpdate(
                user._id,
                { ...(Object.keys(set).length ? { $set: set } : {}), ...(addToSet ? { $addToSet: addToSet } : {}) },
                { new: true }
            );
            const s = updated ?? user;
            res.json({ escalationPrompts: s.escalationPrompts ?? true, seenBeats: s.seenBeats ?? [] });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });
```

- [ ] **Step 5: Run the tests**

Run: `npm test` → PASS.

- [ ] **Step 6: Commit**

```bash
git add server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "feat(server): profile route carries ledger counters, win gate and HUD preferences"
```

---

