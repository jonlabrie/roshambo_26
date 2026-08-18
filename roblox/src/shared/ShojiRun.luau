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

-- Whether a bay's RESOLVED state gives it a screen to slide. The gate reads the `BayState`
-- attribute StructureOps.applyBays writes as it applies each bay -- NOT whether the bay owns a
-- `Shoji` variant, which every bay of a stock prefab does. applyBays hides a variant by setting
-- Transparency = 1, never by removing it, so a bay showing its Solid panel still answers
-- FindFirstChild("Shoji"); reading membership that way put a "Slide open" prompt on nearly every
-- wall in the game and let the server slide an invisible, non-colliding leaf behind it (2026-08-18
-- final review, critical). Anything that is not exactly the string "shoji" -- a bay applyBays
-- skipped and so never stamped, a stale value, junk -- is not slidable, because a prompt that
-- should not exist is worse than a prompt that is briefly missing.
--
-- This gates PROMPTS and HOLD ACCEPTANCE only. Run MEMBERSHIP and ordinals stay "the bays that
-- carry a Shoji variant" (see ShojiRun.ordinalOf and StructureOps.applyShoji): that is what the
-- prefab's grooves were authored against and what a persisted `shojiOpen` index means, so toggling
-- one bay between solid and shoji must not renumber a player's saved screen positions.
function ShojiRun.isSlidable(bayState: any): boolean
    return bayState == "shoji"
end

-- A raw `Bay_<side>_<n>` number resolved against the run it belongs to. `bayNumbers` is that
-- side's shoji-bearing bay numbers in ascending order; the answer is the position within it, or
-- nil for a bay that is not part of the run at all.
--
-- The SlideShoji wire carries the RAW number, not this ordinal (2026-08-18 final review): the
-- client can only count the bays whose `Shoji` child has already replicated to it, while the
-- server sees them all, so in the window after a live rebuild the client's ordinal n named the
-- server's ordinal n+1 and a press slid the neighbouring screen. Raw numbers are the one naming
-- both sides agree on unconditionally; the mapping to an ordinal happens HERE, on the server,
-- which is the side that can always see the whole wall.
function ShojiRun.ordinalOf(bayNumbers: { number }, raw: any): number?
    if typeof(raw) ~= "number" or raw ~= raw or raw % 1 ~= 0 or raw < 1 then
        return nil
    end
    for ordinal, n in bayNumbers do
        if n == raw then
            return ordinal
        end
    end
    return nil
end

-- The precision a travel is PERSISTED at. `shojiOpen` shares one 4096-byte loadout document with
-- everything else a teahouse remembers, and a rejected loadout fails the WHOLE write, not just the
-- shoji part of it -- so a wall of full-float travels ("0.7333333333333333") is a real risk to
-- every other saved setting. Three decimals is 6 millistuds of a 6-stud bay: far below what anyone
-- can see, and it caps each entry at eight characters or so. Junk reads as closed, same posture as
-- ShojiRun.clamp, for the same reason.
function ShojiRun.quantize(open: number): number
    if typeof(open) ~= "number" or open ~= open or open == math.huge or open == -math.huge then
        return 0
    end
    return math.floor(open * 1000 + 0.5) / 1000
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

export type Vec = { x: number, y: number, z: number }

-- Which axis of the STRUCTURE's own LOCAL frame a side's shoji screens slide along: front/back
-- bays step along local X, left/right along local Z. Plain {x,y,z}, not a Vector3 -- a Roblox
-- global absent under Lune, same reason LaunchSites.Vec is a plain table -- so callers convert at
-- the Roblox boundary (Vector3.new(axis.x, axis.y, axis.z)). This is the ONE place this rule
-- lives: StructureOps.luau (server) and ShojiController.client.luau both read it here rather than
-- keeping their own copy, because a drift between them would push a screen off its own wall
-- plane on one side of the wire but not the other.
local RUN_AXIS_LOCAL: { [string]: Vec } = {
    front = { x = 1, y = 0, z = 0 },
    back = { x = 1, y = 0, z = 0 },
    left = { x = 0, y = 0, z = 1 },
    right = { x = 0, y = 0, z = 1 },
}

-- nil for an unrecognised side -- callers already have their own posture for that (a warn-and-
-- skip on the server, a silent skip on the client, same as an ordinary Shoji-less bay).
function ShojiRun.runAxis(side: string): Vec?
    return RUN_AXIS_LOCAL[side]
end

-- A stored side map (a list of travels, one per bay) resolved against the run actually built.
-- Extra entries are dropped and missing ones read as closed, so a house that changed size does
-- not hang a screen off the end of a shorter wall. `stored` itself may be junk -- a stray boolean
-- or number left by an older document shape, not a list at all -- and that reads as entirely
-- absent (every screen closed), the same as `nil`, rather than indexing into it and erroring:
-- junk in one slot is already closed by `clamp`, so junk in the WHOLE slot should read no
-- differently.
function ShojiRun.resolve(stored: any, count: number): { number }
    local list = if typeof(stored) == "table" then stored else nil
    local out = table.create(count, 0)
    for i = 1, count do
        local v = if list ~= nil then list[i] else nil
        out[i] = ShojiRun.clamp(i, count, v)
    end
    return out
end

return ShojiRun
