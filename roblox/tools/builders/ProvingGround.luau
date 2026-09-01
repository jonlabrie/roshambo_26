--!strict
-- The fireworks proving range at FallsLanding: five mortar racks the panel fires from
-- (ProvingPlan.RACKS names them Rack_A..Rack_E) and a FiringPost the yard is composed
-- for, set back from the line. NO Tags anywhere here — racks stand next to real
-- FireworkLaunchSites elsewhere in the arena and must never be mistaken for one; the
-- server fires by looking up a rack's Position, not by a tag on it.
--
-- Structured like FallsDock: baked placement constants (PROVISIONAL until Task 8's
-- in-Studio marker survey), pure geometry, then a single rotate-about-ORIGIN pass that
-- seats every part in the world. Unlike FallsDock's flat part list, this yard nests a
-- Base and a Plaque under each rack's tube (Rojo parenting, not CFrame inheritance —
-- Roblox parts do not inherit a parent's CFrame), so the placement pass has to walk the
-- whole tree, not just the top-level children.
local Spec = require("./Spec")
local ProvingPlan = require("../../src/shared/ProvingPlan")

local ProvingGround = {}

-- ===== baked placement (PROVISIONAL: baked from ProvingGroundMarker survey (Task 8)) =====
ProvingGround.ORIGIN = { -352, 205, -20 } -- PROVISIONAL: baked from ProvingGroundMarker survey (Task 8)
ProvingGround.YAW_DEG = 0 -- PROVISIONAL: baked from ProvingGroundMarker survey (Task 8)

-- ===== dimensions (per the task-6 geometry) =====
-- Racks along local X, 12 studs apart, tubes facing up. ProvingPlan.RACKS is already in
-- this west-to-east order (A at the west end, E at the east), so offset[i] pairs with
-- RACKS[i] by index.
local RACK_X_OFFSETS = { -24, -12, 0, 12, 24 }
assert(
    #RACK_X_OFFSETS == #ProvingPlan.RACKS,
    `ProvingGround has {#RACK_X_OFFSETS} rack offsets but ProvingPlan names {#ProvingPlan.RACKS} racks`
)

local BASE_SIZE = { 3, 0.6, 3 } -- timber base block
local TUBE_SIZE = { 3, 1.4, 1.4 } -- cylinder: local-X (length) -> world-up via CYL_VERTICAL
local PLAQUE_SIZE = { 1.2, 1.2, 0.15 }
local POST_SIZE = { 1.2, 0.6, 1.2 }

-- FallsLanding's grey-cypress timber treatment (216/214/206) — the base and plaque wear it.
local TIMBER_GREY = { 0.847, 0.839, 0.808 }
local TUBE_COLOR = { 0.20, 0.20, 0.22 }
local POST_COLOR = { 0.55, 0.55, 0.52 }
local INK = { 0.15, 0.13, 0.11 }

-- Local ground datum is y = 0 (ORIGIN.y carries the surveyed ground height). The base
-- sits ON it; the tube stands on the base; the plaque's top registers to the tube's top.
local BASE_Y = BASE_SIZE[2] / 2
local TUBE_Y = BASE_SIZE[2] + TUBE_SIZE[1] / 2
local TUBE_TOP_Y = BASE_SIZE[2] + TUBE_SIZE[1]
local PLAQUE_Y = TUBE_TOP_Y - PLAQUE_SIZE[2] / 2
-- On the firing-post side of the base: base's own +Z face, plus half the plaque's thin
-- (Z) dimension, so the plaque stands flush against that face.
local PLAQUE_Z = BASE_SIZE[3] / 2 + PLAQUE_SIZE[3] / 2

local FIRING_POST_POS = { 0, 0.3, 14 } -- 14 studs from the rack line, facing them; y = POST_SIZE[2]/2 so the post's base sits on the ground datum, not half-buried in it

-- ===== the plaque letter — Machiya's `kanjiLabel` canvas recipe (tools/builders/Machiya.luau,
-- ~lines 37-104), copied rather than shared: SizingMode "PixelsPerStud" (the default FixedSize
-- IGNORES PixelsPerStud and renders specks), a SMALL canvas with a fixed TextSize — TextScaled
-- is unreliable and TextSize caps near 100px, so big lettering always wants a small canvas, not
-- a big canvas with big text. PPS 64 / TextSize 90 mirrors Machiya's own single-glyph faces
-- (e.g. kanjiFace(..., 96, 64, ...) on the noren cloth).
local PLAQUE_PPS = 64
local PLAQUE_TEXT_SIZE = 90

local function plaqueFace(letter: string): Spec.PartSpec
    return {
        name = "Face",
        className = "SurfaceGui",
        properties = {
            -- Back = +Z outward normal (Roblox's Front/Back are -Z/+Z respectively; Machiya's
            -- Front faces its -Z street side, so the mirror-image face here, toward the +Z
            -- firing post, is Back) — readable by whoever stands at FiringPost looking back
            -- along -Z at the rack line.
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

-- One rack: the tube IS Rack_X (the server fires from its Position); the base and the
-- lettered plaque are its children.
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
    return Spec.part(name, {
        Size = TUBE_SIZE,
        CFrame = Spec.cframe({ x, TUBE_Y, 0 }, Spec.ROT.CYL_VERTICAL),
        Shape = "Cylinder",
        Material = "Metal",
        Color = TUBE_COLOR,
        CanCollide = false,
        children = { base, plaque },
    })
end

-- Rotate the whole tree about ORIGIN by YAW_DEG and translate to ORIGIN — walking every
-- nested child, not just the model's direct children, since Base/Plaque are parented
-- under their rack rather than living flat in the model (unlike FallsDock's part list).
-- Composes each part's OWN local rotation (e.g. a tube's CYL_VERTICAL) with the yaw
-- rather than replacing it, so a cylinder stays vertical under a future nonzero yaw.
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
        table.insert(children, buildRack(rackName, letter, RACK_X_OFFSETS[i]))
    end
    table.insert(
        children,
        Spec.part("FiringPost", {
            Size = POST_SIZE,
            CFrame = Spec.cframe(FIRING_POST_POS),
            Material = "Slate",
            Color = POST_COLOR,
            CanCollide = true,
        })
    )

    local model = Spec.model("ProvingGround", children)
    seatInWorld(model, ProvingGround.YAW_DEG, ProvingGround.ORIGIN)
    return model
end

return ProvingGround
