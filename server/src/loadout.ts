import { DECORATION_PROPS, MAX_DECORATIONS } from './economy';

export const MAX_LOADOUT_BYTES = 4096;
export const MAX_SIZECLASS_LEN = 16;
export const MAX_CLASSES = 8;

const LOADOUT_KEYS = new Set(['baseStyle', 'colorScheme', 'shoji', 'tatami', 'flags', 'wallArt', 'wallBays', 'placement']);

export const KNOWN_SIDES = new Set(['front', 'back', 'left', 'right']);
export const WALLBAY_STATES = new Set(['solid', 'shoji', 'door']);
export const MAX_BAYS_PER_SIDE = 8;

type Check = { ok: true } | { ok: false; error: string };

export function validateWallBays(value: unknown): Check {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
        return { ok: false, error: 'BAD_WALLBAYS' };
    }
    for (const [side, states] of Object.entries(value as Record<string, unknown>)) {
        if (!KNOWN_SIDES.has(side)) return { ok: false, error: 'BAD_WALLBAYS' };
        if (!Array.isArray(states) || states.length > MAX_BAYS_PER_SIDE) {
            return { ok: false, error: 'BAD_WALLBAYS' };
        }
        for (const s of states) {
            if (typeof s !== 'string' || !WALLBAY_STATES.has(s)) {
                return { ok: false, error: 'BAD_WALLBAYS' };
            }
        }
    }
    return { ok: true };
}

export const PLACEMENT_FACINGS = new Set(['N', 'E', 'S', 'W']);
export const MAX_PLACEMENT_OFFSET = 32;

export function validatePlacement(value: unknown): Check {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
        return { ok: false, error: 'BAD_PLACEMENT' };
    }
    const obj = value as Record<string, unknown>;
    for (const k of Object.keys(obj)) {
        if (k !== 'offset' && k !== 'facing') return { ok: false, error: 'BAD_PLACEMENT' };
    }
    if (!Array.isArray(obj.offset) || obj.offset.length !== 2) {
        return { ok: false, error: 'BAD_PLACEMENT' };
    }
    for (const n of obj.offset) {
        if (typeof n !== 'number' || !Number.isFinite(n) || Math.abs(n) > MAX_PLACEMENT_OFFSET) {
            return { ok: false, error: 'BAD_PLACEMENT' };
        }
    }
    if (typeof obj.facing !== 'string' || !PLACEMENT_FACINGS.has(obj.facing)) {
        return { ok: false, error: 'BAD_PLACEMENT' };
    }
    return { ok: true };
}

export function validateDecorations(value: unknown): Check {
    if (!Array.isArray(value)) return { ok: false, error: 'BAD_DECORATION' };
    if (value.length > MAX_DECORATIONS) return { ok: false, error: 'BAD_DECORATION' };
    const seen = new Set<number>();
    for (const entry of value) {
        if (typeof entry !== 'object' || entry === null || Array.isArray(entry)) {
            return { ok: false, error: 'BAD_DECORATION' };
        }
        const obj = entry as Record<string, unknown>;
        for (const k of Object.keys(obj)) {
            if (k !== 'id' && k !== 'propId' && k !== 'offset' && k !== 'facing') {
                return { ok: false, error: 'BAD_DECORATION' };
            }
        }
        if (typeof obj.id !== 'number' || !Number.isInteger(obj.id) || obj.id < 1 || seen.has(obj.id)) {
            return { ok: false, error: 'BAD_DECORATION' };
        }
        seen.add(obj.id);
        if (typeof obj.propId !== 'string' || !DECORATION_PROPS.has(obj.propId)) {
            return { ok: false, error: 'BAD_DECORATION' };
        }
        if (!Array.isArray(obj.offset) || obj.offset.length !== 2) {
            return { ok: false, error: 'BAD_DECORATION' };
        }
        for (const n of obj.offset) {
            if (typeof n !== 'number' || !Number.isFinite(n) || Math.abs(n) > MAX_PLACEMENT_OFFSET) {
                return { ok: false, error: 'BAD_DECORATION' };
            }
        }
        if (typeof obj.facing !== 'string' || !PLACEMENT_FACINGS.has(obj.facing)) {
            return { ok: false, error: 'BAD_DECORATION' };
        }
    }
    return { ok: true };
}

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
    if (obj.wallBays !== undefined) {
        const wb = validateWallBays(obj.wallBays);
        if (!wb.ok) return wb;
    }
    if (obj.placement !== undefined) {
        const p = validatePlacement(obj.placement);
        if (!p.ok) return p;
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
