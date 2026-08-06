# The firework mobile floor — what was measured, 2026-08-05

This is the provenance for `FireworkDirector.MAX_CONCURRENT` and `.PARTICLES_NEAR`. Read the
limits section before quoting the number: it is a **lower bound, not a curve**.

## The device

| | |
| --- | --- |
| Device | Samsung Galaxy A13 (MediaTek Helio G80), 2022 budget Android |
| Build | the published place, `m4b-zendojo-art-pass` |
| Graphics quality | manual level 5, and separately on Automatic |
| Harness | `roblox/tools/studio/buildFireworkBench.luau` v2 |
| Position | standing still in the arena, facing the shells |

The A13 is **not the target device.** The owner's ruling: *"the one weak device I happen to own"*,
not what the friends-and-family audience will run. It is a canary. That is why the numbers below are
kept conservative rather than raised to match what it survived.

## The result

The bench ramps the launch rate from one shell per 3 seconds down to its floor of **10 shells per
second**, holding each rate for 10 seconds, at roughly 700 particles per shell (peony: 520 main +
180 glitter + 1 flash).

**At the 10/sec floor the place was impacted but still usable, at quality 5 and on Automatic.** The
ramp never crossed the 30fps threshold it was hunting.

For scale: an iPhone 15 Pro handled ~2 shells/sec in July. A player celebrating a win fires **one**
shell.

## What this does NOT tell us

Three limits, all of which matter more than the number itself.

1. **There is no knee.** The bench never dropped below its threshold, so we know the A13 survives
   10/sec and nothing about where it stops. This is a floor under the answer, not the answer.
2. **There is no clean-world baseline.** The bench's first step was meant to fire nothing and report
   the world's own cost. `table.insert(steps, nil)` is a silent no-op in Luau, so the baseline row
   was dropped from the array and never rendered. Fixed in `f263d87`; the number remains uncaptured
   and needs a device to obtain.
3. **It is ONE launcher, at the local player's feet.** The concurrent-shell director — the thing
   this document exists to justify — was never exercised. A 50-player fireworks battle is the real
   worst case and remains unmeasured.

One way the measurement is conservative, which is the right direction: the bench launches within 18
studs of the camera, i.e. **maximum screen coverage**, so the fill-rate axis is already worst-cased.

## Why the constants stay at 14 / 400

Arithmetic, not measurement: at 10 shells/sec with 2–4s bursts, roughly 30 shells were alive at once
at ~700 particles each — call it ~21,000 particles. The director's budget is 14 × 400 = 5,600. That
is roughly **4× headroom**.

The temptation is to raise the constants to match. Don't:

- the headroom figure is inferred, since the bench never reported concurrency;
- the cap's whole purpose is to hold up under a full server firing together, which is precisely the
  case that was not tested;
- and a cap that is too generous fails silently on someone else's phone, in front of guests.

**Known-conservative beats unknown.** Raise these only against a multi-player measurement.

## A caution about how this measurement was nearly lost

Every A13 reading before this one was taken through a **firework bench left ENABLED in
`StarterPlayerScripts` of the published place**, self-ramping for every player on join. It produced
a full session of "the world is too heavy" diagnosis that was measuring the harness. The place ran
at graphics quality 1 with it in, and quality 5 with it out.

Park a bench the instant its reading is taken. Before believing any performance regression,
enumerate what you put in the place first.
