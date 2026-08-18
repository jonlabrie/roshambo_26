--!strict
-- WHERE THE BIRD IS, as a pure function of state, time and a per-player seed. No Roblox service
-- and no randomness at call time: two clients watching the same player must draw the same bird,
-- and Lune must be able to check the curves without a DataModel.
--
-- RETURNS PLAIN {x, y, z} TABLES, NOT Vector3, following DoomEscalation: a pure module names no
-- Roblox type, and the client controller converts at the boundary. That is what lets this file be
-- tested under Lune at all -- Vector3 does not exist there.
--
-- THE GRAMMAR IS VERTICAL DIRECTION (owner, 2026-08-18). Win RISES, safe PERCHES, loss FALLS
-- away. The space above a player's head is the only region never occluded by another avatar, so
-- height is what survives a crowd of fifty on a phone -- colour and detail do not.
local BirdFlight = {}

BirdFlight.DURATION = { WIN = 3.0, SAFE = 2.6, LOSS = 2.0 } :: { [string]: number }

local ORBIT_R = 2.6
local ORBIT_Y = 3.2
local ORBIT_SPEED = 1.1

export type Point = { x: number, y: number, z: number }

local function orbit(t: number, seed: number, radius: number, y: number): Point
    local a = t * ORBIT_SPEED + seed
    return { x = math.cos(a) * radius, y = y + math.sin(a * 1.7) * 0.25, z = math.sin(a) * radius }
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

function BirdFlight.stateAfter(state: string, elapsed: number): string
    local d = BirdFlight.DURATION[state]
    if not d or elapsed > d then
        return "IDLE"
    end
    return state
end

function BirdFlight.offsetFor(state: string, elapsed: number, seed: number): Point
    if state == "WIN" then
        -- RISES, and rising is the whole grammar.
        local k = math.min(1, elapsed / BirdFlight.DURATION.WIN)
        return orbit(elapsed * 2.2, seed, ORBIT_R * (1 + k), ORBIT_Y + k * 5.5)
    elseif state == "SAFE" then
        -- SETTLES AND STAYS. A landed bird is unmistakable, and "nothing changed, you are fine" is
        -- exactly what perching says. Eased so the landing reads rather than snapping.
        local k = math.min(1, elapsed / 1.2)
        local ease = 1 - (1 - k) * (1 - k)
        local perch = { x = 0.9, y = 1.6, z = 0.35 }
        return lerp(orbit(elapsed, seed, ORBIT_R, ORBIT_Y), perch, ease)
    elseif state == "LOSS" then
        -- DARTS OFF AND COMES BACK: the pot was lost, not the companion. Out fast, back slower,
        -- landing exactly on the idle orbit so nothing snaps when the state expires.
        local d = BirdFlight.DURATION.LOSS
        local k = math.min(1, elapsed / d)
        local away = orbit(elapsed, seed, 14, ORBIT_Y + 3)
        local home = orbit(elapsed, seed, ORBIT_R, ORBIT_Y)
        return if k < 0.4 then lerp(home, away, k / 0.4) else lerp(away, home, (k - 0.4) / 0.6)
    end
    return orbit(elapsed, seed, ORBIT_R, ORBIT_Y)
end

return BirdFlight
