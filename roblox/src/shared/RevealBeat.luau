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

-- THE BEAT DELIBERATELY OUTLIVES THE ROUND BOUNDARY (owner's ruling, 2026-08-04, confirmed in
-- Studio). The drum comes to rest with roughly a second left before the next round opens, so a
-- beat that had to fit between rest and ACTIVE was cut off after well under a second — the owner
-- saw the glyph appear at the right moment and be replaced by the fresh countdown almost at once.
--
-- Rather than shortening the beat to fit, or lengthening the round to make room, the beat is now
-- allowed to run ACROSS the boundary: the glyph holds and fades over the first few seconds of the
-- new round, and the ring hands back to a countdown already part-way down. main.client no longer
-- collapses the beat when ACTIVE arrives.
--
-- WHAT STILL BOUNDS IT: the beat must finish comfortably before the NEXT reveal, or two beats
-- would overlap and the older one's tape tile would be released by the newer one's arrival rather
-- than by its own schedule. Drum rests are about a round apart, so the ceiling is generous — but
-- it is a real ceiling and the test below pins it.
RevealBeat.MAX_SAFE_SECONDS = 6

return RevealBeat
