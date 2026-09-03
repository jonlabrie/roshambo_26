---
shelf: practice
updated: 2026-08-15
checked: 2026-09-03
---

# Perf Harness Contamination

Standing rule: **before diagnosing any performance problem, first enumerate what you
yourself added to the environment.** Test harnesses, benches, debug spawners,
profiling overlays. Check that list before you check the content.

## What happened (2026-08-05)

The owner pasted `roblox/tools/studio/buildFireworkBench.luau` into Studio to measure a
mobile particle floor. It created a **self-ramping launcher escalating toward 10
shells/sec** and a second `BloomEffect`. The bench was never parked, and its
`FireworkLauncher` **LocalScript sat ENABLED in `StarterPlayerScripts` of the published
place** — auto-running for every player on join.

Every subsequent measurement went through it. A Samsung A13 read as "only usable at
graphics quality 1 of 10". The *world* got diagnosed: draw-call bound, too much
foliage, the foliage sign-off recorded as untrustworthy. **A new program item was
opened and it briefly reordered the whole roadmap.**

The owner found it in five words — *"should we turn off the fireworks for now?"* With
the bench disabled the same device ran at **quality 5, and on Automatic**. The foliage
audit that started it all came back **clean**: 3,580 MeshParts, 0 at Precise, 96
shadow casters.

## The rules that follow

1. **Park a bench the instant its reading is taken.** Not at end of session, not
   "before we ship". The measurement is the whole lifetime of the harness.
2. **`StarterPlayerScripts` is the dangerous parent.** It auto-runs on every client,
   replicates with the place, and is invisible from the server — nothing in a
   server-side check will find it. Anything put there for a test must be disabled AND
   renamed/moved the same session.
3. **A perf harness in the published place is a shipped feature.** Publishing is what
   made this reach a real device; the bench went out to everyone who opened the
   experience.
4. **Suspect the harness before the content.** The content was reviewed, tested and
   signed off. The harness was written in one pass to be thrown away — which is exactly
   why it is the more likely defect, and exactly why nobody re-reads it.
5. **Do not let a single contaminated reading rewrite the roadmap.** One device, one
   number, no second source, and it reordered a program. Corroborate before
   re-planning.

Related: [[friends-family-baseline]] item 2.5 carries the full incident; [[fireworks]]
holds the perf rules and the clean measured floor; [[visible-is-not-pixels]] is the
same family of error.
