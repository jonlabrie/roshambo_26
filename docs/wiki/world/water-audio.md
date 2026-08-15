---
shelf: world
updated: 2026-08-15
---

# Water Audio

The canyon's water soundscape: 17 looping emitters in the place-only
`CanyonWorld.Water.FallsAudio` (count verified live 2026-08-15), covering the
[[canyon]] watercourse's W## features with four uploaded loop clips. Complete as of
2026-07-29; the dock warbler is separate living sound ([[falls-dock]],
`CanyonWorld.Ambience`).

## As built

Clips (uploaded, looped, −3 dBFS): hidden-waterfall `93790178378734` ·
waterfall_mountain `117739492075862` · waterfall_rocks `81655648960128` ·
babbling_brook `105557446989164`. Assignments (vol / rolloff): `W01_HeroFall` gets
TWO emitters (rocks 0.50 top + mountain 0.60 bottom, 10–70) because the
`FallsLanding` deck sits between lip and pool and the mix should change as you
descend; the big falls (`W02`, `W05`, `W12`, `W13`) carry hidden-waterfall 0.42–0.55
at 12–85; steps/cascades carry rocks 0.30–0.35; the runs carry brook 0.70 at 3–16.
`W02_DockFall` runs 0.50 to sit under the uguisu — the only water emitter reaching
the dock; volume is global to a fall, so if dock and path ever need different levels,
split it two-emitter like `W01`.

Emitter part recipe (all 17 identical): 1×1×1 anchored invisible part, Sound "Loop"
(Looped, Playing, **InverseTapered**), a `StartOffset` attribute applied at startup
by the one-shot `FallsAudio.StaggerFallLoops` Script. Emitters sit **midway between a
fall's lip and its pool** — a real fall reads as one body of sound.

## Rules (learned, do not re-derive)

- `RollOffMode.Inverse` clamps to silence at max distance — an audible hard line.
  **InverseTapered fades to zero**; to shorten reach, cut `RollOffMaxDistance`.
- Copies of one clip must stagger `TimePosition` or they phase-lock. `StartOffset`
  is an attribute on the SOUND, not the part.
- **Drop ÷ horizontal run picks the clip**, not drop alone (W07 is a chute wanting
  brook; W04 is a fall wanting rocks at nearly the same height).
- Coverage is surveyed, not guessed: for each feature, list every emitter within its
  max range from the lip/pool midpoint; hits only at 85–95% of max are audibly
  silent. The 2026-07-29 sweep added W04/W07/W10 emitters and deliberately left W08
  alone (a run emitter 1 stud away already makes the right noise).
- Never match emitter names with a bare `_Run` substring (it misses `OutfallRun_1`
  and deletes `RunCascade`); use `Run_%d+$`.
- Loop building (pure Python, no ffmpeg on this machine): take `loop + fade` seconds
  from the steadiest per-second-RMS window, equal-power crossfade the tail into the
  head (2 s), normalise −3 dBFS. Judge a seam by seam-RMS ÷ file RMS (~1.3–1.4 is
  inaudible for broadband water). Masters in `~/Desktop/Roshambo Reference/`.

## Gates & decisions

- 2026-07-28 owner decision, deliberate deferral: **the runs can't feed the falls** —
  hero falls (21–22 stud drops) are linked by runs far too slight to carry the same
  water (`W09_MidRun` is a single ribbon part). The clip was never the problem; the
  hydrology is. Two directions were named (build the runs up to match — the
  `upcanyonRiverPOC.luau` prototype exists — or accept them as quiet connective
  tissue) and the owner chose to leave it: "a problem I won't solve now." Five
  stand-in run emitters (rocks, 0.22) cover the reaches meanwhile. Tracked with the
  other remainders on [[backlog]].
- babbling_brook stays right for genuinely small water (side channels, garden
  features near the square) — its seam is the tightest of the four (1.06).

## Raw layer

- key commit: `20ac08b` (W## flow-order renames — 86 objects + the four builder
  scripts, so a rebuild cannot resurrect the old names)
- everything else is place-state: the emitters, the stagger Script, the attributes
  ([[place-state]])
