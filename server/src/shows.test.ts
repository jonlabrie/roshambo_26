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
