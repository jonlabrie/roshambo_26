--!strict
-- The fireworks vocabulary's one source of truth: five named burst styles as
-- plain data (speed/drag/lifetime/etc, applied verbatim by the pool's emitters
-- so every shell of a style looks the same), plus the point rules that turn a
-- requested point count into per-part placement/orientation frames, and the
-- role tables the styles' textureRole/soundRole fields resolve through.
local BurstStyles = {}

export type Style = {
    speed: { number }, -- {min, max}
    drag: number,
    lifetime: { number }, -- {min, max}
    acceleration: { number }, -- {x, y, z}
    brightness: number,
    spreadAngle: { number }, -- {x, y} degrees
    transparency: { { number } }, -- keypoints {time, value}
    textureRole: string, -- "dot" | "streak"
    soundRole: string, -- key into SOUNDS
    pointRule: string, -- "scatter" | "circle" | "tilted" | "single"
}

export type Frame = {
    pos: { number }, -- studs relative to the shell's anchor
    rot: { number }, -- XYZ Euler degrees for the point part; identity = emit straight up
}

BurstStyles.MAX_POINTS = 8

BurstStyles.STYLES = {
    -- Today's radial break: the adaa1fe recipe (SpreadAngle 360/drag/fade) becomes
    -- peony's row, so the pool can stop hardcoding it.
    peony = {
        speed = { 20, 60 },
        drag = 2.2,
        lifetime = { 1.2, 2.4 },
        acceleration = { 0, -6, 0 },
        brightness = 3,
        spreadAngle = { 360, 360 },
        transparency = { { 0, 0 }, { 0.8, 0.15 }, { 1, 1 } },
        textureRole = "dot",
        soundRole = "burst_peony",
        pointRule = "scatter",
    },
    -- Planar circle of stars, tilted per shell ("tilted" point rule).
    ring = {
        speed = { 34, 42 }, -- tight band: a ring wants even radius
        drag = 2.6,
        lifetime = { 1.4, 1.8 },
        acceleration = { 0, -4, 0 },
        brightness = 3.5,
        spreadAngle = { 360, 4 }, -- fan in the part's plane
        transparency = { { 0, 0 }, { 0.8, 0.15 }, { 1, 1 } },
        textureRole = "dot",
        soundRole = "burst_peony",
        pointRule = "tilted",
    },
    -- Few thick arms, aimed outward-up by the "circle" point rule, falling hard.
    palm = {
        speed = { 26, 34 },
        drag = 1.4,
        lifetime = { 1.8, 2.6 },
        acceleration = { 0, -22, 0 },
        brightness = 3,
        spreadAngle = { 12, 12 }, -- narrow cone per arm
        transparency = { { 0, 0 }, { 0.85, 0.1 }, { 1, 1 } },
        textureRole = "streak",
        soundRole = "burst_peony",
        pointRule = "circle",
    },
    -- A hanging cloud that flickers: the 18-keypoint square-wave transparency.
    strobe = {
        speed = { 8, 16 },
        drag = 3.5,
        lifetime = { 2.2, 3.0 },
        acceleration = { 0, -3, 0 },
        brightness = 4,
        spreadAngle = { 360, 360 },
        -- NOTE: extended from the brief's 16-keypoint curve, which had 4 rising edges but
        -- only 3 falling edges -- one off/on flicker pair inserted between the {0.74,0} and
        -- {0.88,0} keypoints (times kept strictly increasing) so the curve itself clears
        -- "at least 4 of each", per the controller ruling on this task.
        transparency = {
            { 0, 0 },
            { 0.1, 0 },
            { 0.12, 1 },
            { 0.2, 1 },
            { 0.22, 0 },
            { 0.32, 0 },
            { 0.34, 1 },
            { 0.44, 1 },
            { 0.46, 0 },
            { 0.58, 0 },
            { 0.6, 1 },
            { 0.72, 1 },
            { 0.74, 0 },
            { 0.78, 1 },
            { 0.8, 0 },
            { 0.88, 0 },
            { 0.9, 1 },
            { 1, 1 },
        },
        textureRole = "dot",
        soundRole = "burst_strobe",
        pointRule = "scatter",
    },
    -- The golden crown: long, heavy, drooping to the water.
    kamuro = {
        speed = { 24, 32 },
        drag = 1.8,
        lifetime = { 3.2, 4.2 },
        acceleration = { 0, -14, 0 },
        brightness = 3,
        spreadAngle = { 360, 360 },
        transparency = { { 0, 0 }, { 0.9, 0.2 }, { 1, 1 } },
        textureRole = "streak",
        soundRole = "burst_kamuro",
        pointRule = "single",
    },
} :: { [string]: Style }

