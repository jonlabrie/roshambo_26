--!strict
-- The fireworks proving range: five mortar racks on the suspension bridge deck
-- (ProvingPlan.RACKS names them Rack_A..Rack_E) and a FiringPost at FallsLanding,
-- ~190 studs west and 30 above — the owner opens the panel there and judges the
-- bursts breaking over the bridge at roughly their own eye level (owner's siting,
-- 2026-09-01, superseding the spec's one-yard-at-FallsLanding shape). NO Tags
-- anywhere here — racks stand in a world with real FireworkLaunchSites and must
-- never be mistaken for one; the server fires by looking up a rack's Position.
--
-- Structured like FallsDock: baked placement constants (PROVISIONAL until the
-- two-marker survey bakes them), pure geometry, then a rotate-about-origin pass.
-- TWO origins, because the rack line and the firing post live on opposite sides
-- of the canyon and are surveyed independently.
--
-- Tube bores are the owner's 2026-09-01 ruling: 2", 4" and 6" shells for now
-- (yonshakudama noted for the future). 1 stud = 1 foot, and real display mortars
-- run ~4-5:1 length-to-bore, which is what these dimensions encode.
local Spec = require("./Spec")
local ProvingPlan = require("../../src/shared/ProvingPlan")

local ProvingGround = {}

-- ===== baked placement (PROVISIONAL: baked from the marker survey) =====
-- Rack line: center of the suspension bridge deck (deck runs along world Z).
ProvingGround.RACK_ORIGIN = { -246, 222, 0 } -- PROVISIONAL: baked from ProvingRackMarker survey
ProvingGround.RACK_YAW_DEG = 90 -- PROVISIONAL: local X (rack line) -> world Z, plaques (+Z) face west
-- Firing post: FallsLanding.
ProvingGround.POST_ORIGIN = { -432, 252.4, -26 } -- PROVISIONAL: baked from ProvingPostMarker survey
ProvingGround.POST_YAW_DEG = 0 -- PROVISIONAL: baked from ProvingPostMarker survey

-- ===== dimensions =====
-- Racks along local X, 12 studs apart. ProvingPlan.RACKS pairs with offsets by index.
local RACK_X_OFFSETS = { -24, -12, 0, 12, 24 }
assert(
    #RACK_X_OFFSETS == #ProvingPlan.RACKS,
    `ProvingGround has {#RACK_X_OFFSETS} rack offsets but ProvingPlan names {#ProvingPlan.RACKS} racks`
)

local BASE_SIZE = { 3, 0.6, 3 } -- timber base block
-- Mortar tubes at real proportions (cylinder Size is {length, dia, dia}; length -> world-up
-- via CYL_VERTICAL). Rack_X IS the 6" tube — the server fires from its Position — with the
-- 4" and 2" tubes standing beside it on the shared base.
local TUBE6_SIZE = { 2.5, 0.5, 0.5 } -- 6" bore, 2.5 ft — the class the seed drafts imply
local TUBE4_SIZE = { 1.5, 1 / 3, 1 / 3 } -- 4" bore, 1.5 ft
local TUBE2_SIZE = { 0.85, 1 / 6, 1 / 6 } -- 2" bore, 10 in
local TUBE6_X, TUBE4_X, TUBE2_X = -0.8, 0.1, 0.75 -- spread across the base, local X
-- Plaque sized to read from the FallsLanding sightline (~190 studs); it STANDS ON the
-- base's west edge rather than floating at tube height (the final review's float note).
local PLAQUE_SIZE = { 2, 2, 0.15 }
local POST_SIZE = { 1.2, 0.6, 1.2 }

-- Grey-cypress timber treatment (216/214/206) — the base and plaque wear it.
local TIMBER_GREY = { 0.847, 0.839, 0.808 }
local TUBE_COLOR = { 0.20, 0.20, 0.22 }
local POST_COLOR = { 0.55, 0.55, 0.52 }
local INK = { 0.15, 0.13, 0.11 }

-- Local ground datum is y = 0 (each origin's y carries the surveyed ground height).
local BASE_Y = BASE_SIZE[2] / 2
local function tubeY(size: { number }): number
    return BASE_SIZE[2] + size[1] / 2
end
local PLAQUE_Y = BASE_SIZE[2] + PLAQUE_SIZE[2] / 2
-- Against the base's +Z face, flush.
local PLAQUE_Z = BASE_SIZE[3] / 2 + PLAQUE_SIZE[3] / 2

local POST_Y = POST_SIZE[2] / 2 -- base on the ground datum

-- ===== the plaque letter — Machiya's `kanjiLabel` canvas recipe (tools/builders/Machiya.luau,
-- ~lines 37-104), copied rather than shared: SizingMode "PixelsPerStud" (the default FixedSize
-- IGNORES PixelsPerStud and renders specks), a SMALL canvas with a fixed TextSize — TextScaled
-- is unreliable and TextSize caps near 100px, so big lettering always wants a small canvas, not
-- a big canvas with big text.
local PLAQUE_PPS = 48
local PLAQUE_TEXT_SIZE = 90

