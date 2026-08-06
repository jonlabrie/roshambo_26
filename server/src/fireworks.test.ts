import { describe, it, expect } from 'vitest';
import fixtures from '../../shared-fixtures/firework-shells.json';
import {
    SHELL_IDS,
    SHELL_PRICES,
    MORTAR_PRICES,
    evaluateShell,
    shellStates,
    LaunchContext,
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

describe('prices', () => {
    it('shells cost about one banked win', () => {
        expect(SHELL_PRICES.firecracker).toBe(1);
        expect(SHELL_PRICES.peony).toBe(3);
        expect(SHELL_PRICES.willow).toBe(4);
        expect(SHELL_PRICES.ishibana).toBe(6);
    });
    it('tubes sit below the deck ladder', () => {
        expect(MORTAR_PRICES['mortar:S']).toBe(40);
        expect(MORTAR_PRICES['mortar:M']).toBe(250);
        expect(MORTAR_PRICES['mortar:L']).toBe(1000);
    });
});

describe('requirement kind: none', () => {
    it('a firecracker you hold is launchable with no gear and no condition', () => {
        expect(evaluateShell('firecracker', 1, noGear)).toEqual({
            count: 1,
            launchable: true,
            reason: null,
        });
    });
    it('holding none beats every other reason', () => {
        expect(evaluateShell('firecracker', 0, noGear)).toEqual({
            count: 0,
            launchable: false,
            reason: 'NONE_HELD',
        });
    });
});

describe('requirement kind: gear', () => {
    it('a peony needs a small mortar', () => {
        expect(evaluateShell('peony', 2, noGear)).toEqual({
            count: 2,
            launchable: false,
            reason: 'NEEDS_MORTAR_S',
        });
    });
    it('and flies once you own one', () => {
        const ctx: LaunchContext = { mortars: ['mortar:S'], lastWorldThrow: null };
        expect(evaluateShell('peony', 2, ctx)).toEqual({ count: 2, launchable: true, reason: null });
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
        });
    });
    it('and flies in the round after the world throws Rock', () => {
        const ctx: LaunchContext = { mortars: [], lastWorldThrow: 'R' };
        expect(evaluateShell('ishibana', 1, ctx)).toEqual({
            count: 1,
            launchable: true,
            reason: null,
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
        });
    });
});

describe('shellStates', () => {
    it('reports every catalogued shell, including ones you hold none of', () => {
        const states = shellStates({ firecracker: 2 }, noGear);
        expect(Object.keys(states).sort()).toEqual([...SHELL_IDS].sort());
        expect(states.firecracker.count).toBe(2);
        expect(states.peony).toEqual({ count: 0, launchable: false, reason: 'NONE_HELD' });
    });
});
