export const MAX_LOADOUT_BYTES = 4096;
export const MAX_SIZECLASS_LEN = 16;
export const MAX_CLASSES = 8;

const LOADOUT_KEYS = new Set(['baseStyle', 'colorScheme', 'shoji', 'tatami', 'flags', 'wallArt']);

type Check = { ok: true } | { ok: false; error: string };

export function validateLoadout(loadout: unknown): Check {
    if (typeof loadout !== 'object' || loadout === null || Array.isArray(loadout)) {
        return { ok: false, error: 'LOADOUT_NOT_OBJECT' };
    }
    const obj = loadout as Record<string, unknown>;
    if (typeof obj.baseStyle !== 'string' || obj.baseStyle.length === 0) {
        return { ok: false, error: 'MISSING_BASESTYLE' };
    }
    for (const k of Object.keys(obj)) {
        if (!LOADOUT_KEYS.has(k)) return { ok: false, error: 'UNKNOWN_KEY' };
    }
    if (Buffer.byteLength(JSON.stringify(obj), 'utf8') > MAX_LOADOUT_BYTES) {
        return { ok: false, error: 'LOADOUT_TOO_LARGE' };
    }
    return { ok: true };
}

export function validateSizeClass(sizeClass: unknown, existingClasses: string[]): Check {
    if (typeof sizeClass !== 'string' || sizeClass.length === 0 || sizeClass.length > MAX_SIZECLASS_LEN) {
        return { ok: false, error: 'BAD_SIZECLASS' };
    }
    if (!existingClasses.includes(sizeClass) && existingClasses.length >= MAX_CLASSES) {
        return { ok: false, error: 'TOO_MANY_CLASSES' };
    }
    return { ok: true };
}

export const MAX_PREFERENCES = 32;
export const MAX_PREFERENCE_LEN = 32;

export function validatePadPreferences(value: unknown): Check {
    if (!Array.isArray(value)) {
        return { ok: false, error: 'BAD_REQUEST' };
    }
    if (value.length > MAX_PREFERENCES) {
        return { ok: false, error: 'BAD_REQUEST' };
    }
    for (const entry of value) {
        if (typeof entry !== 'string' || entry.length === 0 || entry.length > MAX_PREFERENCE_LEN) {
            return { ok: false, error: 'BAD_REQUEST' };
        }
    }
    return { ok: true };
}
