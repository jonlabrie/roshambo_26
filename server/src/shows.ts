// A SHOW IS DATA (spec 2026-09-05-fireworks-show-system-design §1). This is the TypeScript twin of
// roblox/src/shared/ShowPlan.luau; both are held to shared-fixtures/shows.json so a rule that
// exists on one side only fails CI instead of letting a client author a show the backend refuses
// (or worse, the reverse). Limits bound payload size, not spectacle — density is the director's
// business, not the validator's.
import { SHELL_IDS, REQUIREMENTS } from './fireworks';

export type Cue = { t_ms: number; slot: string; shellId: string };
export type ShowInput = { stageId: string; fuel: 'inventory' | 'powder'; cues: Cue[]; title?: string };
export type StageSlots = Record<string, string>; // slot -> 'none' | 'any' | 'mortar:S' | 'mortar:M' | 'mortar:L'
export type ShowError =
    | 'EMPTY' | 'TOO_MANY_CUES' | 'TOO_LONG' | 'BAD_CUE' | 'NEGATIVE_TIME'
    | 'CUES_OUT_OF_ORDER' | 'BAD_SLOT' | 'BAD_SHELL' | 'TIER_MISMATCH';
export type ShowCheck = { ok: true } | { ok: false; error: ShowError; cue?: number };

// LITERALS, asserted equal to shared-fixtures/shows.json by shows.test.ts — the same pattern as
// GameRules.ts vs game-rules.json. Runtime code never reads the fixture: `rootDir` is src/ and the
// deployed container is built from server/ alone.
export const SHOW_LIMITS = { maxCues: 120, maxDurationS: 300 };
export const DECK_STAGE: StageSlots = { hand: 'none', 'mortar:S': 'mortar:S', 'mortar:M': 'mortar:M', 'mortar:L': 'mortar:L' };

export function shellMortar(shellId: string): string | null {
    const req = REQUIREMENTS[shellId];
    return req && req.kind === 'gear' ? req.mortar : null;
}

function isCue(c: unknown): c is Cue {
    if (typeof c !== 'object' || c === null) return false;
    const o = c as Record<string, unknown>;
    return typeof o.t_ms === 'number' && Number.isFinite(o.t_ms)
        && typeof o.slot === 'string' && typeof o.shellId === 'string';
}

export function validateShow(cues: unknown, stage: StageSlots): ShowCheck {
    if (!Array.isArray(cues) || cues.length === 0) return { ok: false, error: 'EMPTY' };
    if (cues.length > SHOW_LIMITS.maxCues) return { ok: false, error: 'TOO_MANY_CUES' };
    let last = -Infinity;
    for (let i = 0; i < cues.length; i++) {
        const c = cues[i];
        if (!isCue(c)) return { ok: false, error: 'BAD_CUE', cue: i };
        if (c.t_ms < 0) return { ok: false, error: 'NEGATIVE_TIME', cue: i };
        if (c.t_ms < last) return { ok: false, error: 'CUES_OUT_OF_ORDER', cue: i };
        last = c.t_ms;
        // Own-property only: `stage['toString']` would otherwise resolve to an inherited function,
        // pass an `undefined` check, and crash the tier test below — while the Luau twin, whose
        // tables have no inherited string keys, returned BAD_SLOT. The value must also be one of
        // the three shapes the grammar defines, so a typo'd tier in a stage definition is a bad
        // slot rather than silently degrading to 'any'.
        const accepts = Object.prototype.hasOwnProperty.call(stage, c.slot) ? stage[c.slot] : undefined;
        if (accepts !== 'none' && accepts !== 'any' && !(typeof accepts === 'string' && accepts.startsWith('mortar:'))) {
            return { ok: false, error: 'BAD_SLOT', cue: i };
        }
        if (!(SHELL_IDS as readonly string[]).includes(c.shellId)) return { ok: false, error: 'BAD_SHELL', cue: i };
        const needs = shellMortar(c.shellId);
        if (accepts === 'none' && needs !== null) return { ok: false, error: 'TIER_MISMATCH', cue: i };
        if (accepts.startsWith('mortar:') && needs !== accepts) return { ok: false, error: 'TIER_MISMATCH', cue: i };
        // 'any' accepts everything (public tubes).
    }
    if (last > SHOW_LIMITS.maxDurationS * 1000) return { ok: false, error: 'TOO_LONG' };
    return { ok: true };
}

export function tallyShells(cues: Cue[]): Record<string, number> {
    const out: Record<string, number> = {};
    for (const c of cues) out[c.shellId] = (out[c.shellId] ?? 0) + 1;
    return out;
}
