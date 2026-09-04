// The synthetic crowd's archetypes (spec §2). A policy is a DISTRIBUTION over R/P/S given a
// small memory; sampling is generic. Defining them by distribution rather than by a sampled
// throw is what makes each archetype testable exactly, and what lets the simulator's oracle sum
// them to predict the plurality.
//
// Basis: Wang, Xu & Zhou, "Social cycling and conditional responses in the Rock-Paper-Scissors
// game", Sci. Rep. 4:5830 (2014) — win-stay / lose-shift-CLOCKWISE (R->S->P->R) and the
// population-level cycling it produces. `counter`/`conform` are the two readings of the HUD's
// last-five tape; `rocky` is the folk novice. All of this is a HYPOTHESIS about a Roblox crowd,
// to be recalibrated from real Round.distribution rows once there are any (spec §8).
import { Throw, RoundResult, calculateResult } from './GameRules';
import { Rng } from './Prng';

export type PolicyId = 'random' | 'wsls' | 'counter' | 'conform' | 'rocky' | 'second';
export const POLICY_IDS: PolicyId[] = ['random', 'wsls', 'counter', 'conform', 'rocky', 'second'];

export type Dist = Record<Throw, number>;

export interface Memory {
    lastThrow?: Throw;
    lastResult?: RoundResult;
    lastWorld?: Throw;
    repeatRun: number; // consecutive rounds the bot has thrown lastThrow
}

export const freshMemory = (): Memory => ({ repeatRun: 0 });

const THROWS: Throw[] = ['R', 'P', 'S'];
export const WHAT_BEATS: Record<Throw, Throw> = { R: 'P', P: 'S', S: 'R' };
export const CLOCKWISE: Record<Throw, Throw> = { R: 'S', S: 'P', P: 'R' };
// Frozen: `random` and the zero-total fallback both return this object BY REFERENCE, so an
// accidental write through one caller's Dist would silently re-weight every other one. All
// write sites build fresh literals.
export const UNIFORM: Dist = Object.freeze({ R: 1 / 3, P: 1 / 3, S: 1 / 3 });

export function pointMass(t: Throw): Dist {
    return { R: t === 'R' ? 1 : 0, P: t === 'P' ? 1 : 0, S: t === 'S' ? 1 : 0 };
}

// strength * focused + (1 - strength) * uniform. `strength` is the readability dial WITHIN an
// archetype; the mix (SyntheticCrowd) is the dial ACROSS them.
export function blend(focused: Dist, strength: number): Dist {
    const s = Math.min(1, Math.max(0, strength));
    return {
        R: s * focused.R + (1 - s) / 3,
        P: s * focused.P + (1 - s) / 3,
        S: s * focused.S + (1 - s) / 3,
    };
}

function normalised(d: Dist): Dist {
    const total = d.R + d.P + d.S;
    return total === 0 ? UNIFORM : { R: d.R / total, P: d.P / total, S: d.S / total };
}

export function policyDistribution(id: PolicyId, m: Memory, strength: number): Dist {
    switch (id) {
        case 'random':
            return UNIFORM;
        case 'wsls': {
            if (!m.lastThrow || !m.lastResult) return UNIFORM;
            if (m.lastResult === 'WIN') return blend(pointMass(m.lastThrow), strength);
            const shifted = pointMass(CLOCKWISE[m.lastThrow]);
            return blend(shifted, m.lastResult === 'LOSS' ? strength : strength / 2);
        }
        case 'counter':
            return m.lastWorld ? blend(pointMass(WHAT_BEATS[m.lastWorld]), strength) : UNIFORM;
        case 'conform':
            return m.lastWorld ? blend(pointMass(m.lastWorld), strength) : UNIFORM;
        case 'second':
            return m.lastWorld ? blend(pointMass(WHAT_BEATS[WHAT_BEATS[m.lastWorld]]), strength) : UNIFORM;
        case 'rocky': {
            if (!m.lastThrow) return blend({ R: 0.5, P: 0.25, S: 0.25 }, strength);
            const lean: Dist = { R: 0.4, P: 0.3, S: 0.3 };
            if (m.repeatRun >= 2) lean[m.lastThrow] = 0; // never a third repeat
            return blend(normalised(lean), strength);
        }
    }
}

export function sample(d: Dist, rng: Rng): Throw {
    const x = rng();
    let acc = 0;
    for (const t of THROWS) {
        acc += d[t];
        if (x < acc) return t;
    }
    return 'S'; // rounding guard: x landed within epsilon of 1
}

// Pure: the memory after a round in which the bot threw `thrown` against `world`.
export function advance(m: Memory, thrown: Throw, world: Throw): Memory {
    return {
        lastThrow: thrown,
        lastResult: calculateResult(thrown, world),
        lastWorld: world,
        repeatRun: thrown === m.lastThrow ? m.repeatRun + 1 : 1,
    };
}
