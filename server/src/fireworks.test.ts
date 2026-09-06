import { describe, it, expect } from 'vitest';
import fixtures from '../../shared-fixtures/firework-shells.json';
import {
    SHELL_IDS,
    SHELL_PRICES,
    MORTAR_PRICES,
    REQUIREMENTS,
    evaluateShell,
    shellStates,
    LaunchContext,
    POWDER_INELIGIBLE,
    isPowderEligible,
} from './fireworks';

const noGear: LaunchContext = { mortars: [], lastWorldThrow: null };

describe('the fixture is the contract', () => {
    it('every fixture id has a price', () => {
        for (const id of fixtures.shells) expect(typeof SHELL_PRICES[id]).toBe('number');
    });
    it('SHELL_IDS matches the fixture exactly', () => {
        expect([...SHELL_IDS].sort()).toEqual([...fixtures.shells].sort());
    });
});

// Final-review fix round (deck-mortars): SHELL_MORTAR (roblox/src/shared/MortarPlacement.luau)
// used to be a hand-mirrored copy of REQUIREMENTS' `.mortar` fields with no test on either side —
// house rule is drift fails CI. fixtures.mortars is the gear-required subset of fixtures.shells;
// every OTHER shell in fixtures.shells must NOT require gear on this side, and MortarPlacement's
// own Lune spec asserts the identical fixture against SHELL_MORTAR.
describe('the fixture is the gear-requirement contract too', () => {
    const gearMap = new Map(fixtures.mortars.map((m) => [m.shell, m.mortar]));

    it('every fixture shell not listed in mortars requires no gear', () => {
        for (const id of fixtures.shells) {
            if (gearMap.has(id)) continue;
            expect(REQUIREMENTS[id]?.kind).not.toBe('gear');
        }
    });

    it('every fixture mortars entry matches REQUIREMENTS exactly', () => {
        for (const [shell, mortar] of gearMap) {
            expect(REQUIREMENTS[shell]).toEqual({ kind: 'gear', mortar });
        }
    });

    it('no OTHER shell quietly grew a gear requirement missing from the fixture', () => {
        for (const id of fixtures.shells) {
            const req = REQUIREMENTS[id];
            if (req?.kind === 'gear') {
                expect(gearMap.get(id)).toBe(req.mortar);
            }
        }
    });
});

describe('prices', () => {
    it('shells cost about one banked win', () => {
        expect(SHELL_PRICES.firecracker).toBe(1);
        expect(SHELL_PRICES.peony).toBe(3);
        expect(SHELL_PRICES.willow).toBe(4);
        expect(SHELL_PRICES.ishibana).toBe(6);
    });
    it('tubes sit below the deck ladder', () => {
        // Owner re-priced 2026-09-05 (was 40/250/1000): gear is a step, not a wall.
        expect(MORTAR_PRICES['mortar:S']).toBe(10);
        expect(MORTAR_PRICES['mortar:M']).toBe(50);
        expect(MORTAR_PRICES['mortar:L']).toBe(100);
    });
});

describe('requirement kind: none', () => {
    it('a firecracker you hold is launchable with no gear and no condition', () => {
        expect(evaluateShell('firecracker', 1, noGear)).toEqual({
            count: 1,
            launchable: true,
            reason: null,
            powderEligible: true,
        });
    });
    it('holding none beats every other reason', () => {
        expect(evaluateShell('firecracker', 0, noGear)).toEqual({
            count: 0,
            launchable: false,
            reason: 'NONE_HELD',
            powderEligible: true,
        });
    });
});

describe('requirement kind: gear', () => {
    it('a peony needs a small mortar', () => {
        expect(evaluateShell('peony', 2, noGear)).toEqual({
            count: 2,
            launchable: false,
            reason: 'NEEDS_MORTAR_S',
            powderEligible: true,
        });
    });
    it('and flies once you own one', () => {
        const ctx: LaunchContext = { mortars: ['mortar:S'], lastWorldThrow: null };
        expect(evaluateShell('peony', 2, ctx)).toEqual({
            count: 2,
            launchable: true,
            reason: null,
            powderEligible: true,
        });
    });
    it('a bigger tube satisfies a smaller requirement', () => {
        const ctx: LaunchContext = { mortars: ['mortar:L'], lastWorldThrow: null };
        expect(evaluateShell('peony', 1, ctx).launchable).toBe(true);
        expect(evaluateShell('willow', 1, ctx).launchable).toBe(true);
    });
    it('a smaller tube does NOT satisfy a bigger requirement', () => {
        const ctx: LaunchContext = { mortars: ['mortar:S'], lastWorldThrow: null };
        expect(evaluateShell('willow', 1, ctx)).toEqual({
            count: 1,
            launchable: false,
            reason: 'NEEDS_MORTAR_M',
            powderEligible: true,
        });
    });
});

describe('requirement kind: condition', () => {
    it('ishibana waits for Rock', () => {
        const ctx: LaunchContext = { mortars: [], lastWorldThrow: 'P' };
        expect(evaluateShell('ishibana', 1, ctx)).toEqual({
            count: 1,
            launchable: false,
            reason: 'WAITING_FOR_R',
            powderEligible: true,
        });
    });
    it('and flies in the round after the world throws Rock', () => {
        const ctx: LaunchContext = { mortars: [], lastWorldThrow: 'R' };
        expect(evaluateShell('ishibana', 1, ctx)).toEqual({
            count: 1,
            launchable: true,
            reason: null,
            powderEligible: true,
        });
    });
    it('an unknown last throw is not Rock', () => {
        expect(evaluateShell('ishibana', 1, noGear).launchable).toBe(false);
    });
});

describe('unknown ids', () => {
    it('are never launchable', () => {
        expect(evaluateShell('nope', 5, noGear)).toEqual({
            count: 5,
            launchable: false,
            reason: 'BAD_SHELL',
            powderEligible: false,
        });
    });
});

describe('shellStates', () => {
    it('reports every catalogued shell, including ones you hold none of', () => {
        const states = shellStates({ firecracker: 2 }, noGear);
        expect(Object.keys(states).sort()).toEqual([...SHELL_IDS].sort());
        expect(states.firecracker.count).toBe(2);
        expect(states.peony).toEqual({
            count: 0,
            launchable: false,
            reason: 'NONE_HELD',
            powderEligible: true,
        });
    });
});

describe('the fixture is the powder-eligibility contract too', () => {
    it('POWDER_INELIGIBLE equals the fixture list', () => {
        expect([...POWDER_INELIGIBLE].sort()).toEqual([...fixtures.powderIneligible].sort());
    });
    it('every ineligible id is a real shell', () => {
        for (const id of fixtures.powderIneligible) expect(fixtures.shells).toContain(id);
    });
    it('isPowderEligible: true for every shipped shell today, false for unknown ids', () => {
        for (const id of SHELL_IDS) expect(isPowderEligible(id)).toBe(!POWDER_INELIGIBLE.has(id));
        expect(isPowderEligible('moonshot')).toBe(false);
    });
    it('shellStates carries powderEligible per shell', () => {
        const states = shellStates({ firecracker: 2 }, noGear);
        expect(states.firecracker.powderEligible).toBe(true);
        expect(states.kamuro.powderEligible).toBe(true);
    });
});
