// THE GAME'S RULES, PWA COPY — the third of three, and until 2026-08-05 the only one nothing
// tested.
//
// `server/src/engine/GameRules.ts` is authoritative. `roblox/src/shared/GameRules.luau` mirrors it
// and is held to `shared-fixtures/game-rules.json`, so drift there fails CI. This copy existed too,
// inline inside `useGameLoop.ts` — the matchup table in a `useCallback` and the pot math as two
// lines in the reveal handler — with no test of any kind, because the frontend had no test runner.
// It is extracted here so it can run the SAME fixtures the other two do. Keep the function names
// and signatures identical to the server's: a reader comparing the two should see one file twice,
// not two designs.
//
// WHY A COPY EXISTS AT ALL: the server sends the authoritative per-player result on `player-data`,
// and this is the fallback for the case where it has not arrived — a spectator, or a round this
// client threw in but whose settlement is still in flight. It is not the primary path and must
// never be treated as one.

export type Throw = 'R' | 'P' | 'S';
export type RoundResult = 'WIN' | 'SAFE' | 'LOSS';

const BEATS: Record<Throw, Throw> = { R: 'S', P: 'R', S: 'P' };

// Matching the World Throw is SAFE — the pot is preserved, not forfeited. (requirements.md calls a
// match a LOSS; the code has been the source of truth on that since long before this file.)
export function calculateResult(player: Throw, world: Throw): RoundResult {
    if (player === world) return 'SAFE';
    return BEATS[player] === world ? 'WIN' : 'LOSS';
}

// Pot math: 0 -> 1 -> 3 -> 9 -> 27 ... (3^n). SAFE preserves the pot; LOSS forfeits it.
export function nextPot(currentPot: number, result: RoundResult): number {
    if (result === 'WIN') return currentPot === 0 ? 1 : currentPot * 3;
    if (result === 'LOSS') return 0;
    return currentPot;
}

// NB: on WIN the recorded delta is the NEW pot value, not the increment — characterized from
// production behaviour, and the fixtures pin it.
export function potDelta(currentPot: number, result: RoundResult): number {
    if (result === 'WIN') return nextPot(currentPot, 'WIN');
    if (result === 'LOSS') return currentPot === 0 ? 0 : -currentPot;
    return 0;
}

// Streaks survive only on WIN.
export function nextStreak(currentStreak: number, result: RoundResult): number {
    return result === 'WIN' ? currentStreak + 1 : 0;
}
