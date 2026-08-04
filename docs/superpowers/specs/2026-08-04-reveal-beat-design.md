# The reveal beat — design

**Date:** 2026-08-04
**Supersedes** `2026-08-04-play-hud-round-four-design.md` §2 entirely.
**Gate:** owner's Studio session, 2026-08-04 evening.

---

## §0 The rule this is built on

> **IN EXPERIENCE, THE DRUM IS AUTHORITATIVE, AND SHOULD ALWAYS BE FULLY AT REST BEFORE THE WORLD
> THROW IS REFLECTED ANYWHERE ELSE.** — the owner, 2026-08-04

Everything below follows from that. It is the rule, not an implementation note; anything that reads
the world's throw earlier than `drumRest` is wrong regardless of how good the reason sounds.

**This spec retracts a change made hours earlier.** Round four moved the result splash 0.7s ahead of
`drumRest`, then refined it to a residual-angle trigger firing 0.36–0.51s ahead. Both were wrong
under this rule, and the refinement was wrong in a more interesting way: it was *precisely* correct
about a question that should never have been asked. The lesson is recorded here so it is not
re-derived: **the gap between a round closing and the drum resting is not latency to be optimised.
It is the drum being authoritative.**

---

## §1 What the measurements showed

Three consecutive rounds, instrumented live in Studio (2026-08-04).

**The ring's world-throw glyph is not broken.** Captured mid-reveal: 26.24px square, fully opaque,
cream core over a white outline, on a 32px opaque near-black disc. It renders, at the right size,
in the right place.

**What it lacks is a moment of its own.** It appears in the *same frame* as the tape tile — and,
before this spec, the splash as well. Three things arrive at one instant and the smallest loses.
That is why it reads as absent.

**And its lifetime is leftover time, not a designed beat:**

| round | glyph visible for |
| --- | --- |
| 1 | 3.03s |
| 2 | 1.81s |
| 3 | 4.15s |

It ends abruptly when the next round opens — no fade, no consistency. The variance is the tell: it
lives from `drumRest` until `ACTIVE` reopens, so its length is whatever the round happens to leave.

**The budget is the constraint.** The drum rests roughly 3.2s into a ~6.2s gap between rounds,
leaving 1.8–4.2s. The sequence below needs about 2.4s of that, and sometimes there was not 2.4s.

---

## §2 Lengthen REVEAL

`server/src/index.ts` — `revealSeconds: 3` → **5**.

The round goes 25s → 27s (ACTIVE 20 + TALLY 2 + REVEAL 5). The owner's call, against the
alternatives of compressing the ceremony or moving the strike earlier: the drum's suspense is the
thing worth protecting, and a beat that only sometimes has room is the defect being fixed, not a
constraint to design around.

This is a server change and it reaches the PWA too — the PWA has no drum, so it simply gets a
2-second-longer reveal. Nothing there reads the phase length as a constant.

After the change the drum rests with ~4.0s of runway instead of ~2.0–3.0s.

---

## §3 The sequence

Everything below is measured from the instant the drum is **fully at rest** (`drumRest`).

| t | what happens |
| --- | --- |
| 0.0 | the world-throw glyph appears in the ring; the result splash appears |
| 0.0 – 2.0 | the glyph holds (`GLYPH_HOLD`) |
| 2.0 – 2.4 | the glyph fades (`GLYPH_FADE`) |
| 2.4 | **then** the tape tile lands, carrying the round's outcome badge |

**The splash and the glyph land together, deliberately.** They say different things — the splash
names *your* result, the glyph names *the world's* throw — and the owner's ruling places both at
rest. The tape is the third beat because it is the *record*, and a record arriving with the
announcement is what made the announcement invisible.

**The ring returns to being a clock** when `ACTIVE` reopens, as now.

---

## §4 When the time runs out anyway

The runway is ~4.0s after §2, and the sequence needs 2.4s. But the margin is not guaranteed — a
slow `RevealTheater`, a stalled drum, or a client hitch can eat it.

**If `ACTIVE` reopens mid-sequence, the sequence collapses immediately and in order:** the glyph
clears, the tape tile lands at once, and the ring resumes the countdown. A half-finished beat must
never leave the tape without its tile or the ring without its clock. **The tape tile is never
dropped** — it is the round's permanent record, and losing it to a timing edge would leave a gap in
the tape that no later round repairs.

---

## §5 What is deleted

Round four's early-splash machinery goes, entirely — not disabled, deleted:

- `DrumStep.SPLASH_RESIDUAL_RADIANS`
- `DrumStep.glideResidual`
- the `drumSettling` cue, its latch (`settlingFired`) and both its reset points
- `main.client.luau`'s `drumSettling` / `splashDone` flags and the split gate
- their tests

The splash returns to firing from the drum-rest gate, where it was before round four.

`DrumStep.KICK_OMEGA` **stays** — moving it out of the client was a genuine improvement (a stage
attribute could retune the drum with no test able to see it) and it is unrelated to the retraction.
Likewise the corrected Hermite characterisation in `DrumStep`'s header: that comment was wrong
before round four and is right now.

---

## §6 Where the timing lives

The three durations — `GLYPH_HOLD`, `GLYPH_FADE`, and the resulting tape delay — belong in a pure
`src/shared` module so they are Lune-testable and so the two files that must agree about them
cannot drift. `main.client.luau` owns *when* (it owns the round); `HudController` owns *how it
looks* (it owns pixels).

The fade is a real fade — the glyph is two `ImageLabel`s and both must reach full transparency —
not a `Visible` toggle. A toggle is what it does today, and part of why it reads as a flicker
rather than a reveal.

---

## §7 Risks

- **The splash and the glyph still share an instant.** Two is not three, and they say different
  things, but if the glyph is still lost at the gate the splash is the next thing to move — not the
  drum, and not earlier.
- **The collapse path in §4 is the one no gate can see** and the one that only appears under a
  slow reveal. It must be reasoned through by reading, and the tape tile must survive it.
- **`revealSeconds` reaches the PWA.** Verify nothing there assumes 3.
- **The 2s hold is a guess** — the owner asked for "a few seconds" and the budget allows ~4.0s.
  It is the first thing to tune at the gate, which is why it is a named constant in a shared module
  rather than a literal in a controller.
