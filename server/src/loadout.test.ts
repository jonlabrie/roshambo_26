import { describe, it, expect } from 'vitest';
import {
    validateLoadout,
    validateSizeClass,
    validatePadPreferences,
    validateWallBays,
    MAX_CLASSES,
    MAX_BAYS_PER_SIDE,
} from './loadout';

describe('validateLoadout', () => {
    it('accepts a well-formed loadout', () => {
        expect(validateLoadout({ baseStyle: 'teahouse-1story', colorScheme: 'scheme.ink' }).ok).toBe(true);
    });
    it('rejects non-objects', () => {
        expect(validateLoadout('nope').ok).toBe(false);
        expect(validateLoadout(null).ok).toBe(false);
        expect(validateLoadout([1, 2]).ok).toBe(false);
    });
    it('rejects a missing/empty baseStyle', () => {
        expect(validateLoadout({ colorScheme: 'x' }).ok).toBe(false);
        expect(validateLoadout({ baseStyle: '' }).ok).toBe(false);
    });
    it('rejects unknown top-level keys', () => {
        expect(validateLoadout({ baseStyle: 't', bogus: 1 }).ok).toBe(false);
    });
    it('rejects oversize loadouts', () => {
        expect(validateLoadout({ baseStyle: 't', wallArt: 'x'.repeat(5000) }).ok).toBe(false);
    });
});

describe('validateSizeClass', () => {
    it('accepts a short non-empty class within the cap', () => {
        expect(validateSizeClass('M', []).ok).toBe(true);
        expect(validateSizeClass('M', ['M', 'L']).ok).toBe(true); // existing key, no new-key cap
    });
    it('rejects empty/oversize class ids', () => {
        expect(validateSizeClass('', []).ok).toBe(false);
        expect(validateSizeClass('x'.repeat(17), []).ok).toBe(false);
        expect(validateSizeClass(42, []).ok).toBe(false);
    });
    it('rejects a new class beyond the cap', () => {
        const full = Array.from({ length: MAX_CLASSES }, (_, i) => `c${i}`);
        expect(validateSizeClass('new', full).ok).toBe(false); // 9th distinct
        expect(validateSizeClass('c0', full).ok).toBe(true);   // overwriting an existing one is fine
    });
});

describe('validatePadPreferences', () => {
    it('accepts an array of short strings, and an empty array', () => {
        expect(validatePadPreferences([]).ok).toBe(true);
        expect(validatePadPreferences(['T06', 'T02']).ok).toBe(true);
    });
    it('rejects a non-array', () => {
        expect(validatePadPreferences('T06').ok).toBe(false);
        expect(validatePadPreferences(null).ok).toBe(false);
        expect(validatePadPreferences({ 0: 'T06' }).ok).toBe(false);
    });
    it('rejects more than 32 entries', () => {
        expect(validatePadPreferences(Array.from({ length: 33 }, (_, i) => `T${i}`)).ok).toBe(false);
    });
    it('rejects a non-string entry', () => {
        expect(validatePadPreferences(['T06', 42]).ok).toBe(false);
    });
    it('rejects an entry longer than 32 chars', () => {
        expect(validatePadPreferences(['x'.repeat(33)]).ok).toBe(false);
    });
});

describe('validateWallBays', () => {
    it('accepts an empty map and valid dense side lists', () => {
        expect(validateWallBays({}).ok).toBe(true);
        expect(validateWallBays({ back: ['solid', 'door', 'solid'], front: ['shoji'] }).ok).toBe(true);
    });
    it('rejects non-objects', () => {
        expect(validateWallBays(null).ok).toBe(false);
        expect(validateWallBays(['solid']).ok).toBe(false);
        expect(validateWallBays('back').ok).toBe(false);
    });
    it('rejects an unknown side key', () => {
        expect(validateWallBays({ roof: ['solid'] }).ok).toBe(false);
    });
    it('rejects a non-array side value', () => {
        expect(validateWallBays({ back: 'door' }).ok).toBe(false);
    });
    it('rejects an unknown bay state', () => {
        expect(validateWallBays({ back: ['window'] }).ok).toBe(false);
    });
    it('rejects an over-length side list', () => {
        expect(validateWallBays({ back: Array(MAX_BAYS_PER_SIDE + 1).fill('solid') }).ok).toBe(false);
    });
    it('accepts a side list of exactly MAX_BAYS_PER_SIDE', () => {
        expect(validateWallBays({ back: Array(MAX_BAYS_PER_SIDE).fill('solid') }).ok).toBe(true);
    });
});

describe('validateLoadout wallBays', () => {
    it('accepts a loadout carrying a valid wallBays', () => {
        expect(validateLoadout({ baseStyle: 't', wallBays: { back: ['solid', 'door', 'solid'] } }).ok).toBe(true);
    });
    it('rejects a loadout with an invalid wallBays', () => {
        expect(validateLoadout({ baseStyle: 't', wallBays: { back: ['trapdoor'] } }).ok).toBe(false);
    });
});
