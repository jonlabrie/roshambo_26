import { describe, it, expect } from 'vitest';
import {
    validateLoadout,
    validateSizeClass,
    validatePadPreferences,
    validateWallBays,
    validatePlacement,
    validateDecorations,
    validateAccess,
    validateShojiOpen,
    validateMortarPlacements,
    MAX_CLASSES,
    MAX_BAYS_PER_SIDE,
    MAX_PLACEMENT_OFFSET,
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

describe('validatePlacement', () => {
    it('accepts a valid placement', () => {
        expect(validatePlacement({ offset: [3, -4.5], facing: 'E' })).toEqual({ ok: true });
    });
    it('rejects non-objects and arrays', () => {
        expect(validatePlacement(null).ok).toBe(false);
        expect(validatePlacement([1, 2]).ok).toBe(false);
        expect(validatePlacement('N').ok).toBe(false);
    });
    it('rejects wrong offset arity', () => {
        expect(validatePlacement({ offset: [1], facing: 'N' })).toEqual({ ok: false, error: 'BAD_PLACEMENT' });
        expect(validatePlacement({ offset: [1, 2, 3], facing: 'N' })).toEqual({ ok: false, error: 'BAD_PLACEMENT' });
    });
    it('rejects non-finite and out-of-range offsets', () => {
        expect(validatePlacement({ offset: [NaN, 0], facing: 'N' }).ok).toBe(false);
        expect(validatePlacement({ offset: [Infinity, 0], facing: 'N' }).ok).toBe(false);
        expect(validatePlacement({ offset: [33, 0], facing: 'N' }).ok).toBe(false);
        expect(validatePlacement({ offset: [0, -33], facing: 'N' }).ok).toBe(false);
    });
    it('accepts offsets at exactly the ±MAX_PLACEMENT_OFFSET boundary', () => {
        expect(validatePlacement({ offset: [32, -32], facing: 'N' })).toEqual({ ok: true });
    });
    it('rejects bad facings and unknown keys', () => {
        expect(validatePlacement({ offset: [0, 0], facing: 'NE' }).ok).toBe(false);
        expect(validatePlacement({ offset: [0, 0], facing: 'N', extra: 1 }).ok).toBe(false);
    });
    it('validateLoadout accepts placement and still rejects unknown keys', () => {
        expect(validateLoadout({ baseStyle: 'teahouse-1story', placement: { offset: [2, 2], facing: 'S' } })).toEqual({ ok: true });
        expect(validateLoadout({ baseStyle: 'teahouse-1story', placement: { offset: [2], facing: 'S' } }).ok).toBe(false);
        expect(validateLoadout({ baseStyle: 'teahouse-1story', teleporter: true }).ok).toBe(false);
    });
});

describe('validateDecorations', () => {
    const ok = (extra: unknown[] = []) => [
        { id: 1, propId: 'bonsai', offset: [0, 0], facing: 'N' },
        { id: 2, propId: 'bench', offset: [3, -4], facing: 'E' },
        ...extra,
    ];
    it('accepts a well-formed list', () => {
        expect(validateDecorations(ok())).toEqual({ ok: true });
    });
    it('accepts an empty list', () => {
        expect(validateDecorations([])).toEqual({ ok: true });
    });
    it('rejects a non-array', () => {
        expect(validateDecorations({})).toEqual({ ok: false, error: 'BAD_DECORATION' });
    });
    it('rejects an unknown propId', () => {
        expect(validateDecorations([{ id: 1, propId: 'dragon', offset: [0, 0], facing: 'N' }]))
            .toEqual({ ok: false, error: 'BAD_DECORATION' });
    });
    it('rejects a bad facing', () => {
        expect(validateDecorations([{ id: 1, propId: 'bonsai', offset: [0, 0], facing: 'X' }]))
            .toEqual({ ok: false, error: 'BAD_DECORATION' });
    });
    it('rejects a non-finite / out-of-range offset', () => {
        expect(validateDecorations([{ id: 1, propId: 'bonsai', offset: [999, 0], facing: 'N' }]))
            .toEqual({ ok: false, error: 'BAD_DECORATION' });
        expect(validateDecorations([{ id: 1, propId: 'bonsai', offset: [0], facing: 'N' }]))
            .toEqual({ ok: false, error: 'BAD_DECORATION' });
    });
    it('rejects a non-integer / non-positive id', () => {
        expect(validateDecorations([{ id: 0, propId: 'bonsai', offset: [0, 0], facing: 'N' }]))
            .toEqual({ ok: false, error: 'BAD_DECORATION' });
        expect(validateDecorations([{ id: 1.5, propId: 'bonsai', offset: [0, 0], facing: 'N' }]))
            .toEqual({ ok: false, error: 'BAD_DECORATION' });
    });
    it('rejects duplicate ids', () => {
        expect(validateDecorations([
            { id: 1, propId: 'bonsai', offset: [0, 0], facing: 'N' },
            { id: 1, propId: 'bench', offset: [0, 0], facing: 'N' },
        ])).toEqual({ ok: false, error: 'BAD_DECORATION' });
    });
    it('rejects an extra key on an entry', () => {
        expect(validateDecorations([{ id: 1, propId: 'bonsai', offset: [0, 0], facing: 'N', evil: 1 }]))
            .toEqual({ ok: false, error: 'BAD_DECORATION' });
    });
    it('rejects over the cap', () => {
        const many = Array.from({ length: 25 }, (_, i) => ({ id: i + 1, propId: 'bonsai', offset: [0, 0], facing: 'N' }));
        expect(validateDecorations(many)).toEqual({ ok: false, error: 'BAD_DECORATION' });
    });
});

describe('validateAccess', () => {
    it('accepts a well-formed public payload', () => {
        expect(validateAccess({ mode: 'public', invited: [] })).toEqual({ ok: true });
    });
    it('accepts a private payload with invited ids', () => {
        expect(validateAccess({ mode: 'private', invited: [1, 2, 3] })).toEqual({ ok: true });
    });
    it('accepts friends mode', () => {
        expect(validateAccess({ mode: 'friends', invited: [] })).toEqual({ ok: true });
    });
    it('rejects a non-object', () => {
        expect(validateAccess(null)).toEqual({ ok: false, error: 'BAD_ACCESS' });
        expect(validateAccess([])).toEqual({ ok: false, error: 'BAD_ACCESS' });
    });
    it('rejects an unknown mode', () => {
        expect(validateAccess({ mode: 'secret', invited: [] })).toEqual({ ok: false, error: 'BAD_ACCESS' });
    });
    it('rejects an extra key', () => {
        expect(validateAccess({ mode: 'public', invited: [], evil: 1 })).toEqual({ ok: false, error: 'BAD_ACCESS' });
    });
    it('rejects a non-array invited', () => {
        expect(validateAccess({ mode: 'public', invited: 'x' })).toEqual({ ok: false, error: 'BAD_ACCESS' });
    });
    it('rejects a non-positive or non-integer userId', () => {
        expect(validateAccess({ mode: 'private', invited: [0] })).toEqual({ ok: false, error: 'BAD_ACCESS' });
        expect(validateAccess({ mode: 'private', invited: [1.5] })).toEqual({ ok: false, error: 'BAD_ACCESS' });
        expect(validateAccess({ mode: 'private', invited: [-4] })).toEqual({ ok: false, error: 'BAD_ACCESS' });
    });
    it('rejects duplicate ids', () => {
        expect(validateAccess({ mode: 'private', invited: [7, 7] })).toEqual({ ok: false, error: 'BAD_ACCESS' });
    });
    it('rejects over the cap', () => {
        const many = Array.from({ length: 51 }, (_, i) => i + 1);
        expect(validateAccess({ mode: 'private', invited: many })).toEqual({ ok: false, error: 'BAD_ACCESS' });
    });
});

describe('validateShojiOpen', () => {
    it('accepts a per-side list of travels', () => {
        expect(validateShojiOpen({ front: [0, 1, -1], back: [0] }).ok).toBe(true);
    });

    it('accepts an empty map (every screen closed)', () => {
        expect(validateShojiOpen({}).ok).toBe(true);
    });

    it('rejects an unknown side', () => {
        expect(validateShojiOpen({ roof: [0] }).ok).toBe(false);
    });

    it('rejects more entries than a wall can have bays', () => {
        expect(validateShojiOpen({ front: new Array(MAX_BAYS_PER_SIDE + 1).fill(0) }).ok).toBe(false);
    });

    it('rejects values no run could produce', () => {
        // the true limit is the run's own length and lives in ShojiRun; this only refuses nonsense
        expect(validateShojiOpen({ front: [MAX_BAYS_PER_SIDE] }).ok).toBe(false);
        expect(validateShojiOpen({ front: [Number.NaN] }).ok).toBe(false);
        expect(validateShojiOpen({ front: [Number.POSITIVE_INFINITY] }).ok).toBe(false);
    });

    it('rejects a non-list side and a non-object map', () => {
        expect(validateShojiOpen({ front: 'open' }).ok).toBe(false);
        expect(validateShojiOpen([0, 1]).ok).toBe(false);
    });

    it('travels are continuous, not just whole bays', () => {
        expect(validateShojiOpen({ front: [0.5, -1.25] }).ok).toBe(true);
    });
});

describe('validateLoadout with shojiOpen', () => {
    it('accepts a loadout carrying one', () => {
        expect(validateLoadout({ baseStyle: 'teahouse-1story', shojiOpen: { front: [1, 0] } }).ok).toBe(true);
    });

    it('rejects the whole loadout when it is malformed', () => {
        // half-applying a bad map would leave a house in a state nobody chose
        expect(validateLoadout({ baseStyle: 'teahouse-1story', shojiOpen: { front: ['x'] } }).ok).toBe(false);
    });
});

describe('validateMortarPlacements', () => {
    const owned = ['mortar:S', 'mortar:M'];
    const ok = () => ({ 'mortar:S': { offset: [2, -3], facing: 'N' } });
    it('accepts a well-formed owned placement map', () => {
        expect(validateMortarPlacements(ok(), owned)).toEqual({ ok: true });
    });
    it('accepts an empty object (all defaults)', () => {
        expect(validateMortarPlacements({}, owned)).toEqual({ ok: true });
    });
    it('rejects non-objects, unknown ids, unowned mortars, bad offsets, bad facing', () => {
        expect(validateMortarPlacements(null, owned).ok).toBe(false);
        expect(validateMortarPlacements({ 'mortar:X': { offset: [0, 0], facing: 'N' } }, owned).ok).toBe(false);
        expect(validateMortarPlacements({ 'mortar:L': { offset: [0, 0], facing: 'N' } }, owned).ok).toBe(false);
        expect(validateMortarPlacements({ 'mortar:S': { offset: [0], facing: 'N' } }, owned).ok).toBe(false);
        expect(validateMortarPlacements({ 'mortar:S': { offset: [0, NaN], facing: 'N' } }, owned).ok).toBe(false);
        expect(validateMortarPlacements({ 'mortar:S': { offset: [0, 0], facing: 'Q' } }, owned).ok).toBe(false);
    });
    it('rejects an extra key on a placement entry, mirroring validatePlacement', () => {
        expect(validateMortarPlacements({ 'mortar:S': { offset: [0, 0], facing: 'N', evil: 1 } }, owned).ok).toBe(false);
    });
    it('rejects offsets beyond MAX_PLACEMENT_OFFSET, accepting exactly at the boundary', () => {
        expect(validateMortarPlacements({ 'mortar:S': { offset: [MAX_PLACEMENT_OFFSET + 1, 0], facing: 'N' } }, owned).ok).toBe(false);
        expect(validateMortarPlacements({ 'mortar:S': { offset: [1e300, 0], facing: 'N' } }, owned).ok).toBe(false);
        expect(validateMortarPlacements({ 'mortar:S': { offset: [MAX_PLACEMENT_OFFSET, -MAX_PLACEMENT_OFFSET], facing: 'N' } }, owned))
            .toEqual({ ok: true });
    });
});
