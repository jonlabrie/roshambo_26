import { describe, it, expect, vi } from 'vitest';
import { readCrowdConfig, guardCrowd } from './crowdConfig';
import { DEFAULT_MIX } from './engine/SyntheticCrowd';

const opts = (testMode = false) => ({ testMode, log: vi.fn(), randomSeed: () => 4242 });

describe('readCrowdConfig', () => {
    it('is off when CROWD_SIZE is unset or 0, silently', () => {
        const o = opts();
        expect(readCrowdConfig({}, o)).toBeNull();
        expect(readCrowdConfig({ CROWD_SIZE: '0' }, o)).toBeNull();
        expect(o.log).not.toHaveBeenCalled();
    });

    it('reads size, default mix, and a random seed that it logs so the run is reproducible', () => {
        const o = opts();
        expect(readCrowdConfig({ CROWD_SIZE: '30' }, o)).toEqual({ size: 30, mix: DEFAULT_MIX, seed: 4242 });
        expect(o.log).toHaveBeenCalledWith('[CROWD] CROWD_SEED unset; using 4242 (set CROWD_SEED=4242 to reproduce this run)');
    });

    it('honours CROWD_MIX and CROWD_SEED', () => {
        const o = opts();
        expect(readCrowdConfig({ CROWD_SIZE: '5', CROWD_MIX: 'counter:1', CROWD_SEED: '7' }, o))
            .toEqual({ size: 5, mix: { counter: 1 }, seed: 7 });
        expect(o.log).not.toHaveBeenCalled();
    });

    it('TEST_MODE disables the crowd with a warning instead of lying on the reveal card', () => {
        const o = opts(true);
        expect(readCrowdConfig({ CROWD_SIZE: '30' }, o)).toBeNull();
        expect(o.log).toHaveBeenCalledWith(
            '[CROWD] CROWD_SIZE=30 ignored: TEST_MODE cycles the World Throw, and a crowd whose plurality disagrees with it would lie on the reveal card');
    });

    it('refuses malformed values at boot', () => {
        expect(() => readCrowdConfig({ CROWD_SIZE: '-3' }, opts())).toThrow('CROWD_SIZE="-3" must be a non-negative integer');
        expect(() => readCrowdConfig({ CROWD_SIZE: '2.5' }, opts())).toThrow('CROWD_SIZE="2.5" must be a non-negative integer');
        expect(() => readCrowdConfig({ CROWD_SIZE: '5', CROWD_MIX: 'ninja:1' }, opts())).toThrow('CROWD_MIX: unknown archetype "ninja"');
        expect(() => readCrowdConfig({ CROWD_SIZE: '5', CROWD_SEED: 'abc' }, opts())).toThrow('CROWD_SEED="abc" must be a non-negative integer');
    });

    it('still refuses a malformed CROWD_MIX under TEST_MODE, so a typo cannot lie in wait', () => {
        expect(() => readCrowdConfig({ CROWD_SIZE: '5', CROWD_MIX: 'ninja:1' }, opts(true)))
            .toThrow('CROWD_MIX: unknown archetype "ninja"');
    });

    it('still refuses a malformed CROWD_SEED under TEST_MODE', () => {
        expect(() => readCrowdConfig({ CROWD_SIZE: '5', CROWD_SEED: 'abc' }, opts(true)))
            .toThrow('CROWD_SEED="abc" must be a non-negative integer');
    });

    it('does not draw or announce a seed for a crowd TEST_MODE has disabled', () => {
        const o = { testMode: true, log: vi.fn(), randomSeed: vi.fn(() => 4242) };
        expect(readCrowdConfig({ CROWD_SIZE: '30' }, o)).toBeNull();
        expect(o.randomSeed).not.toHaveBeenCalled();
        expect(o.log).toHaveBeenCalledTimes(1);
    });
});

describe('guardCrowd', () => {
    it('passes calls through when the crowd behaves', () => {
        const inner = { throws: vi.fn(() => ({ R: 1, P: 2, S: 3 })), observe: vi.fn() };
        const log = vi.fn();
        const g = guardCrowd(inner, log);
        expect(g.throws(7)).toEqual({ R: 1, P: 2, S: 3 });
        g.observe('P');
        expect(inner.throws).toHaveBeenCalledWith(7);
        expect(inner.observe).toHaveBeenCalledWith('P');
        expect(log).not.toHaveBeenCalled();
    });

    it('a throwing crowd yields an empty tally and one log line, and observe() failures are swallowed', () => {
        const inner = {
            throws: vi.fn(() => { throw new Error('boom'); }),
            observe: vi.fn(() => { throw new Error('bang'); }),
        };
        const log = vi.fn();
        const g = guardCrowd(inner, log);
        expect(g.throws(3)).toEqual({ R: 0, P: 0, S: 0 });
        expect(() => g.observe('R')).not.toThrow();
        expect(log).toHaveBeenCalledWith('[CROWD] throws() failed on round 3: boom — empty crowd this round');
        expect(log).toHaveBeenCalledWith('[CROWD] observe() failed: bang');
    });
});
