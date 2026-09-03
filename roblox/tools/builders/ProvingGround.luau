--!strict
-- The fireworks proving range: five mortar stations SCATTERED across the canyon
-- (owner placement 2026-09-06, superseding the 2026-09-01 suspension-bridge line),
-- fired from ProvingController's anywhere-in-Studio panel. Each station is placed AND
-- AIMED by the owner: the 6" tube's own orientation is the launch heading the server
-- fires along ("oriented in the angle of elevation and direction I'd like to be used").
-- Future: public access with jukebox-style play queueing (backlog). NO Tags anywhere
-- here — stations stand in a world with real FireworkLaunchSites and must never be
-- mistaken for one; the server fires by looking up a rack by name.
--
-- Tube bores are the owner's 2026-09-01 ruling: 2", 4" and 6" shells for now
-- (yonshakudama noted for the future). 1 stud = 1 foot, and real display mortars
-- run ~4-5:1 length-to-bore, which is what these dimensions encode.
local Spec = require("./Spec")
local ProvingPlan = require("../../src/shared/ProvingPlan")

local ProvingGround = {}

-- ===== baked placement (surveyed 2026-09-06: the owner dragged and aimed each station
-- live in Studio; these are the 6" tubes' world CFrames read back out and re-orthonormalized).
-- Paired with ProvingPlan.RACKS by index (the A..E lineage order).
ProvingGround.STATIONS = {
    {
        name = "north arena",
        cf = {
            -48.37,
            244.1778,
            -81.1563,
            -0.004721,
            0.020782,
            -0.999773,
            0.974915,
            0.222576,
            2.3e-05,
            0.222526,
            -0.974694,
            -0.021312,
        },
    },
    {
        name = "bridge",
        cf = {
            -240.9508,
            221.8876,
            53.0429,
            0.005024,
            0.020696,
            -0.999773,
            0.971515,
            -0.236978,
            -2.4e-05,
            -0.236924,
            -0.971295,
            -0.021297,
        },
    },
    {
        name = "upper north",
        cf = {
            -298.1053,
            263.1958,
            -84.7032,
            -0.010115,
            0.018718,
            -0.999774,
            0.879669,
            0.475587,
            4e-06,
            0.475479,
            -0.87947,
            -0.021276,
        },
    },
    {
        name = "mid pool",
        cf = {
            -263.5037,
            176.5959,
            -1.5086,
            0.000911,
            0.02129,
            -0.999773,
            0.999062,
            -0.043305,
            -1.2e-05,
            -0.043295,
            -0.998835,
            -0.02131,
        },
    },
    {
        name = "hi west",
        cf = {
            -454.1745,
            273.8061,
            -35.5307,
            0.498644,
            0.021279,
            -0.866546,
            0.86472,
            0.05711,
            0.498996,
            0.060106,
            -0.998141,
            0.010077,
        },
    },
}
-- ProvingPlan.RACKS may name MORE than these (the virtual "hanabiya roof" resolves to
-- the rooftop battery's mounts, not a yard rack) -- but every physical station here
-- must be nameable by the plan, in lineage order.
for i, st in ProvingGround.STATIONS do
    assert(
        st.name == ProvingPlan.RACKS[i],
        `station {i} is '{st.name}' but ProvingPlan.RACKS[{i}] is '{ProvingPlan.RACKS[i]}'`
    )
end

local BASE_SIZE = { 3, 0.6, 3 } -- timber base block
-- Mortar tubes at real proportions (cylinder Size is {length, dia, dia}; length -> world-up
-- via CYL_VERTICAL). Rack_X IS the 6" tube — the server fires from its Position — with the
-- 4" and 2" tubes standing beside it on the shared base.
-- Parked defect (m), fixed 2026-09-05: bore is the INNER diameter (owner ruling at the
-- deck-mortars gate), so the drawn cylinder is bore + 2×wall — the same 0.06 wall the deck
-- tubes hollow against. Drawn solid (this is a baked model.json; the deck tubes' CSG hollow
-- is runtime-only), sized honestly.
local TUBE_WALL = 0.06
local TUBE6_SIZE = { 2.5, 0.5 + 2 * TUBE_WALL, 0.5 + 2 * TUBE_WALL } -- 6" bore, 2.5 ft — the class the seed drafts imply
local TUBE4_SIZE = { 1.5, 1 / 3 + 2 * TUBE_WALL, 1 / 3 + 2 * TUBE_WALL } -- 4" bore, 1.5 ft
local TUBE2_SIZE = { 0.85, 1 / 6 + 2 * TUBE_WALL, 1 / 6 + 2 * TUBE_WALL } -- 2" bore, 10 in
local TUBE6_X, TUBE4_X, TUBE2_X = -0.8, 0.1, 0.75 -- spread across the base, local X

-- Grey-cypress timber treatment (216/214/206) — the base and plaque wear it.
local TIMBER_GREY = { 0.847, 0.839, 0.808 }
local TUBE_COLOR = { 0.20, 0.20, 0.22 }

-- Local ground datum is y = 0 (each origin's y carries the surveyed ground height).
local BASE_Y = BASE_SIZE[2] / 2
local function tubeY(size: { number }): number
    return BASE_SIZE[2] + size[1] / 2
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
-- No plaques (owner, 2026-09-06: "you can take the name plaques off the racks") —
-- the station names live in the panel, not the world.
local function buildRack(name: string, x: number): Spec.PartSpec
    local base = Spec.part("Base", {
        Size = BASE_SIZE,
        CFrame = Spec.cframe({ x, BASE_Y, 0 }),
        Material = "Wood",
        Color = TIMBER_GREY,
        CanCollide = true,
    })
    local main = tube(name, TUBE6_SIZE, x + TUBE6_X)
    main.properties.CanCollide = false
    main.children = { base, tube("Tube4", TUBE4_SIZE, x + TUBE4_X), tube("Tube2", TUBE2_SIZE, x + TUBE2_X) }
    return main
end

-- Seat a rack tree at its station: T = stationCF · (rackLocalCF)⁻¹ applied to every
-- part, so the 6" tube lands EXACTLY on the owner-surveyed CFrame and its base,
-- plaque and sibling tubes ride along rigidly — the same relative composition the
-- old bridge line had, at whatever position and aim the owner chose.
local function invertCF(cf: { number }): { number }
    -- rotation transpose; position = -Rᵀ·p
    local px, py, pz = cf[1], cf[2], cf[3]
    local r = { cf[4], cf[5], cf[6], cf[7], cf[8], cf[9], cf[10], cf[11], cf[12] }
    local t = { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
    return {
        -(t[1] * px + t[2] * py + t[3] * pz),
        -(t[4] * px + t[5] * py + t[6] * pz),
        -(t[7] * px + t[8] * py + t[9] * pz),
        t[1],
        t[2],
        t[3],
        t[4],
        t[5],
        t[6],
        t[7],
        t[8],
        t[9],
    }
end

local function composeCF(a: { number }, b: { number }): { number }
    local ra = { a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12] }
    local rb = { b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12] }
    local r = Spec.matMul(ra, rb)
    local bx, by, bz = b[1], b[2], b[3]
    return {
        a[1] + ra[1] * bx + ra[2] * by + ra[3] * bz,
        a[2] + ra[4] * bx + ra[5] * by + ra[6] * bz,
        a[3] + ra[7] * bx + ra[8] * by + ra[9] * bz,
        r[1],
        r[2],
        r[3],
        r[4],
        r[5],
        r[6],
        r[7],
        r[8],
        r[9],
    }
end

local function seatAtStation(spec: Spec.PartSpec, transform: { number })
    local props = spec.properties
    if props and props.CFrame then
        props.CFrame = composeCF(transform, props.CFrame :: { number })
    end
    if spec.children then
        for _, child in spec.children do
            seatAtStation(child, transform)
        end
    end
end

function ProvingGround.build(): Spec.PartSpec
    local children: { Spec.PartSpec } = {}
    for _, station in ProvingGround.STATIONS do
        local rack = buildRack(station.name, 0)
        if station.apex then
            local props = rack.properties :: any
            props.Attributes = { LaunchApex = station.apex }
        end
        -- the rack part's own local CFrame, exactly as buildRack/tube composed it
        local rackLocal = { TUBE6_X, tubeY(TUBE6_SIZE), 0 }
        local localCF = Spec.cframe(rackLocal, Spec.ROT.CYL_VERTICAL)
        seatAtStation(rack, composeCF(station.cf, invertCF(localCF)))
        table.insert(children, rack)
    end
    return Spec.model("ProvingGround", children)
end

return ProvingGround
