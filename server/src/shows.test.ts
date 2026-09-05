import { describe, it, expect } from 'vitest';
import fixture from '../../shared-fixtures/shows.json';
import shellFixture from '../../shared-fixtures/firework-shells.json';
import { validateShow, tallyShells, shellMortar, SHOW_LIMITS, DECK_STAGE, Cue } from './shows';

describe('the fixture is the contract', () => {
    it('limits come from the fixture', () => {
        expect(SHOW_LIMITS).toEqual(fixture.limits);
    });
    it('DECK_STAGE is the fixture deck stage', () => {
        expect(DECK_STAGE).toEqual(fixture.stages.deck);
    });
    it('every case shell is a catalogued shell or deliberately unknown', () => {
        for (const c of fixture.cases) {
            for (const cue of c.cues) {
                if (c.expect !== 'BAD_SHELL') expect(shellFixture.shells).toContain(cue.shellId);
            }
        }
    });
});

describe('validateShow — every fixture case', () => {
    for (const c of fixture.cases) {
        it(c.name, () => {
            const stage = (fixture.stages as Record<string, Record<string, string>>)[c.stage];
            const r = validateShow(c.cues, stage);
            if (c.expect === 'ok') {
                expect(r).toEqual({ ok: true });
            } else {
                expect(r.ok).toBe(false);
                if (!r.ok) {
                    expect(r.error).toBe(c.expect);
                    if ('cue' in c) expect(r.cue).toBe(c.cue);
                }
            }
        });
    }
    it('TOO_MANY_CUES at maxCues + 1', () => {
        const cues: Cue[] = Array.from({ length: SHOW_LIMITS.maxCues + 1 }, (_, i) => ({ t_ms: i * 10, slot: 'hand', shellId: 'firecracker' }));
        expect(validateShow(cues, DECK_STAGE)).toEqual({ ok: false, error: 'TOO_MANY_CUES' });
        expect(validateShow(cues.slice(0, SHOW_LIMITS.maxCues), DECK_STAGE)).toEqual({ ok: true });
    });
    it('TOO_LONG is strict: a show ending exactly at the limit is legal', () => {
        const at = (t_ms: number) => validateShow([{ t_ms: 0, slot: 'hand', shellId: 'firecracker' }, { t_ms, slot: 'hand', shellId: 'firecracker' }], DECK_STAGE);
        expect(at(SHOW_LIMITS.maxDurationS * 1000)).toEqual({ ok: true });
        expect(at(SHOW_LIMITS.maxDurationS * 1000 + 1)).toEqual({ ok: false, error: 'TOO_LONG' });
    });
    it('a non-finite t_ms is a BAD_CUE, not a time error', () => {
        // JSON cannot carry NaN or Infinity, so the fixture cannot express these -- and the Luau
        // twin asserts the same two rows in ShowPlan.spec.luau.
        for (const bad of [NaN, Infinity, -Infinity]) {
            expect(validateShow([{ t_ms: bad, slot: 'hand', shellId: 'firecracker' }], DECK_STAGE))
                .toEqual({ ok: false, error: 'BAD_CUE', cue: 0 });
        }
    });
    it('rejects non-array input as EMPTY', () => {
        expect(validateShow(undefined, DECK_STAGE)).toEqual({ ok: false, error: 'EMPTY' });
        expect(validateShow('nope', DECK_STAGE)).toEqual({ ok: false, error: 'EMPTY' });
    });
});

describe('helpers', () => {
    it('shellMortar reads REQUIREMENTS', () => {
        expect(shellMortar('peony')).toBe('mortar:S');
        expect(shellMortar('kamuro')).toBe('mortar:L');
        expect(shellMortar('firecracker')).toBeNull();
        expect(shellMortar('ishibana')).toBeNull();
        expect(shellMortar('nope')).toBeNull();
    });
    it('tallyShells counts per id', () => {
        expect(tallyShells([
            { t_ms: 0, slot: 'hand', shellId: 'firecracker' },
            { t_ms: 0, slot: 'mortar:S', shellId: 'peony' },
            { t_ms: 500, slot: 'hand', shellId: 'firecracker' },
        ])).toEqual({ firecracker: 2, peony: 1 });
    });
});
