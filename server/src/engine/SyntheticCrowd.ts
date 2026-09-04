// A crowd is a bag of policies (spec §2). Each bot is one archetype plus a small memory; the
// crowd tallies their throws and, once the World Throw is decided, tells every bot what
// happened so it can react next round. Bots have no pot and never bank: a bot's "result" is
// only the input to its next decision.
//
// Composition is EXACT, not sampled: `allocate` gives a 30-bot crowd the same archetype split
// every boot, so CROWD_SEED reproduces a run rather than a distribution of runs.
import { Throw } from './GameRules';
import { Rng } from './Prng';
import {
    PolicyId, POLICY_IDS, Memory, Dist, freshMemory, policyDistribution, sample, advance,
} from './CrowdPolicies';

export type Mix = Partial<Record<PolicyId, number>>;

// Settled 2026-09-04 by the simulator's readability experiment (spec §2, Q0), not by taste.
// The first hypothesis (wsls:35, counter:20, conform:15) was a metronome: `wsls`'s lose-shift is
// CLOCKWISE, which lands exactly on the counter-throw, so wsls and counter pulled the same way and
// the World Throw rotated counter-wards 82% of the time — "throw what beats the counter" (`second`)
// beat the world 82.4%, and the naive `counter` reader was punished at 6.8%. Halving `counter` and
// doubling `conform` sets the counter-pull against a stay-put pull, so the world's transitions
// spread. At 20000 rounds, crowd 30, seeds 1-3: `second` 51.4-52.4%, `counter` 42.0-42.6%,
// `wsls` 32.8-33.0%, `random` 29.4-29.8%, oracle 56.0-56.5%. Readable, contested, and — because the
// oracle now clears every teachable rule by ~4 points — not fully solved by any one of them.
export const DEFAULT_MIX: Mix = { wsls: 30, counter: 10, conform: 30, rocky: 10, random: 20 };
export const DEFAULT_STRENGTH = 0.7;

export function parseMix(spec: string): Mix {
    const parts = spec.split(',').map(s => s.trim()).filter(s => s.length > 0);
    if (parts.length === 0) throw new Error('CROWD_MIX: empty');
    const mix: Mix = {};
    for (const part of parts) {
        const [rawId, rawWeight] = part.split(':').map(s => s.trim());
        const id = rawId as PolicyId;
        if (!POLICY_IDS.includes(id)) {
            throw new Error(`CROWD_MIX: unknown archetype "${rawId}" (known: ${POLICY_IDS.join(', ')})`);
        }
        const weight = Number(rawWeight);
        if (rawWeight === undefined || rawWeight === '' || !Number.isFinite(weight) || weight <= 0) {
            throw new Error(`CROWD_MIX: weight for "${id}" must be a positive number, got "${rawWeight ?? ''}"`);
        }
        if (mix[id] !== undefined) throw new Error(`CROWD_MIX: "${id}" listed twice`);
        mix[id] = weight;
    }
    return mix;
}

export function formatMix(mix: Mix): string {
    return POLICY_IDS.filter(id => (mix[id] ?? 0) > 0).map(id => `${id}:${mix[id]}`).join(',');
}

// Largest-remainder allocation in POLICY_IDS order; ties on the fractional part go to the
// earlier id. Deterministic by construction.
export function allocate(size: number, mix: Mix): PolicyId[] {
    const ids = POLICY_IDS.filter(id => (mix[id] ?? 0) > 0);
    const total = ids.reduce((s, id) => s + (mix[id] as number), 0);
    if (size <= 0 || ids.length === 0 || total <= 0) return [];
    const quotas = ids.map(id => (size * (mix[id] as number)) / total);
    const counts = quotas.map(q => Math.floor(q));
    let remainder = size - counts.reduce((s, c) => s + c, 0);
    const byFraction = ids
        .map((_, i) => i)
        .sort((a, b) => (quotas[b] - counts[b]) - (quotas[a] - counts[a]) || a - b);
    for (const i of byFraction) {
        if (remainder === 0) break;
        counts[i]++;
        remainder--;
    }
    const out: PolicyId[] = [];
    ids.forEach((id, i) => { for (let k = 0; k < counts[i]; k++) out.push(id); });
    return out;
}

export interface Crowd {
    readonly size: number;
    throws(roundCount: number): Record<Throw, number>;
    observe(worldThrow: Throw): void;
    expected(): Dist; // sum of every bot's current distribution — the oracle's input
}

interface Bot {
    id: PolicyId;
    memory: Memory;
    pending?: Throw; // this round's throw, awaiting the World Throw
}

export function createCrowd(opts: { size: number; mix?: Mix; strength?: number; rng: Rng }): Crowd {
    const strength = opts.strength ?? DEFAULT_STRENGTH;
    const bots: Bot[] = allocate(opts.size, opts.mix ?? DEFAULT_MIX).map(id => ({ id, memory: freshMemory() }));
    return {
        size: bots.length,
        throws() {
            const counts: Record<Throw, number> = { R: 0, P: 0, S: 0 };
            for (const bot of bots) {
                const t = sample(policyDistribution(bot.id, bot.memory, strength), opts.rng);
                bot.pending = t;
                counts[t]++;
            }
            return counts;
        },
        observe(worldThrow) {
            for (const bot of bots) {
                if (bot.pending) {
                    bot.memory = advance(bot.memory, bot.pending, worldThrow);
                    bot.pending = undefined;
                } else {
                    bot.memory = { ...bot.memory, lastWorld: worldThrow };
                }
            }
        },
        expected() {
            const sum: Dist = { R: 0, P: 0, S: 0 };
            for (const bot of bots) {
                const d = policyDistribution(bot.id, bot.memory, strength);
                sum.R += d.R; sum.P += d.P; sum.S += d.S;
            }
            return sum;
        },
    };
}
