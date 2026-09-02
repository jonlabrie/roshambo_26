import { Throw } from './engine/GameRules';

// THE SHELL LEDGER. Ids are mirrored in shared-fixtures/firework-shells.json (the contract with
// roblox/src/shared/FireworkCatalog.luau) and the tests here assert the two agree — a shell the
// shop can sell but the client cannot draw is a blank sky nobody would think to look for.
//
// Prices are deliberately tiny. totalPoints changes ONLY on bank, and at a 60-second round banking
// every win is about one point every three minutes — so a shell must cost about one banked win or
// nobody ever fires one. The 50-point deck is already hours of play.
export const SHELL_IDS = ['firecracker', 'peony', 'willow', 'ishibana', 'kiku', 'wa', 'yashi', 'kamuro'] as const;

export const SHELL_PRICES: Record<string, number> = {
    firecracker: 1,
    peony: 3,
    willow: 4,
    ishibana: 6,
    // The first range-promoted shell (2026-09-04): a hot gold chrysanthemum that ~30% of
    // the time upgrades itself mid-air. Priced above peony for the luck, below willow.
    kiku: 4,
    // The red ring (2026-09-05): ~30% of the time a second, wider ring blooms behind the
    // first with an orange-star kicker -- the first STRUCTURAL surprise. Owner-priced.
    wa: 5,
    yashi: 10,
    kamuro: 10,
};

// Gear, not real estate — deliberately under the deck ladder (50 / 500 / 3000).
export const MORTAR_PRICES = {
    // Owner re-priced 2026-09-05 (was 40/250/1000: "sounds expensive"): gear should be a
    // step, not a wall -- and even these may drop once the Robux benchmark exists.
    'mortar:S': 10,
    'mortar:M': 50,
    'mortar:L': 100,
} as const;

export type MortarId = keyof typeof MORTAR_PRICES;
export const MORTAR_IDS = Object.keys(MORTAR_PRICES) as MortarId[];

const MORTAR_RANK: Record<MortarId, number> = { 'mortar:S': 1, 'mortar:M': 2, 'mortar:L': 3 };

// What a shell needs. Three kinds, one evaluator — a fourth kind is a branch below, not a redesign.
export type Requirement =
    | { kind: 'none' }
    | { kind: 'gear'; mortar: MortarId }
    | { kind: 'condition'; afterWorldThrow: Throw };

// Exported so the gear-requirement half of shared-fixtures/firework-shells.json (the `mortars`
// list) can be asserted against it directly, the same way SHELL_IDS is asserted against
// `fixtures.shells` below — see fireworks.test.ts's "the fixture is the contract" describe block.
// roblox/src/shared/MortarPlacement.luau's SHELL_MORTAR is asserted against the SAME fixture list
// on the Lune side (tests/MortarPlacement.spec.luau), so the two can no longer drift silently.
export const REQUIREMENTS: Record<string, Requirement> = {
    firecracker: { kind: 'none' },
    peony: { kind: 'gear', mortar: 'mortar:S' },
    willow: { kind: 'gear', mortar: 'mortar:M' },
    // Reads the round's outcome; never influences it. That line is what keeps fireworks a safe
    // cosmetic rather than pay-to-win, and it must not be crossed.
    ishibana: { kind: 'condition', afterWorldThrow: 'R' },
    kiku: { kind: 'gear', mortar: 'mortar:S' },
    wa: { kind: 'gear', mortar: 'mortar:M' },
    yashi: { kind: 'gear', mortar: 'mortar:M' },
    kamuro: { kind: 'gear', mortar: 'mortar:L' },
};

export type LaunchContext = { mortars: string[]; lastWorldThrow: Throw | null };
export type ShellState = { count: number; launchable: boolean; reason: string | null };

export function evaluateShell(shellId: string, count: number, ctx: LaunchContext): ShellState {
    const req = REQUIREMENTS[shellId];
    if (!req) return { count, launchable: false, reason: 'BAD_SHELL' };
    // Holding none outranks every other reason: "you have no peony" is more useful to a player
    // than "you need a mortar for the peony you do not have".
    if (count <= 0) return { count, launchable: false, reason: 'NONE_HELD' };
    if (req.kind === 'gear') {
        const need = MORTAR_RANK[req.mortar];
        const best = ctx.mortars.reduce((m, id) => Math.max(m, MORTAR_RANK[id as MortarId] ?? 0), 0);
        if (best < need) {
            return { count, launchable: false, reason: `NEEDS_MORTAR_${req.mortar.slice(-1)}` };
        }
    }
    if (req.kind === 'condition' && ctx.lastWorldThrow !== req.afterWorldThrow) {
        return { count, launchable: false, reason: `WAITING_FOR_${req.afterWorldThrow}` };
    }
    return { count, launchable: true, reason: null };
}

// Every catalogued shell, including the ones held at zero — the picker shows the whole catalogue so
// a player can see what exists and why they cannot fire it yet.
export function shellStates(
    held: Record<string, number>,
    ctx: LaunchContext
): Record<string, ShellState> {
    const out: Record<string, ShellState> = {};
    for (const id of SHELL_IDS) out[id] = evaluateShell(id, held[id] ?? 0, ctx);
    return out;
}
