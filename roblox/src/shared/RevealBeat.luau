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
RevealBeat.HOLD_SECONDS = 3

-- A real fade, not a Visible toggle. A toggle is what it did before, and part of why it read as a
-- flicker rather than a reveal.
RevealBeat.FADE_SECONDS = 0.4

-- When the tape tile lands, measured from drumRest. AFTER the glyph is fully gone — the tape is the
-- round's RECORD, and a record arriving with the announcement is what buried the announcement.
RevealBeat.TAPE_DELAY_SECONDS = RevealBeat.HOLD_SECONDS + RevealBeat.FADE_SECONDS

-- THE BEAT MAY OUTLIVE THE ROUND BOUNDARY, AND MUST STILL BE ALLOWED TO (owner's ruling
-- 2026-08-04, re-derived 2026-08-05 when REVEAL grew to 7s).
--
-- The original reason is gone: REVEAL used to be 3s (briefly 5s) against a 6.85s ceremony, so the
-- beat could not possibly fit and ran across the boundary by necessity. At REVEAL 7s it fits —
-- drum rest at DrumStep.SETTLE_SECONDS 3.45, tape at 3.45 + 3.4 = 6.85, OPEN at 7.0.
--
-- BUT THE MARGIN IS 0.15 SECONDS, AND SETTLE_SECONDS IS THE UNSTALLED CHAIN ONLY. When the World
-- Throw is late the drum waits (DrumStep.STALL_MAX_SECONDS), rest happens later than 3.45, and
-- the beat runs past OPEN again. Since stage 3 the throw arrives AFTER the strike rather than ~2s
-- before it, so that is the common case, not the rare one.
--
-- So the tolerance stays, and its reason is now STALL, not a phase too short to hold a ceremony.
-- Anyone re-checking the arithmetic will find the beat fits and may conclude the tolerance is
-- removable: it is not. Removing it reinstates the cut-off glyph on exactly the rounds whose
-- timing is already worst. main.client does not collapse the beat when OPEN arrives.
--
-- WHAT STILL BOUNDS IT: the beat must finish before the NEXT drum rest, or two beats overlap and
-- the older one's tape tile is released by the newer beat's arrival instead of by its own
-- schedule. Rests are exactly one period apart, and the shortest period ever run is the 27s test
-- config — so against a 3.4s beat this static ceiling is generous by a wide margin. It is not
-- derived from the period because this module is pure and never sees one.
RevealBeat.MAX_SAFE_SECONDS = 6

return RevealBeat
