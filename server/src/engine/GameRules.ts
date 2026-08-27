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

// PARTIAL BANKING: a pot may be dropped to a LOWER RUNG, banking the difference.
//
// WHY RUNGS AND NOT A SLIDER. A continuous fraction turns Bank-vs-Stake into an optimisation with
// a computable answer; three or four discrete choices keep it a judgement call. Rungs also mean
// every pot stays a power of three and every banked difference is an integer, so "never 13.5"
// holds by construction rather than by rounding (owner, 2026-08-26).
//
// Returns every ladder value strictly below `pot`, ascending, 0 first. 0 is the full bank, which
// is why `bankPot`'s default keep of 0 reproduces today's behaviour exactly.
export function keepOptions(pot: number): number[] {
    if (!Number.isFinite(pot) || pot <= 0) return [];
    const options = [0];
    // Walk the ladder 1, 3, 9, ... and stop before reaching the pot itself.
    for (let rung = 1; rung < pot; rung *= 3) options.push(rung);
    return options;
}

export function isValidKeep(pot: number, keep: number): boolean {
    // ⚠ DEFENCE, NOT THE FRACTIONAL CHECK THAT ACTUALLY BITES. No rung is ever fractional, so
    // membership below already rejects 13.5 -- mutation testing showed the fixture's 13.5 row
    // passes with this line deleted. It stays as a guard on the day keepOptions changes shape,
    // but do not read the fixture as proving it.
    if (!Number.isInteger(keep)) return false;
    return keepOptions(pot).includes(keep);
}

// ── The World Throw ──────────────────────────────────────────────────────────
// THE PREMISE: the World Throw is what the crowd threw — "you against the world".
// See docs/wiki/world/world-throw.md. Deriving it from the round's own tally is what
// makes reading the crowd a skill; picking it at random made every outcome fortune
// (parked defect (h)).
//
// PLURALITY, NOT MAJORITY. With three options a true majority (>50%) frequently does
// not exist — R 40 / P 35 / S 25 has none — so the rule is argmax. "Majority" is the
// product word; plurality is the implementation, and they differ often enough to matter.
//
// Two fallbacks to random, both deliberate:
//  * A TIE for top picks randomly AMONG THE TIED ONLY — never a throw nobody made.
//  * Below `minParticipants` the crowd is too small to be a "world" at all. Worse, at
//    small N a player's own throw is decisive: joining either side of a 2-2 split
//    CREATES the plurality they needed to beat, so they can only draw. Falling back to
//    random keeps such rounds playable instead of degenerate. A solo player would
//    otherwise set the World Throw single-handedly and be permanently SAFE.
export interface WorldThrowOptions {
    minParticipants?: number;
    random?: () => number; // injectable so the fallbacks are testable
}

const ALL_THROWS: Throw[] = ['R', 'P', 'S'];

export function deriveWorldThrow(counts: Record<Throw, number>, opts: WorldThrowOptions = {}): Throw {
    const minParticipants = opts.minParticipants ?? 5;
    const random = opts.random ?? Math.random;
    // guard a random() of exactly 1 so the index can never fall off the end
    const pick = (pool: Throw[]): Throw => pool[Math.min(pool.length - 1, Math.floor(random() * pool.length))];

    const total = counts.R + counts.P + counts.S;
    if (total < minParticipants) return pick(ALL_THROWS);

    const top = Math.max(counts.R, counts.P, counts.S);
    const tied = ALL_THROWS.filter(t => counts[t] === top);
    return tied.length === 1 ? tied[0] : pick(tied);
}
