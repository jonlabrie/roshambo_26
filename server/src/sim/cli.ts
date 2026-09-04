// npm run sim -- [--experiment readability|blind-spread|effective-n] [--rounds N] [--crowd N]
//                [--mix id:w,...] [--strength p] [--seed N] [--json]
import { formatMix } from '../engine/SyntheticCrowd';
import { parseArgs, readability, blindSpread, effectiveN } from './experiments';

const pct = (x: number) => `${(100 * x).toFixed(1)}%`;

function main(argv: string[]): void {
    const a = parseArgs(argv);
    const out = a.experiment === 'readability' ? readability(a)
        : a.experiment === 'blind-spread' ? blindSpread(a)
        : effectiveN(a);

    if (a.json) {
        console.log(JSON.stringify(out, null, 2));
        return;
    }

    console.log(`# ${a.experiment}  rounds=${a.rounds} crowd=${a.crowd} strength=${a.strength} seed=${a.seed}`);
    console.log(`# mix ${formatMix(a.mix)}`);
    if ('transitions' in out) {
        console.log('\nhuman     BEAT WORLD   ±95%    safe    loss    banked      max pot*');
        for (const h of out.humans) {
            console.log(`${h.id.padEnd(9)} ${pct(h.rate).padStart(10)} ${pct(h.ci95).padStart(6)} ${pct(h.safes / h.throws).padStart(7)} ${pct(h.losses / h.throws).padStart(7)} ${String(h.banked).padStart(9)} ${String(h.maxPot).padStart(12)}`);
        }
        console.log('* max pot is measured AFTER each round\'s bank decision');
        const t = out.transitions;
        console.log(`\nworld throw transitions (n=${t.n}): same ${pct(t.same)}  counter ${pct(t.counter)}  other ${pct(t.other)}`);
        console.log('(a blind world is 33/33/33; "counter" high means the crowd rotates the way everyone-counters predicts)');
    } else if ('ratios' in out) {
        console.log(`\n${out.players} blind players, bank at 9, ${out.runs} runs of ${a.rounds} rounds`);
        console.log(`max ÷ median banked: mean ${out.meanRatio?.toFixed(2) ?? 'n/a'}  worst ${out.maxRatio?.toFixed(2) ?? 'n/a'}`);
        console.log(`per run: ${out.ratios.map(r => r.toFixed(2)).join(' ')}`);
    } else {
        console.log('\ncrowd   counter BEAT WORLD   ±95%');
        for (const r of out.rows) console.log(`${String(r.crowd).padStart(5)} ${pct(r.rate).padStart(20)} ${pct(r.ci95).padStart(6)}`);
        console.log('(where the rate stops moving, the human\'s own throw has stopped moving the plurality)');
    }
}

main(process.argv.slice(2));
