export type Throw = 'R' | 'P' | 'S';
export type RoundResult = 'WIN' | 'SAFE' | 'LOSS';

const BEATS: Record<Throw, Throw> = { R: 'S', P: 'R', S: 'P' };

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

// Delta recorded on PlayerRound. NB: on WIN the recorded delta is the NEW pot
// value (characterized from production behavior), not the increment.
export function potDelta(currentPot: number, result: RoundResult): number {
    if (result === 'WIN') return nextPot(currentPot, 'WIN');
    if (result === 'LOSS') return currentPot === 0 ? 0 : -currentPot;
    return 0;
}

// Streaks (both currentStreak and stakingStreak) survive only on WIN.
export function nextStreak(currentStreak: number, result: RoundResult): number {
    return result === 'WIN' ? currentStreak + 1 : 0;
}
