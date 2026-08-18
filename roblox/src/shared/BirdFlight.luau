--!strict
-- WHERE THE BIRD IS, as a pure function of state, time and a per-player seed. No Roblox service
-- and no randomness at call time: two clients watching the same player must draw the same bird,
-- and Lune must be able to check the curves without a DataModel.
--
-- RETURNS PLAIN {x, y, z} TABLES, NOT Vector3, following DoomEscalation: a pure module names no
-- Roblox type, and the client controller converts at the boundary. That is what lets this file be
-- tested under Lune at all -- Vector3 does not exist there.
--
-- THE GRAMMAR IS VERTICAL DIRECTION (owner, 2026-08-18). Win RISES, safe PERCHES, loss SINKS.
-- The space above a player's head is the only region never occluded by another avatar, so height
-- is what survives a crowd of fifty on a phone -- colour and detail do not.
--
-- ⚠ A RESULT IS A STANDING DISPLAY, NOT AN ANIMATION (owner, 2026-08-18). The first version played
-- a 2-3 second flourish and returned to idle, which meant the result was only visible if you
-- happened to be watching that player at the instant the drum rested -- "if you weren't looking at
-- an avatar right as the drum came to a rest, you'll miss it."
--
-- So every state has a short ENTRY animation and then a HELD POSE that persists until the next
-- round replaces it. That is what makes the flock readable as a whole: walk through the arena
-- between rounds and you can see who won and who lost, at a glance, without a HUD.
--
-- Which forces a distinct hold for LOSS. Returning to the idle orbit would make "lost" and "has
-- not thrown yet" identical, so a loss sinks to a low, slow orbit around the knees and stays
-- there -- down, in a grammar where up means won.
local BirdFlight = {}

-- ENTRY is the length of the ANIMATION, not the length of the state: the state itself persists
-- until the next result replaces it.
BirdFlight.ENTRY = { WIN = 2.4, SAFE = 1.4, LOSS = 1.8 } :: { [string]: number }

export type Point = { x: number, y: number, z: number }

-- Each held pose is an orbit: radius, height, angular speed. SAFE is the exception -- it is a
-- fixed perch, because a bird that has landed does not orbit anything.
local HOLD = {
    IDLE = { r = 2.6, y = 3.2, speed = 1.1 },
    WIN = { r = 3.4, y = 8.2, speed = 2.0 },
    LOSS = { r = 2.0, y = 0.9, speed = 0.55 },
}
local PERCH = { x = 0.9, y = 1.6, z = 0.35 }

local function orbit(t: number, seed: number, o: { r: number, y: number, speed: number }): Point
    local a = t * o.speed + seed
    return { x = math.cos(a) * o.r, y = o.y + math.sin(a * 1.7) * 0.25, z = math.sin(a) * o.r }
end

local function lerp(a: Point, b: Point, k: number): Point
    return { x = a.x + (b.x - a.x) * k, y = a.y + (b.y - a.y) * k, z = a.z + (b.z - a.z) * k }
end

-- Exported because both the tests and the controller's LOD want it, and neither should reach for
-- Vector3 to get it.
function BirdFlight.magnitude(p: Point): number
    return math.sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
end

function BirdFlight.distance(a: Point, b: Point): number
    return BirdFlight.magnitude({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z })
end

function BirdFlight.offsetFor(state: string, elapsed: number, seed: number): Point
    local idle = orbit(elapsed, seed, HOLD.IDLE)

    if state == "SAFE" then
        -- SETTLES AND STAYS PUT. A landed bird is unmistakable, and "nothing changed, you are
        -- fine" is exactly what perching says. It stays perched for the whole round.
        local k = math.min(1, elapsed / BirdFlight.ENTRY.SAFE)
        return lerp(idle, PERCH, 1 - (1 - k) * (1 - k))
    elseif state == "WIN" then
        -- SPIRALS UP AND STAYS UP. The entry climbs with a real spiral -- radius and speed both
        -- rising, several revolutions -- and then holds a high, quick orbit for the rest of the
        -- round, visibly above everyone who did not win.
        local k = math.min(1, elapsed / BirdFlight.ENTRY.WIN)
        local high = orbit(elapsed, seed, HOLD.WIN)
        if k >= 1 then
            return high
        end
        local ease = 1 - (1 - k) * (1 - k) * (1 - k)
        local climbing = orbit(elapsed * (1 + 1.6 * k), seed, {
            r = HOLD.IDLE.r + (HOLD.WIN.r - HOLD.IDLE.r) * ease,
            y = HOLD.IDLE.y + (HOLD.WIN.y - HOLD.IDLE.y) * ease,
            speed = HOLD.IDLE.speed,
        })
        return climbing
    elseif state == "LOSS" then
        -- BOLTS, THEN SINKS. Out fast and wide -- the pot was lost, not the companion -- then
        -- back to a low, slow orbit around the knees, where it stays. Low is the whole point: an
        -- idle-orbit return would make "lost" and "has not thrown yet" look identical.
        local low = orbit(elapsed, seed, HOLD.LOSS)
        local k = math.min(1, elapsed / BirdFlight.ENTRY.LOSS)
        if k >= 1 then
            return low
        end
        local away = orbit(elapsed, seed, { r = 15, y = HOLD.IDLE.y + 3.5, speed = 2.4 })
        return if k < 0.35 then lerp(idle, away, k / 0.35) else lerp(away, low, (k - 0.35) / 0.65)
    end
    return idle
end

return BirdFlight
