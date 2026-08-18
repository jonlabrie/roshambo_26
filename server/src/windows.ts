// TIME AND QUALIFICATION VOCABULARY. Every stats query takes a window, and several take a
// minimum sample. Defining them once stops each caller inventing its own idea of when a week
// starts — which is how two boards end up disagreeing about the same player.
//
// ALL WINDOWS ARE HALF-OPEN [from, to). An event landing exactly on a boundary belongs to the
// LATER window, never both. Adopted repo-wide in plan 1.
//
// ALL CALENDAR WINDOWS ARE UTC. Not a placeholder for "local time later": players span the
// world and share one World Throw, so a board whose day boundary depends on the viewer would
// rank the same two players differently for each of them.
export interface Window {
    from: Date;
    to: Date;
}

export const HOUR_MS = 60 * 60 * 1000;
export const DAY_MS = 24 * HOUR_MS;
export const WEEK_MS = 7 * DAY_MS;

// HEAT uses rolling windows — "who is on a tear right now" means the last hour, not the hour
// since midnight, which would be nearly empty at 00:05.
export function rollingWindow(now: Date, ms: number): Window {
    return { from: new Date(now.getTime() - ms), to: new Date(now.getTime()) };
}

// RANK uses a ROLLING window (owner, 2026-08-18). The calendar argument was that a standing
// should name a period players agree on — but a Monday boundary wipes a run that started on
// Sunday evening, and it makes WHEN you play matter as much as how well. Rolling rewards
// dropping in at any hour and lets a hot streak count the moment it happens.
// The calendar helpers below stay: records boards still name a day.
export function calendarDayUTC(now: Date): Window {
    const from = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
    return { from, to: new Date(from.getTime() + DAY_MS) };
}

// Weeks start MONDAY, the ISO convention. getUTCDay() is 0 for Sunday, so shift it.
export function calendarWeekUTC(now: Date): Window {
    const day = calendarDayUTC(now);
    const dow = (now.getUTCDay() + 6) % 7; // Mon=0 … Sun=6
    const from = new Date(day.from.getTime() - dow * DAY_MS);
    return { from, to: new Date(from.getTime() + WEEK_MS) };
}

// MINIMUM SAMPLE FOR A RATE BOARD, in THROWS (never rounds elapsed — abstention is normal
// play). A blind player wins 1/3 of rounds, so the standard error of an observed win rate is
// 0.4714/sqrt(n): separating a +5-point edge from luck takes ~356 throws, and +3 points takes
// ~990. Below these, a board ranks noise and the top of it is whoever played least.
//
// These numbers are MEANT TO BE PRINTED on the board next to the ranking ("qualified: 350+
// throws this week"). A rule players can read is worth more here than statistical elegance.
export const QUALIFY = {
    // 360, not the ~356 the standard error strictly needs: rounds are OPEN 51 + LOCK 2 +
    // REVEAL 7 = 60s exactly, so 360 throws is 360 MINUTES. "Play six hours in a week and you
    // are on the board" is a rule a player can hold, and it is printed on the board itself.
    week: 360,
    month: 1000,
    career: 1000,
};
