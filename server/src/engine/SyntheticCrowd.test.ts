import { describe, it, expect } from 'vitest';
import { parseMix, formatMix, allocate, createCrowd, DEFAULT_MIX, DEFAULT_STRENGTH } from './SyntheticCrowd';
import { mulberry32 } from './Prng';

describe('parseMix', () => {
    it('parses id:weight pairs, tolerating whitespace', () => {
        expect(parseMix('wsls:35, counter:20 ,conform:15')).toEqual({ wsls: 35, counter: 20, conform: 15 });
    });
    it('refuses an unknown archetype with a message naming the known ones', () => {
        expect(() => parseMix('wsls:1,ninja:2')).toThrow(
            'CROWD_MIX: unknown archetype "ninja" (known: random, wsls, counter, conform, rocky, second)');
    });
    it('refuses a non-positive or non-numeric weight', () => {
        expect(() => parseMix('wsls:0')).toThrow('CROWD_MIX: weight for "wsls" must be a positive number, got "0"');
        expect(() => parseMix('wsls:lots')).toThrow('CROWD_MIX: weight for "wsls" must be a positive number, got "lots"');
    });
    it('refuses an empty spec and a repeated id', () => {
        expect(() => parseMix('')).toThrow('CROWD_MIX: empty');
        expect(() => parseMix('wsls:1,wsls:2')).toThrow('CROWD_MIX: "wsls" listed twice');
    });
    it('round-trips through formatMix', () => {
        expect(parseMix(formatMix(DEFAULT_MIX))).toEqual(DEFAULT_MIX);
    });
});

describe('allocate', () => {
    it('splits a size across the mix exactly, largest remainder, in POLICY_IDS order', () => {
        // 10 bots over random:20 wsls:30 counter:10 conform:30 rocky:10 (POLICY_IDS order)
        // -> quotas 2,3,1,3,1; floors sum to 10 exactly, so no remainder is handed out
        expect(allocate(10, DEFAULT_MIX)).toEqual([
            'random', 'random', 'wsls', 'wsls', 'wsls', 'counter', 'conform', 'conform', 'conform', 'rocky',
        ]);
    });
    it('hands remainders out by largest fraction, ties to the earlier POLICY_IDS entry', () => {
        // 10 bots over wsls:35 counter:20 conform:15 rocky:10 random:20 -> quotas 2,3.5,2,1.5,1
        // floors 2,3,2,1,1 = 9; one remainder -> fractions tie (wsls .5, conform .5) -> wsls, the
        // earlier id, takes it. (This was the pre-2026-09-04 default mix; kept for the tie-break.)
        expect(allocate(10, { wsls: 35, counter: 20, conform: 15, rocky: 10, random: 20 })).toEqual([
            'random', 'random', 'wsls', 'wsls', 'wsls', 'wsls', 'counter', 'counter', 'conform', 'rocky',
        ]);
    });
    it('a single archetype gets everything; zero size gets nothing', () => {
        expect(allocate(3, { counter: 1 })).toEqual(['counter', 'counter', 'counter']);
        expect(allocate(0, DEFAULT_MIX)).toEqual([]);
    });
});

describe('createCrowd', () => {
    it('tallies exactly `size` throws every round', () => {
        const crowd = createCrowd({ size: 30, rng: mulberry32(1) });
        const c = crowd.throws(0);
        expect(c.R + c.P + c.S).toBe(30);
        expect(crowd.size).toBe(30);
    });

    it('is deterministic: same seed and same observed world throws give the same tallies', () => {
        const a = createCrowd({ size: 25, rng: mulberry32(11) });
        const b = createCrowd({ size: 25, rng: mulberry32(11) });
        const worlds = ['R', 'P', 'P', 'S', 'R'] as const;
        for (const w of worlds) {
            expect(a.throws(0)).toEqual(b.throws(0));
            a.observe(w); b.observe(w);
        }
        expect(a.throws(0)).toEqual(b.throws(0));
    });

    it('bots learn from observe(): an all-counter crowd at strength 1 throws what beats the last world', () => {
        const crowd = createCrowd({ size: 5, mix: { counter: 1 }, strength: 1, rng: mulberry32(2) });
        crowd.throws(0);
        crowd.observe('R');
        expect(crowd.throws(1)).toEqual({ R: 0, P: 5, S: 0 });
        crowd.observe('P');
        expect(crowd.throws(2)).toEqual({ R: 0, P: 0, S: 5 });
    });

    it('an all-conform crowd at strength 1 repeats the last world', () => {
        const crowd = createCrowd({ size: 4, mix: { conform: 1 }, strength: 1, rng: mulberry32(2) });
        crowd.throws(0);
        crowd.observe('S');
        expect(crowd.throws(1)).toEqual({ R: 0, P: 0, S: 4 });
    });

    it('observe() without a preceding throws() still teaches the bots the world throw', () => {
        const crowd = createCrowd({ size: 3, mix: { conform: 1 }, strength: 1, rng: mulberry32(2) });
        crowd.observe('P');
        expect(crowd.throws(0)).toEqual({ R: 0, P: 3, S: 0 });
    });

    it('expected() sums the bots\' current distributions', () => {
        const crowd = createCrowd({ size: 4, mix: { counter: 1 }, strength: 1, rng: mulberry32(2) });
        crowd.observe('R');
        expect(crowd.expected()).toEqual({ R: 0, P: 4, S: 0 });
    });

    it('defaults to DEFAULT_MIX and DEFAULT_STRENGTH', () => {
        expect(DEFAULT_STRENGTH).toBe(0.7);
        expect(DEFAULT_MIX).toEqual({ wsls: 30, counter: 10, conform: 30, rocky: 10, random: 20 });
    });
});
