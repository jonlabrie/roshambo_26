// Pure summaries over a simulation log (spec §6). Each answers one of the spec's §7 questions
// and nothing else; the CLI composes them.
import { WHAT_BEATS } from '../engine/CrowdPolicies';
import { RoundRecord, HumanSpec } from './Simulation';

export interface WinRateRow {
    id: string;
    throws: number;
    wins: number;
    safes: number;
    losses: number;
    rate: number; // wins ÷ throws — the stats room's BEAT WORLD; a blind player scores 1/3
    ci95: number; // normal-approximation half-width
}

export function winRates(log: RoundRecord[], humans: HumanSpec[]): WinRateRow[] {
    return humans.map((h, i) => {
        let wins = 0, safes = 0, losses = 0;
        for (const r of log) {
            const res = r.humans[i].result;
            if (res === 'WIN') wins++; else if (res === 'SAFE') safes++; else losses++;
        }
        const throws = log.length;
        const rate = throws === 0 ? 0 : wins / throws;
        const ci95 = throws === 0 ? 0 : 1.96 * Math.sqrt((rate * (1 - rate)) / throws);
        return { id: h.id, throws, wins, safes, losses, rate, ci95 };
    });
}

export interface Transitions {
    same: number;    // world repeated
    counter: number; // world became what beats the last world — the "everyone counters" rotation
    other: number;   // world became what the last world beats
    n: number;       // pairs counted
}

export function worldTransitions(log: RoundRecord[]): Transitions {
    let same = 0, counter = 0, other = 0;
    for (let i = 1; i < log.length; i++) {
        const prev = log[i - 1].world, cur = log[i].world;
        if (cur === prev) same++;
        else if (cur === WHAT_BEATS[prev]) counter++;
        else other++;
    }
    const n = Math.max(0, log.length - 1);
    if (n === 0) return { same: 0, counter: 0, other: 0, n: 0 };
    return { same: same / n, counter: counter / n, other: other / n, n };
}

export function bankedTotals(log: RoundRecord[]): number[] {
    if (log.length === 0) return [];
    const totals = log[0].humans.map(() => 0);
    for (const r of log) r.humans.forEach((h, i) => { totals[i] += h.banked; });
    return totals;
}

// Largest potAfter seen. potAfter is AFTER the round's bank decision, so a rung banker's max
// sits one rung below its bank point; the CLI labels the column accordingly.
export function maxPots(log: RoundRecord[]): number[] {
    if (log.length === 0) return [];
    const maxes = log[0].humans.map(() => 0);
    for (const r of log) r.humans.forEach((h, i) => { maxes[i] = Math.max(maxes[i], h.potAfter); });
    return maxes;
}

// The backlog's "twenty identical blind players... 2.5× the median by chance alone" concern,
// as a number. max ÷ median; null when the median is zero (nobody banked).
export function spreadRatio(totals: number[]): number | null {
    if (totals.length === 0) return null;
    const sorted = [...totals].sort((a, b) => a - b);
    const mid = sorted.length / 2;
    const median = sorted.length % 2 === 1 ? sorted[Math.floor(mid)] : (sorted[mid - 1] + sorted[mid]) / 2;
    if (median === 0) return null;
    return sorted[sorted.length - 1] / median;
}
