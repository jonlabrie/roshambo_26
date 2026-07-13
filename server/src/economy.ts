export type Size = 'S' | 'M' | 'L';
export const SIZE_RANK: Record<Size, number> = { S: 1, M: 2, L: 3 };
export const PRICES = {
    deck: { S: 50, M: 500, L: 3000 },
    teahouse: { S: 30, M: 300, L: 2000 },
} as const;
export const DEFAULT_TEAHOUSE_LOADOUT = { baseStyle: 'teahouse-1story' };

export type EconomyState = { totalPoints: number; maxDeckSize: Size | null; teahouseSizes: Size[] };
type Check = { ok: true; cost: number } | { ok: false; error: string };

// the tier that must be owned before buying `size` (null = nothing below S)
const below = (size: Size): Size | null => (size === 'S' ? null : size === 'M' ? 'S' : 'M');

export function validatePurchase(state: EconomyState, item: string): Check {
    const [kind, size] = item.split(':') as [string, Size];
    if ((kind !== 'deck' && kind !== 'teahouse') || (size !== 'S' && size !== 'M' && size !== 'L')) {
        return { ok: false, error: 'BAD_ITEM' };
    }
    const cost = PRICES[kind][size];
    if (kind === 'deck') {
        // linear: current max deck must be exactly the tier below
        if (state.maxDeckSize !== below(size)) return { ok: false, error: 'BAD_TIER_ORDER' };
    } else {
        // linear: must own the teahouse tier below (and not already own this one)
        const prev = below(size);
        const owns = (s: Size) => state.teahouseSizes.includes(s);
        if (owns(size) || (prev !== null && !owns(prev))) return { ok: false, error: 'BAD_TIER_ORDER' };
        // gate: a deck at least this size
        if (state.maxDeckSize === null || SIZE_RANK[state.maxDeckSize] < SIZE_RANK[size]) {
            return { ok: false, error: 'DECK_TOO_SMALL' };
        }
    }
    if (state.totalPoints < cost) return { ok: false, error: 'INSUFFICIENT_POINTS' };
    return { ok: true, cost };
}

export function applyPurchase(state: EconomyState, item: string): EconomyState {
    const chk = validatePurchase(state, item);
    if (!chk.ok) throw new Error(`applyPurchase on invalid item: ${chk.error}`);
    const [kind, size] = item.split(':') as [string, Size];
    const next: EconomyState = {
        totalPoints: state.totalPoints - chk.cost,
        maxDeckSize: state.maxDeckSize,
        teahouseSizes: [...state.teahouseSizes],
    };
    if (kind === 'deck') next.maxDeckSize = size;
    else next.teahouseSizes.push(size);
    return next;
}
