// Parked defect (e), fixed 2026-09-05: the TEST_MODE world-throw cycle used to seed its phase
// from `Round.countDocuments()` -- a COUNT standing in for a PHASE. The two drift (rounds tick
// every minute; documents only exist once a round with participants persists), so every deploy
// re-rolled the phase and could land the same face twice under a player mid-session (observed
// 2026-08-03 on dev). The real state to carry across a restart is the last face actually
// SHOWN: this helper computes the shift that makes the cycle's next pick the successor of the
// last PERSISTED round's world throw, whatever the in-memory roundCount was seeded to.
const THROWS = ['R', 'P', 'S'] as const;

/**
 * Shift such that `THROWS[(roundCount + shift) % 3]` continues the R->P->S cycle from the
 * last persisted world throw. No persisted rounds (or an unrecognized face) starts at 'R'.
 */
export function testModePhaseShift(lastPersistedThrow: string | undefined, bootRoundCount: number): number {
    const lastIdx = THROWS.indexOf(lastPersistedThrow as (typeof THROWS)[number]);
    const nextIdx = (lastIdx + 1) % 3; // indexOf miss = -1 -> next 0 = 'R'
    return (((nextIdx - bootRoundCount) % 3) + 3) % 3;
}
