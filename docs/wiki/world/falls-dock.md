---
shelf: world
updated: 2026-08-15
---

# Falls Dock

The falls-pool dock at `W02_DockFall` (x≈−345): a grey-cypress viewing dock over the
falls pool, and a **composed site** — dock + `YukimiDoro` lantern + Kanzan flowering
cherry (`DockHero_1`) + uguisu birdsong + an iris hero clump across the pool, tied
together with their own internal logic. Builder `tools/builders/FallsDock.luau` +
`assets/FallsDock.model.json` (`RoshamboStage.FallsDock`, verified 2026-08-15). It is
also a fireworks launch site (`Site_FallsDock` tag, [[fireworks]]) and carries its own
15-stud garden radius that overrides the care gradient's longitude ([[foliage]]).

## The uguisu (built & signed off 2026-07-28)

A Japanese bush warbler that lives here and nowhere else — first occupant of the
place-only `CanyonWorld.Ambience` folder (emitter `Audio_Dock_Uguisu` + its
`UguisuScheduler` Script, both verified in the place 2026-08-15). Owner verdict:
"sounds and feels completely natural."

- **Perched in the cherry, not on the deck**: emitter at (−338.6, 197.0, −12.0)
  inside the Kanzan canopy — a call off the walking boards reads as a speaker; a bird
  perches. 10.2 studs from dock centre, 6.8 above the deck.
- Clips `Call_1/2/3` = `74571915778017` / `93957494294947` / `133151225815336`
  (uploaded, moderation cleared), vol 0.6, InverseTapered 12–55 — the whole dock sits
  inside the full-volume radius.
- **Bout scheduler** (the owner's design): drifts between active and quiet states of
  a random 10–60 s; while active, a call every 10–20 s, never the same clip twice
  running; ±3% PlaybackSpeed jitter; **a bout opens with a call**. The Script is
  place-only; a backup lives at
  `~/Desktop/Roshambo Reference/sound/UguisuScheduler.server.luau`.
- Water mix: `Audio_W02_DockFall` runs at 0.50 specifically to sit under the bird —
  it is the only water emitter that reaches the dock ([[water-audio]]).

## Gates & decisions

- **The schedule must never key off player arrival** (owner, rejecting a
  step-on-the-dock trigger): "Birds are ephemeral… this bird lives here and you have
  to be close to hear it." If a proximity optimisation is ever needed, keep the
  schedule free-running on wall-clock time and suppress only the playback — a paused
  cycle resumes with a fresh bout, and bouts open with a call, which silently
  recreates the rejected behaviour.
- **The site is composed, not raw material for a rule.** The `YukimiDoro` at
  (−340, 192, −22) was sited on purpose — to be seen across still water. A whole
  siting spec written on the false reading "it was never placed" was binned. Never
  infer that a model at Workspace root is unplaced, and don't re-derive a placement
  law over this site.
- The iris hero clump's first position beside the dock was wrong and the owner moved
  it across the pool (~20 studs): two pink-purple masses at the same depth were doing
  the same job. Same "seen across the water" logic as the yukimi.
- Ambience is auditioned in situ, not solo — the recording's residual forest noise is
  masked by the waterfall (owner: "lost in the sound of the waterfall").

## Raw layer

- birdcall cutter: `~/Desktop/Roshambo Reference/sound/cut_birdcall.py` (bandpass
  700 Hz–6.5 kHz, spectral gate, one common gain across the set)
- dock builder: `roblox/tools/builders/FallsDock.luau`; grey-cypress treatment =
  `Wood` + `CypressWeathered` + Color 216/214/206 (shared with the river-trail
  timber, [[paths]])
