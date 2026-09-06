import { describe, it, expect } from 'vitest';
import fixture from '../../shared-fixtures/firework-drops.json';
import shells from '../../shared-fixtures/firework-shells.json';
import { DROP_TABLE, dropForStreak } from './drops';

describe('the fixture is the contract', () => {
    it('DROP_TABLE equals the fixture', () => {
        expect(DROP_TABLE).toEqual({
            default: fixture.default,
            tiers: fixture.tiers,
            ticketAtStreak: fixture.ticketAtStreak,
        });
    });
    it('every drop shell is a real, powder-eligible shell', () => {
        const all = [fixture.default, ...Object.values(fixture.tiers)];
        for (const id of all) {
            expect(shells.shells).toContain(id);
            expect(shells.powderIneligible).not.toContain(id);
        }
    });
});

describe('dropForStreak — every fixture case', () => {
    for (const c of fixture.cases) {
        it(`streak ${c.streak} → ${c.shellId}${c.ticket ? ' + ticket' : ''}`, () => {
            expect(dropForStreak(c.streak)).toEqual({ shellId: c.shellId, ticket: c.ticket });
        });
    }
});
