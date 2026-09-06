// WHAT A WIN DROPS (spec 2026-09-05 §7). Keyed to the streak AFTER the win and awarded on the WIN
// event, so it never leans on Bank vs Stake — banking does not reset currentStreak. Drops are
// ITEMS: "you got a peony" is legible to an eight-year-old; a number ticking up is not. A dropped
// gear shell a player cannot fire yet is not a dead item — it melts (Task 4).
//
// LITERALS, asserted equal to shared-fixtures/firework-drops.json by drops.test.ts. The tiers are
// starting values: the ticket at six follows from the rooftop's capacity (spec §5), and every
// tier is one fixture edit plus this table.
export const DROP_TABLE = {
    default: 'firecracker',
    tiers: { 3: 'peony', 5: 'wa' } as Record<number, string>,
    ticketAtStreak: 6,
};

export type Drop = { shellId: string; ticket: boolean };

export function dropForStreak(streak: number): Drop {
    if (!Number.isInteger(streak) || streak < 1) return { shellId: DROP_TABLE.default, ticket: false };
    return {
        shellId: DROP_TABLE.tiers[streak] ?? DROP_TABLE.default,
        ticket: streak === DROP_TABLE.ticketAtStreak,
    };
}