local function plaqueFace(letter: string): Spec.PartSpec
    return {
        name = "Face",
        className = "SurfaceGui",
        properties = {
            -- Back = +Z outward normal; with RACK_YAW_DEG aiming local +Z at FallsLanding,
            -- this is the face the owner reads across the canyon.
            Face = "Back",
            SizingMode = "PixelsPerStud",
            PixelsPerStud = PLAQUE_PPS,
            AlwaysOnTop = false,
            ZIndexBehavior = "Sibling",
        },
        children = {
            {
                name = "Letter",
                className = "TextLabel",
                properties = {
                    Position = { UDim2 = { { 0, 0 }, { 0, 0 } } },
                    Size = { UDim2 = { { 1, 0 }, { 1, 0 } } },
                    BackgroundTransparency = 1,
                    Text = letter,
                    TextColor3 = INK,
                    TextSize = PLAQUE_TEXT_SIZE,
                    Font = "GothamBold",
                },
            },
        },
    }
end

local function tube(name: string, size: { number }, x: number): Spec.PartSpec
    return Spec.part(name, {
        Size = size,
        CFrame = Spec.cframe({ x, tubeY(size), 0 }, Spec.ROT.CYL_VERTICAL),
        Shape = "Cylinder",
        Material = "Metal",
        Color = TUBE_COLOR,
        CanCollide = false,
    })
end

-- One rack: the 6" tube IS Rack_X (the server fires from its Position); the base, the
-- smaller tubes and the lettered plaque are its children.
local function buildRack(name: string, letter: string, x: number): Spec.PartSpec
    local base = Spec.part("Base", {
        Size = BASE_SIZE,
        CFrame = Spec.cframe({ x, BASE_Y, 0 }),
        Material = "Wood",
        Color = TIMBER_GREY,
        CanCollide = true,
    })
    local plaque = Spec.part("Plaque", {
        Size = PLAQUE_SIZE,
        CFrame = Spec.cframe({ x, PLAQUE_Y, PLAQUE_Z }),
        Material = "Wood",
        Color = TIMBER_GREY,
        CanCollide = false,
        children = { plaqueFace(letter) },
    })
    local main = tube(name, TUBE6_SIZE, x + TUBE6_X)
    main.properties.CanCollide = false
    main.children =
        { base, plaque, tube("Tube4", TUBE4_SIZE, x + TUBE4_X), tube("Tube2", TUBE2_SIZE, x + TUBE2_X) }
    return main
end

-- Rotate a tree about an origin by yawDeg and translate to it — walking every nested
-- child (Base/Plaque/tubes are parented under their rack, and Roblox parts do not
-- inherit a parent's CFrame). Composes each part's OWN local rotation (a tube's
-- CYL_VERTICAL) with the yaw rather than replacing it, so cylinders stay vertical
-- under a nonzero yaw.
local function seatInWorld(spec: Spec.PartSpec, yawDeg: number, origin: { number })
    local props = spec.properties
    if props and props.CFrame then
        local cf = props.CFrame :: { number }
        local localRot = { cf[4], cf[5], cf[6], cf[7], cf[8], cf[9], cf[10], cf[11], cf[12] }
        local pos = Spec.rotY({ cf[1], cf[2], cf[3] }, yawDeg)
        local yawRot = Spec.rotYMat(yawDeg)
        local finalRot = Spec.matMul(yawRot, localRot)
        props.CFrame = {
            pos[1] + origin[1],
            pos[2] + origin[2],
            pos[3] + origin[3],
            finalRot[1],
            finalRot[2],
            finalRot[3],
            finalRot[4],
            finalRot[5],
            finalRot[6],
            finalRot[7],
            finalRot[8],
            finalRot[9],
        }
    end
    if spec.children then
        for _, child in spec.children do
            seatInWorld(child, yawDeg, origin)
        end
    end
end

function ProvingGround.build(): Spec.PartSpec
    local children: { Spec.PartSpec } = {}
    for i, rackName in ProvingPlan.RACKS do
        local letter = string.sub(rackName, -1)
        local rack = buildRack(rackName, letter, RACK_X_OFFSETS[i])
        seatInWorld(rack, ProvingGround.RACK_YAW_DEG, ProvingGround.RACK_ORIGIN)
        table.insert(children, rack)
    end
    local post = Spec.part("FiringPost", {
        Size = POST_SIZE,
        CFrame = Spec.cframe({ 0, POST_Y, 0 }),
        Material = "Slate",
        Color = POST_COLOR,
        CanCollide = true,
    })
    seatInWorld(post, ProvingGround.POST_YAW_DEG, ProvingGround.POST_ORIGIN)
    table.insert(children, post)

    return Spec.model("ProvingGround", children)
end

return ProvingGround
