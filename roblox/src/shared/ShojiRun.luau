--!strict
-- The arithmetic of a sliding shoji run. Pure — no Roblox globals, no instances — so it runs
-- under Lune and every rule below is tested without a place open.
--
-- A run is one wall's shoji bays, numbered 1..count along the wall. A screen's position is
-- `open`, its travel in BAY-WIDTHS from its own bay: 0 is home, +1 is parked over the next bay
-- up the run, -2 is two bays down it.
--
-- THERE IS NO PER-SCREEN TRAVEL CAP (owner, 2026-08-18). A screen may slide anywhere between
-- the first and last bay positions of its wall, so an entire run can tuck into a single bay and
-- that bay can be any of them. The fullest opening is therefore count-1 bays: the screens have
-- to be somewhere, and this design has no pocket to hide them in.
local ShojiRun = {}

ShojiRun.PITCH = 6.0 -- bay spacing, and so the travel of one full bay-width
ShojiRun.GROOVE_PITCH = 0.20 -- depth between adjacent channels

-- Groove z for bay `index` of a `count`-bay run, relative to the wall's mid-plane. Centred, so
-- a two-bay run straddles the wall and a four-bay run stands 0.30 proud of each face. Every bay
-- gets its OWN groove: that is what lets a whole run stack in one bay without clipping.
function ShojiRun.grooveOffset(index: number, count: number): number
    return (index - (count + 1) / 2) * ShojiRun.GROOVE_PITCH
end

-- Travel in bay-widths -> studs along the wall.
function ShojiRun.displacement(open: number): number
    return open * ShojiRun.PITCH
end

-- Clamp a requested travel to what the run allows: a screen may reach any bay position, and no
-- position beyond the run. Anything that is not a finite number reads as closed, because a
-- screen that refuses to render is worse than one that is shut.
function ShojiRun.clamp(index: number, count: number, open: number?): number
    if typeof(open) ~= "number" or open ~= open or open == math.huge or open == -math.huge then
        return 0
    end
    local lo, hi = 1 - index, count - index
    return math.clamp(open, lo, hi)
end

-- Which way a hold sends a screen. Not a function of position alone: a screen at rest in the
-- LAST bay of a run has no +1 to travel into, and a barely-open screen should keep going the
-- way it was already going rather than reverse under the player's finger.
--   mostly open  -> come home
--   barely open  -> continue the way it is already displaced
--   at rest      -> open toward the far end of the run, or back down it from the last bay
function ShojiRun.directionFrom(index: number, count: number, open: number): number
    if typeof(open) ~= "number" or open ~= open then
        return 1
    end
    if math.abs(open) >= 0.5 then
        return if open > 0 then -1 else 1
    elseif open ~= 0 then
        return if open > 0 then 1 else -1
    end
    return if index < count then 1 else -1
end

-- A stored side map (a list of travels, one per bay) resolved against the run actually built.
-- Extra entries are dropped and missing ones read as closed, so a house that changed size does
-- not hang a screen off the end of a shorter wall.
function ShojiRun.resolve(stored: { number }?, count: number): { number }
    local out = table.create(count, 0)
    for i = 1, count do
        local v = if stored ~= nil then stored[i] else nil
        out[i] = ShojiRun.clamp(i, count, v)
    end
    return out
end

return ShojiRun
