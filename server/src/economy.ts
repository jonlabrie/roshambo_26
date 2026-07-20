export type Size = 'S' | 'M' | 'L';
export const SIZE_RANK: Record<Size, number> = { S: 1, M: 2, L: 3 };
export const PRICES = {
    deck: { S: 50, M: 500, L: 3000 },
    teahouse: { S: 30, M: 300, L: 2000 },
    portal: 500,
    decoration: { ishidoro: 40, tsukubai: 60, bonsai: 25, bench: 35 },
} as const;
export const DEFAULT_TEAHOUSE_LOADOUT = { baseStyle: 'teahouse-1story' };

export const MAX_DECORATIONS = 24;
export const DECORATION_PROPS: Set<string> = new Set(Object.keys(PRICES.decoration));

export const MAX_INVITED = 50;
export type AccessMode = 'public' | 'friends' | 'private';
export const ACCESS_MODES: Set<string> = new Set<string>(['public', 'friends', 'private']);
export type TeahouseAccess = { mode: AccessMode; invited: number[] };
export const DEFAULT_ACCESS: TeahouseAccess = { mode: 'public', invited: [] };

export type DeckDecoration = { id: number; propId: string; offset: [number, number]; facing: 'N' | 'E' | 'S' | 'W' };

export function nextDecorationId(decorations: DeckDecoration[]): number {
    return decorations.reduce((m, d) => Math.max(m, d.id), 0) + 1;
}

export function appendDecoration(
    decorations: DeckDecoration[],
    propId: string,
): { list: DeckDecoration[]; instance: DeckDecoration } {
    const instance: DeckDecoration = { id: nextDecorationId(decorations), propId, offset: [0, 0], facing: 'N' };
    return { list: [...decorations, instance], instance };
}

export type EconomyState = { totalPoints: number; maxDeckSize: Size | null; teahouseSizes: Size[]; portalOwned?: boolean; deckDecorationCount?: number };
type Check = { ok: true; cost: number } | { ok: false; error: string };

// the tier that must be owned before buying `size` (null = nothing below S)
const below = (size: Size): Size | null => (size === 'S' ? null : size === 'M' ? 'S' : 'M');

export function validatePurchase(state: EconomyState, item: string): Check {
    if (item === 'portal') {
        if (state.maxDeckSize === null) return { ok: false, error: 'NEEDS_DECK' };
        if (state.portalOwned) return { ok: false, error: 'ALREADY_OWNED' };
        if (state.totalPoints < PRICES.portal) return { ok: false, error: 'INSUFFICIENT_POINTS' };
        return { ok: true, cost: PRICES.portal };
    }
    if (item.startsWith('decoration:')) {
        const propId = item.slice('decoration:'.length);
        if (state.maxDeckSize === null) return { ok: false, error: 'NEEDS_DECK' };
        if (!DECORATION_PROPS.has(propId)) return { ok: false, error: 'BAD_ITEM' };
        if ((state.deckDecorationCount ?? 0) >= MAX_DECORATIONS) return { ok: false, error: 'DECOR_CAP' };
        const cost = (PRICES.decoration as Record<string, number>)[propId];
        if (state.totalPoints < cost) return { ok: false, error: 'INSUFFICIENT_POINTS' };
        return { ok: true, cost };
    }
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
    const next: EconomyState = {
        totalPoints: state.totalPoints - chk.cost,
        maxDeckSize: state.maxDeckSize,
        teahouseSizes: [...state.teahouseSizes],
        portalOwned: state.portalOwned ?? false,
    };
    if (item === 'portal') {
        next.portalOwned = true;
        return next;
    }
    if (item.startsWith('decoration:')) {
        return next; // cost already deducted above; decoration list is tracked outside EconomyState
    }
    const [kind, size] = item.split(':') as [string, Size];
    if (kind === 'deck') next.maxDeckSize = size;
    else next.teahouseSizes.push(size);
    return next;
}

export type DeckDisplay = Size | null;
export type TeahouseDisplay = 'none' | Size | null;

const isSize = (v: unknown): v is Size => v === 'S' || v === 'M' || v === 'L';
const ownedMaxTeahouse = (state: EconomyState): Size | null =>
  state.teahouseSizes.reduce<Size | null>((m, s) => (m === null || SIZE_RANK[s] > SIZE_RANK[m] ? s : m), null);

export function validateDisplay(
  state: EconomyState,
  deckDisplay: unknown,
  teahouseDisplay: unknown,
): { ok: true; deckDisplay: DeckDisplay; teahouseDisplay: TeahouseDisplay } | { ok: false; error: string } {
  // deck: null or a Size <= owned maxDeckSize; 'none' is NOT allowed for the deck
  if (deckDisplay !== null && !isSize(deckDisplay)) return { ok: false, error: 'BAD_DISPLAY' };
  if (isSize(deckDisplay)) {
    if (state.maxDeckSize === null || SIZE_RANK[deckDisplay] > SIZE_RANK[state.maxDeckSize]) {
      return { ok: false, error: 'DISPLAY_UNOWNED' };
    }
  }
  // teahouse: null, 'none', or a Size <= owned max teahouse
  if (teahouseDisplay !== null && teahouseDisplay !== 'none' && !isSize(teahouseDisplay)) {
    return { ok: false, error: 'BAD_DISPLAY' };
  }
  if (isSize(teahouseDisplay)) {
    const owned = ownedMaxTeahouse(state);
    if (owned === null || SIZE_RANK[teahouseDisplay] > SIZE_RANK[owned]) {
      return { ok: false, error: 'DISPLAY_UNOWNED' };
    }
  }
  return { ok: true, deckDisplay: deckDisplay as DeckDisplay, teahouseDisplay: teahouseDisplay as TeahouseDisplay };
}
