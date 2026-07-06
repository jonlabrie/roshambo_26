import { describe, it, expect } from 'vitest';
import { validateLoadout, validateSizeClass, MAX_CLASSES } from './loadout';

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
