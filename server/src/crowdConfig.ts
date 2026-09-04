// The synthetic crowd's env surface (spec §5): CROWD_SIZE, CROWD_MIX, CROWD_SEED. House pattern
// is config over commits (round durations, WORLD_THROW_MIN_PARTICIPANTS), so the crowd is a
// service setting, not a deploy. Extracted from index.ts like testModeCycle.ts so it is testable.
import { Mix, parseMix, DEFAULT_MIX } from './engine/SyntheticCrowd';

export interface CrowdConfig {
    size: number;
    mix: Mix;
    seed: number;
}

function nonNegativeInt(name: string, raw: string): number {
    const n = Number(raw);
    if (!Number.isInteger(n) || n < 0) throw new Error(`${name}="${raw}" must be a non-negative integer`);
    return n;
}

export function readCrowdConfig(
    env: Record<string, string | undefined>,
    opts: { testMode: boolean; log: (msg: string) => void; randomSeed: () => number },
): CrowdConfig | null {
    const rawSize = env.CROWD_SIZE;
    if (rawSize === undefined || rawSize === '') return null;
    const size = nonNegativeInt('CROWD_SIZE', rawSize);
    if (size === 0) return null;

    // A cycled World Throw beside a plurality distribution that disagrees with it is exactly
    // the lie the engine-side merge exists to prevent (spec §1, §5).
    if (opts.testMode) {
        opts.log(`[CROWD] CROWD_SIZE=${size} ignored: TEST_MODE cycles the World Throw, and a crowd whose plurality disagrees with it would lie on the reveal card`);
        return null;
    }

    const mix = env.CROWD_MIX !== undefined && env.CROWD_MIX !== '' ? parseMix(env.CROWD_MIX) : DEFAULT_MIX;

    let seed: number;
    if (env.CROWD_SEED !== undefined && env.CROWD_SEED !== '') {
        seed = nonNegativeInt('CROWD_SEED', env.CROWD_SEED);
    } else {
        seed = opts.randomSeed();
        opts.log(`[CROWD] CROWD_SEED unset; using ${seed} (set CROWD_SEED=${seed} to reproduce this run)`);
    }
    return { size, mix, seed };
}
