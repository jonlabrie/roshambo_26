import { describe, it, expect } from 'vitest';
import { mulberry32, randomSeed } from './Prng';

describe('mulberry32', () => {
    it('is a known-answer sequence for a fixed seed', () => {
        const r = mulberry32(1);
        expect([r(), r(), r()].map(x => x.toFixed(6))).toEqual(['0.627074', '0.002736', '0.527447']);
        const s = mulberry32(42);
        expect([s(), s(), s()].map(x => x.toFixed(6))).toEqual(['0.601104', '0.448291', '0.852466']);
    });

    it('stays in [0, 1) over many draws', () => {
        const r = mulberry32(7);
        for (let i = 0; i < 10_000; i++) {
            const x = r();
            expect(x).toBeGreaterThanOrEqual(0);
            expect(x).toBeLessThan(1);
        }
    });

    it('two generators with the same seed agree; different seeds diverge', () => {
        const a = mulberry32(99), b = mulberry32(99), c = mulberry32(100);
        expect(a()).toBe(b());
        expect(a()).not.toBe(c());
    });
});

describe('randomSeed', () => {
    it('returns a 32-bit unsigned integer', () => {
        const s = randomSeed();
        expect(Number.isInteger(s)).toBe(true);
        expect(s).toBeGreaterThanOrEqual(0);
        expect(s).toBeLessThan(2 ** 32);
    });
});
