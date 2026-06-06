--!strict
-- Pursuit math for the Three Fates (spec §6.1). Pure: positions are {x,y,z}
-- tables; the client controller converts to/from Vector3. No guaranteed catch:
-- intensity escalates and plateaus; contact (or acceptance) ends the flight.
local DoomEscalation = {}

local STAGE_SECONDS = 5
local FAST_CATCH_SPEED = 1 -- studs/sec: "standing still"
local FAST_CATCH_AFTER = 4

DoomEscalation.CONFIG = {
    fateBoulder = { plateau = 6, baseSpawnSec = 2.5, minSpawnSec = 0.6, baseSpeed = 14, speedPerStage = 3 },
    fatePaper = { plateau = 40, baseSpawnSec = 0.8, minSpawnSec = 0.15, baseSpeed = 16, speedPerStage = 2 },
    fateShears = {
        plateau = 8,
        baseSpawnSec = 2.0,
        minSpawnSec = 0.5,
        baseSpeed = 0,
        speedPerStage = 0,
        lungeRange = 14,
        lungeSpeed = 28,
    },
}

export type Vec = { x: number, y: number, z: number }

function DoomEscalation.stageAt(elapsedSec: number): number
    return 1 + math.floor(elapsedSec / STAGE_SECONDS)
end

function DoomEscalation.spawnInterval(fateId: string, stage: number): number
    local c = DoomEscalation.CONFIG[fateId]
    return math.max(c.minSpawnSec, c.baseSpawnSec * 0.7 ^ (stage - 1))
end

function DoomEscalation.entityCap(fateId: string, stage: number): number
    local c = DoomEscalation.CONFIG[fateId]
    return math.min(c.plateau, 2 * stage)
end

function DoomEscalation.speed(fateId: string, stage: number): number
    local c = DoomEscalation.CONFIG[fateId]
    return c.baseSpeed + c.speedPerStage * (stage - 1)
end

function DoomEscalation.homingStep(pos: Vec, target: Vec, speed: number, dt: number): Vec
    local dx, dy, dz = target.x - pos.x, target.y - pos.y, target.z - pos.z
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    local stepLen = speed * dt
    if dist <= stepLen or dist == 0 then
        return { x = target.x, y = target.y, z = target.z }
    end
    local s = stepLen / dist
    return { x = pos.x + dx * s, y = pos.y + dy * s, z = pos.z + dz * s }
end

function DoomEscalation.shouldFastCatch(victimSpeed: number, elapsedSec: number): boolean
    return victimSpeed < FAST_CATCH_SPEED and elapsedSec > FAST_CATCH_AFTER
end

return DoomEscalation
