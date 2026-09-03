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
    orientation: string, -- "camera" | "velocity": velocity aligns the sprite to each star's
    -- own path, so a streak's bright head LEADS and its tail trails behind (camera-facing
    -- billboards wore the streak upside down on falling stars -- owner, 2026-09-03)
    sizeScale: number, -- multiplier on the spread-derived sprite size (streaks need bulk)
    lightEmission: number, -- the STACKING LAW, not just a glow switch: 1 = fully additive
    -- (overlaps sum without bound -- the shared-halo problem), lower = part-normal blend,
    -- so pileups compress. Dots ~0.7, streaks higher (they overlap less).
    tailSound: { role: string, delay: number, volume: number, duration: number } | false,
    -- a SECOND voice layered after the burst (owner's canyon sizzle over hotaru's final
    -- flicker phase, 2026-09-03) -- role into SOUNDS, delay seconds after the break,
    -- volume as a fraction of SOUND_LEVELS.volume, duration seconds the voice may run
    -- before the engine fades it: THE SOUND OBEYS THE PHASE, not the clip's own length
    -- (owner ruling: "the sizzle clip should only run as long as the final phase").
    -- false = the style has no tail.
    soundRole: string, -- key into SOUNDS (burst roles are variant pools)
    -- RE-POPS (owner, 2026-09-06: hotaru's flicker waves read as re-bursts and "burst 2 is
    -- almost always silent"): fractions of star lifetime where the style visibly re-ignites
    -- -- the transparency square-wave's rising edges -- and a soft report belongs. The
    -- controller plays the phase's own break clip quieter/sharper at each. false = none.
    rePops: { number } | false,
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
        brightness = 2.2,
        spreadAngle = { 360, 360 },
        transparency = { { 0, 0 }, { 0.8, 0.15 }, { 1, 1 } },
        textureRole = "dot",
        soundRole = "burst_peony",
        pointRule = "scatter",
        orientation = "camera",
        sizeScale = 1,
        lightEmission = 0.7,
        tailSound = false,
        rePops = false,
    },
    -- Planar circle of stars, tilted per shell ("tilted" point rule).
    ring = {
        speed = { 34, 42 }, -- tight band: a ring wants even radius
        drag = 2.6,
        lifetime = { 1.4, 1.8 },
        acceleration = { 0, -4, 0 },
        brightness = 2.2,
        spreadAngle = { 360, 4 }, -- fan in the part's plane
        transparency = { { 0, 0 }, { 0.8, 0.15 }, { 1, 1 } },
        textureRole = "dot",
        soundRole = "burst_peony",
        pointRule = "tilted",
        orientation = "camera",
        sizeScale = 1,
        lightEmission = 0.7,
        tailSound = false,
        rePops = false,
    },
    -- Few thick arms, aimed outward-up by the "circle" point rule, falling hard.
    palm = {
        speed = { 26, 34 },
        drag = 1.4,
        -- was {1.8, 2.6}: +0.4s (owner at the yashi audition, 2026-09-05: "yashi streaks
        -- should have a longer life... to really let them rain down") -- the arms arc out,
        -- die back, and visibly FALL before they fade.
        lifetime = { 2.2, 3.0 },
        acceleration = { 0, -22, 0 },
        brightness = 2.2,
        spreadAngle = { 12, 12 }, -- narrow cone per arm
        transparency = { { 0, 0 }, { 0.85, 0.1 }, { 1, 1 } },
        textureRole = "streak",
        soundRole = "burst_peony",
        pointRule = "circle",
        orientation = "velocity",
        sizeScale = 2.2,
        lightEmission = 0.85,
        tailSound = false,
        rePops = false,
    },
    -- A hanging cloud that flickers: the 18-keypoint square-wave transparency.
    strobe = {
        speed = { 8, 16 },
        drag = 3.5,
        lifetime = { 2.2, 3.0 },
        acceleration = { 0, -3, 0 },
        brightness = 3,
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
        orientation = "camera",
        sizeScale = 1,
        lightEmission = 0.7,
        -- The owner's own canyon-echoed sizzle, over the FINAL flicker phase only: the
        -- strobe's square wave reads as 3-4 sequential re-bursts and the last one
        -- shimmers -- that is the phase this voice belongs to (~70% of star lifetime).
        tailSound = { role = "tail_strobe", delay = 1.75, volume = 0.35, duration = 1.6 },
        -- The square wave's rising edges (see transparency above: on-phases begin at 0,
        -- 0.22, 0.46, 0.74 of life) -- the first edge is the break itself.
        rePops = { 0.22, 0.46, 0.74 },
    },
    -- The golden crown: long, heavy, drooping to the water.
    kamuro = {
        speed = { 24, 32 },
        drag = 1.8,
        lifetime = { 3.2, 4.2 },
        acceleration = { 0, -14, 0 },
        brightness = 2,
        spreadAngle = { 360, 360 },
        transparency = { { 0, 0 }, { 0.9, 0.2 }, { 1, 1 } },
        textureRole = "streak",
        soundRole = "burst_kamuro",
        pointRule = "single",
        orientation = "velocity",
        sizeScale = 3.6, -- 2.4 + 50% (owner, 2026-09-06: "kamuro streaks that are 50% larger")
        lightEmission = 0.85,
        tailSound = false,
        rePops = false,
    },
} :: { [string]: Style }

