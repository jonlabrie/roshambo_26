// Seeded PRNG for the synthetic crowd (spec §2: "mulberry32 or equivalent, ~10 lines — no
// package"). Same seed + same call sequence → same numbers, which is what makes a crowd run
// reproducible and the zero-human demo deterministic. Not cryptographic; not meant to be.
export type Rng = () => number;

export function mulberry32(seed: number): Rng {
    let a = seed >>> 0;
    return () => {
        a = (a + 0x6D2B79F5) | 0;
        let t = Math.imul(a ^ (a >>> 15), 1 | a);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

// For CROWD_SEED unset: a seed that is logged so the run can still be reproduced.
export function randomSeed(): number {
    return (Math.random() * 0x100000000) >>> 0;
}