-- Role tables (built-in stand-ins until the owner's uploads clear, per spec §4/§8).
BurstStyles.TEXTURES = {
    dot = "rbxasset://textures/particles/sparkles_main.dds",
    streak = "rbxasset://textures/particles/sparkles_main.dds",
}
BurstStyles.SOUNDS = {
    burst_peony = "rbxasset://sounds/impact_explosion_03.mp3",
    burst_strobe = "rbxasset://sounds/impact_explosion_03.mp3",
    burst_kamuro = "rbxasset://sounds/impact_explosion_03.mp3",
    report = "rbxasset://sounds/collide.wav",
    ascent = "rbxasset://sounds/swoosh.wav",
}

-- Exactly the Style field names above -- the completeness contract the controller
-- applies (every property, every style, every shell) and the spec test enforces.
BurstStyles.APPLIED = {
    "speed",
    "drag",
    "lifetime",
    "acceleration",
    "brightness",
    "spreadAngle",
    "transparency",
    "textureRole",
    "soundRole",
    "pointRule",
}

function BurstStyles.styleOf(name: string?): Style
    if name == nil then
        return BurstStyles.STYLES.peony
    end
    return BurstStyles.STYLES[name] or BurstStyles.STYLES.peony
end

-- Point rules. All pure, all consuming `rand` only (deterministic under a fixed
-- sequence, per the spec test) and clamping the requested point count to MAX_POINTS.
--
-- "circle" (palm) tilt encoding: an arm at outward XZ angle `angle` (degrees, measured
-- from +X toward +Z) wants its part's local +Y axis tipped exactly 35 degrees off
-- vertical, toward that arm's outward direction (cos(angle), 0, sin(angle)). Using an
-- XYZ Euler triple (rx, ry, rz) applied as CFrame.fromEulerAnglesXYZ -- rotate about X,
-- then Y, then Z, i.e. v' = RotX(rx) * RotY(ry) * RotZ(rz) * v -- with ry = 0 held fixed
-- (so the arm-to-arm difference lands on rx/rz, which is what the spec test inspects),
-- solving RotX(rx) * RotZ(rz) * (0,1,0) = (sin(35)*cos(angle), cos(35), sin(35)*sin(angle))
-- gives the closed form below (rz from the X-component, rx from the Y/Z components); the
-- two trig identities used to check it (cos(rx)^2+sin(rx)^2, and cos(35)^2+sin(35)^2=1)
-- cancel out to confirm it holds for every angle.
local CIRCLE_TILT_RAD = math.rad(35)
local CIRCLE_TILT_SIN = math.sin(CIRCLE_TILT_RAD)
local CIRCLE_TILT_COS = math.cos(CIRCLE_TILT_RAD)

local POINT_RULES: { [string]: (n: number, scatter: number, rand: () -> number) -> { Frame } } = {
    scatter = function(n, scatter, rand)
        local frames = {}
        for i = 1, n do
            frames[i] = {
                pos = {
                    (rand() * 2 - 1) * scatter,
                    (rand() * 2 - 1) * scatter * 0.6,
                    (rand() * 2 - 1) * scatter,
                },
                rot = { 0, 0, 0 },
            }
        end
        return frames
    end,

    tilted = function(_n, _scatter, rand)
        return {
            {
                pos = { 0, 0, 0 },
                rot = { rand() * 60 - 30, rand() * 360, rand() * 60 - 30 },
            },
        }
    end,

    circle = function(n, scatter, rand)
        local radius = math.max(scatter, 2)
        local frames = {}
        for i = 1, n do
            local angleDeg = (i - 1) / n * 360 + rand() * 20
            local angleRad = math.rad(angleDeg)
            local cosA, sinA = math.cos(angleRad), math.sin(angleRad)
            local rx = math.deg(math.atan2(CIRCLE_TILT_SIN * sinA, CIRCLE_TILT_COS))
            local rz = -math.deg(math.asin(CIRCLE_TILT_SIN * cosA))
            frames[i] = {
                pos = { radius * cosA, 0, radius * sinA },
                rot = { rx, 0, rz },
            }
        end
        return frames
    end,

    single = function(_n, _scatter, _rand)
        return {
            { pos = { 0, 0, 0 }, rot = { 0, 0, 0 } },
        }
    end,
}

function BurstStyles.pointFrames(
    name: string?,
    points: number,
    scatter: number,
    rand: () -> number
): { Frame }
    local style = BurstStyles.styleOf(name)
    local n = math.clamp(points, 1, BurstStyles.MAX_POINTS)
    local rule = POINT_RULES[style.pointRule] or POINT_RULES.scatter
    return rule(n, scatter, rand)
end

function BurstStyles.releaseTail(name: string?): number
    return BurstStyles.styleOf(name).lifetime[2]
end

return BurstStyles