-- Role tables (built-in stand-ins until the owner's uploads clear, per spec §4/§8).
BurstStyles.TEXTURES = {
    -- Owner uploads 2026-09-02 (sources: tools/textures/firework_dot.png / firework_streak.png).
    dot = "rbxassetid://87559558731370",
    streak = "rbxassetid://136219621015067",
    -- Salute flares (2026-09-06, tools/textures/make_salute_flares.py): purpose-made burst
    -- art -- salutes are a FIRST-CLASS effect (owner ruling; crossed streak sprites read as
    -- a line whenever the random rotations aligned). Four silhouettes, star baked into the
    -- texture: a 4-point, b 6-point, c 5-point, d 8-spike pop.
    flare_a = "rbxassetid://97945892165096",
    flare_b = "rbxassetid://106113269280235",
    flare_c = "rbxassetid://107807952502084",
    flare_d = "rbxassetid://82438585464749",
}

-- The shuffle deck for salute flashes: one seeded draw per shot in the controller.
BurstStyles.SALUTE_FLARES = {
    BurstStyles.TEXTURES.flare_a,
    BurstStyles.TEXTURES.flare_b,
    BurstStyles.TEXTURES.flare_c,
    BurstStyles.TEXTURES.flare_d,
}
-- How LOUD and how FAR. Fireworks are shared spectacle, the opposite of the familiars'
-- deliberately intimate 9-34 rolloff: full volume out to a plateau, audible across the
-- canyon. Never left to Sound defaults again (Volume 0.5 / RollOffMin 10 made the whole
-- show a whisper from FallsLanding -- owner, 2026-09-03: "they don't seem very loud").
-- Per-clip head trims, seconds skipped at play time via Sound.TimePosition -- a clip whose cut
-- carries pre-roll lands its transient LATE, which physics-delay masked at range and point-blank
-- deck launches exposed (owner, 2026-09-05: "a pretty significant delay between visual launch
-- and the tube thump"). Measured in Studio by sampling PlaybackLoudness: launch-deck-2's first
-- audible at 134ms, peak at 201ms. Trimming here beats re-uploading: one tunable number.
-- 0.12 still lagged (owner, 2026-09-06): the envelope trimmed at 0.12 peaks 68ms after Play,
-- stacked on frame-hop dispatch. 0.15 keeps ~35ms of rise so the transient still reads as a
-- thump, not a click.
BurstStyles.SOUND_TRIMS = {
    -- Launch thumps, each trimmed to peak-minus-~35ms (measured from the source WAVs; the
    -- offline envelope agreed with the in-engine PlaybackLoudness curve within 3ms).
    ["rbxassetid://87713703495045"] = 0.15, -- launch-deck-2: peak at 185ms
    ["rbxassetid://122319288610707"] = 0.14, -- launch-deck-1: peak at 175ms
    ["rbxassetid://92892667329683"] = 0.135, -- launch-deck-3: peak at 170ms
    ["rbxassetid://79843927797938"] = 0.16, -- launch-deck-m3: peak at 195ms (aligned to deck-4)
    -- deck-4 stays on the peak-minus-35ms rule. A deeper 0.19 was tried for the perceived
    -- lag and REVERTED (owner, 2026-09-06: "far less satisfying" -- the bass swell IS the
    -- grunt); the real intermittent lag was fire-time SoundId binding, fixed structurally
    -- in the controller (dedicated preassigned launch voices).
    ["rbxassetid://77117688726913"] = 0.16, -- launch-deck-4: peak at 195ms in the raw clip
} :: { [string]: number }

BurstStyles.SOUND_LEVELS = {
    -- Turned up 2026-09-05 (owner: inaudible at a teahouse from the bridge): volume 2 -> 2.4,
    -- reach 400 -> 900 so the far decks hear the show, min 45 -> 60 for a fuller plateau near.
    volume = 2.4,
    rolloffMin = 60, -- studs of full volume around the shell
    rolloffMax = 900, -- audible reach; keep FireworkDirector.AUDIBLE_STUDS aligned with this
    -- Light is instant; sound is not. 1 stud = 1 foot and sound runs ~1125 ft/s, so every
    -- phase sound arrives distance/1125 late for THIS listener (owner, 2026-09-03: "the
    -- sound from an aerial burst should be slightly delayed"). ~0.17s from FallsLanding
    -- to the bridge racks.
    speedOfSound = 1125,
}

-- THE BONUS SHELL (owner, 2026-09-04): occasionally a shell is simply BIGGER -- it
-- climbs much higher, its stars live longer, and it speaks with the heavyweight boom.
-- Seeded per shell, so every client sees the same lucky ones; rolls only on
-- mortar-class flights (>= 2s), never hand firecrackers.
BurstStyles.BONUS = {
    chance = 0.08,
    apexScale = 1.6,
    lifeScale = 1.45,
    sound = "rbxassetid://126255239203597", -- boom-parasonya
    minFlight = 2,
}

BurstStyles.SOUNDS = {
    -- Owner uploads 2026-09-03 (sources: Roshambo Reference/sound/fireworks_cuts/).
    -- Each burst role is a VARIANT POOL: the controller picks one per shell from the
    -- seeded rng, so a show is not one clip on repeat. Strobe and kamuro share the
    -- aerial pool as stand-ins until the firecracker-string and glitter-sizzle
    -- recordings land (owner ruling 2026-09-03).
    -- The tube thumps. S/M launches rotate through the pool (seeded per shell, like the
    -- burst pools); an L tube speaks with the heavy voice alone (owner, 2026-09-06:
    -- deck-4 is "heavier/gruntier and much more close range... like from a bigger tube").
    -- Recipes normally omit the report sound and let the controller resolve it here; an
    -- explicit phase `sound` still overrides for a shell with its own launch voice.
    launch = {
        "rbxassetid://122319288610707", -- launch-deck-1
        "rbxassetid://87713703495045", -- launch-deck-2 (the original, owner pick 2026-09-03)
        "rbxassetid://92892667329683", -- launch-deck-3
    },
    launch_heavy = "rbxassetid://77117688726913", -- launch-deck-4: the L tube's grunt
    -- The M tube's voice (owner, 2026-09-06: "sounds a little thin now" next to the L
    -- grunt): launch-deck-3's crack over deck-4's low-passed chest at heavy gain, blended
    -- offline (fireworks_cuts/launch-deck-m3.wav), peaks aligned so the trim rule holds.
    launch_medium = "rbxassetid://79843927797938", -- launch-deck-m3: the M tube's chest
    -- The salute voices (owner uploads 2026-09-06, cut from 390182__eardeer__explosion:
    -- echo-y canyon punch, ZERO pre-roll -- peak 50ms in, no trim needed). The 3.5s cut
    -- keeps the 2.75s slap-back echo: a break's single big boom. The 3s cut rolls off
    -- earlier: the salvo voice, tuned to stack 3-6 deep without going to mud.
    salute_single = "rbxassetid://130448210140184", -- eardeer 3.5s: the always-boom
    salute = "rbxassetid://133126105159507", -- eardeer 3s: the salvo voice
    tail_strobe = "rbxassetid://92069275413514", -- jon-sizzle-c3-canyon-v6: 0.8s sizzle body, vast dark returns, lows shaved
    burst_peony = {
        "rbxassetid://89225206152876", -- burst-aerial-1
        "rbxassetid://91810415393899", -- burst-aerial-2
        "rbxassetid://84490753811521", -- burst-aerial-3
        "rbxassetid://110252668535781", -- burst-aerial-4
        "rbxassetid://108527933513449", -- report-jakub: different recording, city-reverb breath
    },
    burst_strobe = {
        "rbxassetid://89225206152876",
        "rbxassetid://91810415393899",
        "rbxassetid://84490753811521",
        "rbxassetid://110252668535781",
        "rbxassetid://108527933513449", -- report-jakub
    },
    burst_kamuro = {
        "rbxassetid://89225206152876",
        "rbxassetid://91810415393899",
        "rbxassetid://84490753811521",
        "rbxassetid://110252668535781",
        "rbxassetid://108527933513449", -- report-jakub
    },
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
    "orientation",
    "sizeScale",
    "lightEmission",
    "tailSound",
    "soundRole",
    "rePops",
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

-- How long a tail-voice clip is allowed to run past its entry before the slot may be
-- reused. Generous by design: a reused slot teleports, and a still-playing tail sound
-- would jump across the canyon with it.
local TAIL_CLIP_ALLOWANCE = 4.5

function BurstStyles.releaseTail(name: string?): number
    local style = BurstStyles.styleOf(name)
    local tail = style.lifetime[2]
    if style.tailSound then
        tail = math.max(tail, style.tailSound.delay + TAIL_CLIP_ALLOWANCE)
    end
    return tail
end

return BurstStyles
