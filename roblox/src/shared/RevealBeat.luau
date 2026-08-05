--!strict
-- THE REVEAL BEAT. What happens after the drum comes fully to rest, and when.
--
-- THE RULE THIS SERVES (owner, 2026-08-04): the drum is authoritative, and must always be fully at
-- rest before the world throw is reflected anywhere else. Everything here is measured from
-- `drumRest` — nothing in this module may ever be used to show something earlier.
--
-- WHY A BEAT AT ALL. The glyph in the ring and the new tape tile used to appear in the same frame,
-- so three things arrived at one instant and the smallest lost — which is why the glyph read as
-- missing even while it was rendering. And its lifetime was leftover time, not a designed span:
-- 3.03s, 1.81s and 4.15s across three consecutive measured rounds, ending abruptly with no fade
-- whenever the next round happened to open.
--
-- TWO FILES MUST AGREE about these numbers — main.client.luau schedules the beat, HudController
-- animates the fade — so they live here rather than as a literal in each. No Roblox globals; this
-- runs under Lune like everything else in src/shared.
local RevealBeat = {}

-- How long the glyph sits before it begins to go. The owner asked for "a few seconds"; this is the
-- first thing to tune at a Studio gate, which is why it is named rather than inline.
RevealBeat.HOLD_SECONDS = 2

-- A real fade, not a Visible toggle. A toggle is what it did before, and part of why it read as a
-- flicker rather than a reveal.
RevealBeat.FADE_SECONDS = 0.4

-- When the tape tile lands, measured from drumRest. AFTER the glyph is fully gone — the tape is the
-- round's RECORD, and a record arriving with the announcement is what buried the announcement.
RevealBeat.TAPE_DELAY_SECONDS = RevealBeat.HOLD_SECONDS + RevealBeat.FADE_SECONDS

-- How much time exists after the drum stops. PROVISIONAL — THIS NUMBER IS NOT MEASURED, and the
-- previous comment here claiming it was ("the drum rests ~3.2s into the gap") was measuring the
-- wrong event: every instrumented round released through main.client's reveal-safety FALLBACK, not
-- through `drumRest`, because the fallback was armed from RevealResult arriving and beat the drum.
-- The 3.2s was the fallback's own lead, and it says nothing about where the drum actually stops.
--
-- WHAT IS ACTUALLY KNOWN:
--   * The nominal arithmetic. The strike is scheduled at ACTIVE-end + TallySec, and the drum rests
--     DrumStep.SETTLE_SECONDS (3.45s) after it — so 5.45s into a TALLY(2) + REVEAL(5) = 7s gap,
--     leaving a nominal runway of 1.55s.
--   * The client's phase transitions lag the nominal boundaries. Measured at revealSeconds: 3,
--     TALLY was seen at 8.13s and ACTIVE at 14.34s — a 6.21s observed gap against a 5s nominal one,
--     so the gap the client actually experiences runs on the order of a second longer than nominal.
--   * The true post-rest runway has NOT been measured, at either reveal length. It cannot be until
--     the fallback stops pre-empting `drumRest`.
--
-- So 1.55s nominal, perhaps ~2.7s once the observed lag is allowed for, against a 3.8s literal that
-- the spec test leans on — the literal may well be too generous, and the beat (2.4s to the tape) may
-- not fit. RE-MEASURE AT THE STUDIO GATE, from `drumRest` to the next ACTIVE, and set this from that
-- reading; if it comes in under TAPE_DELAY_SECONDS the beat itself has to shorten. Left as a literal
-- deliberately: deriving it from the phase durations would only dress the same guess up as a fact.
RevealBeat.RUNWAY_SECONDS = 3.8

return RevealBeat
