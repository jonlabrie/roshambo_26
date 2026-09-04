import { describe, it, expect } from 'vitest';
import {
    POLICY_IDS, UNIFORM, WHAT_BEATS, CLOCKWISE, freshMemory,
    policyDistribution, sample, advance, Memory,
} from './CrowdPolicies';
import { mulberry32 } from './Prng';

const close = (d: Record<string, number>, want: Record<string, number>) => {
    for (const k of ['R', 'P', 'S']) expect(d[k]).toBeCloseTo(want[k], 6);
};

describe('vocabulary', () => {
    it('lists the six archetypes in a fixed order', () => {
        expect(POLICY_IDS).toEqual(['random', 'wsls', 'counter', 'conform', 'rocky', 'second']);
    });
    it('WHAT_BEATS and CLOCKWISE are the two rotations the archetypes use', () => {
        expect(WHAT_BEATS).toEqual({ R: 'P', P: 'S', S: 'R' });
        expect(CLOCKWISE).toEqual({ R: 'S', S: 'P', P: 'R' });
    });
});

describe('policyDistribution', () => {
    const p = 0.7;
    const noMemory = freshMemory();
    const afterWorldR: Memory = { lastThrow: 'S', lastResult: 'LOSS', lastWorld: 'R', repeatRun: 1 };

    it('every archetype is uniform with no memory, except rocky which leans rock', () => {
        for (const id of ['random', 'wsls', 'counter', 'conform', 'second'] as const) {
            close(policyDistribution(id, noMemory, p), UNIFORM);
        }
        // rocky: 0.7 * {0.5, 0.25, 0.25} + 0.3 * uniform
        close(policyDistribution('rocky', noMemory, p), { R: 0.45, P: 0.275, S: 0.275 });
    });

    it('random ignores memory', () => {
        close(policyDistribution('random', afterWorldR, p), UNIFORM);
    });

    it('counter throws what beats the last World Throw', () => {
        // world R -> P beats it: 0.7 + 0.3/3 = 0.8 on P, 0.1 each elsewhere
        close(policyDistribution('counter', afterWorldR, p), { R: 0.1, P: 0.8, S: 0.1 });
    });

    it('conform throws the last World Throw', () => {
        close(policyDistribution('conform', afterWorldR, p), { R: 0.8, P: 0.1, S: 0.1 });
    });

    it('second throws what beats the counter of the last World Throw', () => {
        // world R -> counter throws P -> S beats P
        close(policyDistribution('second', afterWorldR, p), { R: 0.1, P: 0.1, S: 0.8 });
    });

    it('wsls: win-stay at full strength', () => {
        const m: Memory = { lastThrow: 'P', lastResult: 'WIN', lastWorld: 'R', repeatRun: 1 };
        close(policyDistribution('wsls', m, p), { R: 0.1, P: 0.8, S: 0.1 });
    });

    it('wsls: lose-shift clockwise (R->S->P->R) at full strength', () => {
        const m: Memory = { lastThrow: 'R', lastResult: 'LOSS', lastWorld: 'P', repeatRun: 1 };
        close(policyDistribution('wsls', m, p), { R: 0.1, P: 0.1, S: 0.8 });
    });

    it('wsls: after SAFE, shifts clockwise at half strength', () => {
        const m: Memory = { lastThrow: 'R', lastResult: 'SAFE', lastWorld: 'R', repeatRun: 1 };
        // strength 0.35 on S, 0.65 uniform -> S: 0.35 + 0.65/3
        close(policyDistribution('wsls', m, p), { R: 0.65 / 3, P: 0.65 / 3, S: 0.35 + 0.65 / 3 });
    });

    it('rocky leans rock after the first throw and never throws a third repeat', () => {
        const lean: Memory = { lastThrow: 'P', lastResult: 'LOSS', lastWorld: 'S', repeatRun: 1 };
        close(policyDistribution('rocky', lean, p), { R: 0.7 * 0.4 + 0.1, P: 0.7 * 0.3 + 0.1, S: 0.7 * 0.3 + 0.1 });
        const twoRocks: Memory = { lastThrow: 'R', lastResult: 'SAFE', lastWorld: 'R', repeatRun: 2 };
        // R zeroed, {P: .3, S: .3} renormalised to {P: .5, S: .5}, then blended
        close(policyDistribution('rocky', twoRocks, p), { R: 0.1, P: 0.45, S: 0.45 });
    });

    it('strength 1 is a point mass; strength 0 is uniform', () => {
        close(policyDistribution('counter', afterWorldR, 1), { R: 0, P: 1, S: 0 });
        close(policyDistribution('counter', afterWorldR, 0), UNIFORM);
    });
});

describe('sample', () => {
    it('maps the unit interval onto R, P, S in that order', () => {
        const d = { R: 0.2, P: 0.5, S: 0.3 };
        expect(sample(d, () => 0.1)).toBe('R');
        expect(sample(d, () => 0.2)).toBe('P');
        expect(sample(d, () => 0.69)).toBe('P');
        expect(sample(d, () => 0.7)).toBe('S');
        expect(sample(d, () => 0.999999)).toBe('S');
    });
    it('is deterministic under a seeded rng', () => {
        const a = mulberry32(3), b = mulberry32(3);
        for (let i = 0; i < 50; i++) expect(sample(UNIFORM, a)).toBe(sample(UNIFORM, b));
    });
});

describe('advance', () => {
    it('records the throw, the result against the world, the world, and the repeat run', () => {
        const m1 = advance(freshMemory(), 'R', 'S');
        expect(m1).toEqual({ lastThrow: 'R', lastResult: 'WIN', lastWorld: 'S', repeatRun: 1 });
        const m2 = advance(m1, 'R', 'R');
        expect(m2).toEqual({ lastThrow: 'R', lastResult: 'SAFE', lastWorld: 'R', repeatRun: 2 });
        const m3 = advance(m2, 'P', 'S');
        expect(m3).toEqual({ lastThrow: 'P', lastResult: 'LOSS', lastWorld: 'S', repeatRun: 1 });
    });
    it('does not mutate its input', () => {
        const m = freshMemory();
        advance(m, 'R', 'S');
        expect(m).toEqual({ repeatRun: 0 });
    });
});
