// THE CATALOG IS DATA, AND TWO FAMILIES ARE POWERS. Depth and Career generate new milestones
// indefinitely without anyone hand-authoring a hundred achievements, and their spacing gets
// naturally harder exactly where the ladder does.
//
// WHY MILESTONES AND NOT A RATE OR A CLOCK (owner ruling, 2026-08-18). A rate is an INFERENCE and
// inference needs sample — that is where the 360-throw floor comes from, and why a rate board sits
// empty for a week. A milestone is an EVENT: exactly true the moment it happens. So grading needs
// no sample, is unaffected by TEST_MODE (the World Throw is a fixed R->P->S cycle in every
// environment today, so nothing skill-derived can be validated), and cannot be lost by logging
// off — which matters, because the program's bar reads "rounds skippable, no penalty".
//
// EARN-ONCE AND MONOTONIC. `bestPot` is kept via $max and `lifetimeBanked` never decreases, so
// both are safe bases. NEVER build one on `totalPoints` — it is a wallet, decremented by
// purchases, so the milestone would be revoked by shopping.
export interface MilestoneStats {
    bestPot: number;
    lifetimeBanked: number;
    bestStreak: number;
    weekThrows: number;
    hasBanked: boolean;
    hasWon: boolean;
}

export interface Milestone {
    id: string;
    earned: (s: MilestoneStats) => boolean;
}

const POT_STEPS = [9, 27, 81, 243, 729, 2187, 6561, 19683];
const CAREER_STEPS = [100, 1000, 10000, 100000, 1000000];
const RUN_STEPS = [3, 5, 7, 10];

export const CATALOG: Milestone[] = [
    { id: 'first.win', earned: s => s.hasWon },
    { id: 'first.bank', earned: s => s.hasBanked },
    { id: 'presence.qualified', earned: s => s.weekThrows >= 360 },
    ...POT_STEPS.map(n => ({ id: `pot.${n}`, earned: (s: MilestoneStats) => s.bestPot >= n })),
    ...CAREER_STEPS.map(n => ({ id: `career.${n}`, earned: (s: MilestoneStats) => s.lifetimeBanked >= n })),
    ...RUN_STEPS.map(n => ({ id: `run.${n}`, earned: (s: MilestoneStats) => s.bestStreak >= n })),
];

export function earnedFor(stats: MilestoneStats): string[] {
    return CATALOG.filter(m => m.earned(stats)).map(m => m.id);
}

export interface Grade {
    index: number;
    name: string;
    band: number;
}

// KYU COUNTS DOWN, THEN DAN COUNTS UP, hinged at 1st dan as a real event. Thresholds widen as you
// climb, so 10th kyu lands on a player's first evening — the game should acknowledge someone
// before they leave it — and 1st dan stays uncommon. Fifteen grades: judo's upper dan are largely
// honorary, so this stops at 5th.
const NAMES = [
    '10th kyu', '9th kyu', '8th kyu', '7th kyu', '6th kyu',
    '5th kyu', '4th kyu', '3rd kyu', '2nd kyu', '1st kyu',
    '1st dan', '2nd dan', '3rd dan', '4th dan', '5th dan',
];
const THRESHOLDS = [1, 2, 3, 4, 6, 8, 10, 13, 16, 19, 23, 27, 31, 35, 40];

export function gradeFor(count: number): Grade {
    let index = 0;
    for (let i = 0; i < THRESHOLDS.length; i++) {
        if (count >= THRESHOLDS[i]) index = i + 1;
    }
    // FIVE BANDS, NOT FIFTEEN. Fifteen visually distinct birds is neither achievable nor legible
    // across an arena; five is. The exact grade is printed where there is room for it — the slip
    // in the vestibule and the teahouse banner — and the bird carries only the band.
    const band = index === 0 ? 0 : Math.min(5, Math.ceil(index / 3));
    return { index, name: index === 0 ? 'unranked' : NAMES[index - 1], band };
}
