import { describe, it, expect } from 'vitest';
import { rollingWindow, calendarDayUTC, calendarWeekUTC, HOUR_MS, DAY_MS, WEEK_MS, QUALIFY } from './windows';

describe('windows', () => {
    it('a rolling window ends at now and starts span-ago', () => {
        const now = new Date(Date.UTC(2026, 7, 16, 14, 30, 0));
        const w = rollingWindow(now, HOUR_MS);
        expect(w.to.toISOString()).toBe(now.toISOString());
        expect(w.from.toISOString()).toBe(new Date(Date.UTC(2026, 7, 16, 13, 30, 0)).toISOString());
    });

    it('a calendar day runs from UTC midnight to the NEXT midnight, half-open', () => {
        const w = calendarDayUTC(new Date(Date.UTC(2026, 7, 16, 14, 30, 0)));
        expect(w.from.toISOString()).toBe('2026-08-16T00:00:00.000Z');
        expect(w.to.toISOString()).toBe('2026-08-17T00:00:00.000Z');
    });

    it('a calendar day is stable anywhere inside it', () => {
        const a = calendarDayUTC(new Date(Date.UTC(2026, 7, 16, 0, 0, 0)));
        const b = calendarDayUTC(new Date(Date.UTC(2026, 7, 16, 23, 59, 59, 999)));
        expect(a.from.toISOString()).toBe(b.from.toISOString());
        expect(a.to.toISOString()).toBe(b.to.toISOString());
    });

    it('a calendar week starts MONDAY 00:00 UTC', () => {
        // 2026-08-16 is a Sunday; its week began Monday the 10th
        const w = calendarWeekUTC(new Date(Date.UTC(2026, 7, 16, 12, 0, 0)));
        expect(w.from.toISOString()).toBe('2026-08-10T00:00:00.000Z');
        expect(w.to.toISOString()).toBe('2026-08-17T00:00:00.000Z');
    });

    it('a Monday belongs to the week it starts, not the one before', () => {
        const w = calendarWeekUTC(new Date(Date.UTC(2026, 7, 10, 0, 0, 0)));
        expect(w.from.toISOString()).toBe('2026-08-10T00:00:00.000Z');
    });

    it('windows are exactly one span long', () => {
        const day = calendarDayUTC(new Date(Date.UTC(2026, 7, 16, 5, 0, 0)));
        expect(day.to.getTime() - day.from.getTime()).toBe(DAY_MS);
        const week = calendarWeekUTC(new Date(Date.UTC(2026, 7, 16, 5, 0, 0)));
        expect(week.to.getTime() - week.from.getTime()).toBe(WEEK_MS);
    });

    it('qualification thresholds are ordered and non-trivial', () => {
        expect(QUALIFY.week).toBe(360); // six hours, and above the ~356 the maths needs
        expect(QUALIFY.month).toBeGreaterThan(QUALIFY.week);
        expect(QUALIFY.career).toBeGreaterThanOrEqual(QUALIFY.month);
    });
});
