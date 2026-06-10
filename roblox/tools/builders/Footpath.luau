--!strict
-- Garden circulation: a stone ring path on the centre side of each wet tier (at
-- gardenTiers.pathR), stepping stones across the still pools, slab links toward the
-- N ramp, and arched bridges over the pool widenings. Deterministic (sin-hash
-- jitter only). The still pools and channel water are terrain; this is the stone.
local Spec = require("./Spec")
local Bridge = require("./Bridge")

local Footpath = {}

local GROUND_LIFT = 2 -- terrain renders ~2 studs proud (matches TerraceDressing/Teahouse)
local SANDO = 1.5 * math.pi -- entrance gap at -Z; leave it clear

local function rand(seed: number): number -- deterministic jitter in [0,1)
    local v = math.sin(seed * 12.9898) * 43758.5453
    return v - math.floor(v)
end

function Footpath.build(palette: { [string]: { number } }, L: any)
    local children = {}
    for _, g in L.gardenTiers do
        local gy = g.height + GROUND_LIFT
        local r = g.pathR
        local slabW = 3.2
        local step = slabW + 1.0 -- arc gap between slab centres
        local count = math.floor((2 * math.pi * r) / step)
        for k = 0, count - 1 do
            local a = (k / count) * 2 * math.pi
            if math.abs(((a - SANDO + math.pi) % (2 * math.pi)) - math.pi) < 0.18 then
                continue -- keep the sandō entrance clear
            end
            local jr = r + (rand(g.tier * 131 + k) - 0.5) * 1.2 -- slight in/out wobble
            local x, z = jr * math.cos(a), jr * math.sin(a)
            table.insert(
                children,
                Spec.part(`PathSlab{g.tier}_{k}`, {
                    Size = { slabW, 0.3, 2.6 },
                    CFrame = Spec.cframe({ x, gy + 0.15, z }, Spec.yaw(math.deg(a))),
                    Color = palette.gravel,
                    Material = "Slate",
                })
            )
        end
        -- a still-pool bridge at each pool gap (one per two huts keeps it sparse).
        local pools = math.floor(g.houseCount / 2)
        for p = 0, pools - 1 do
            local a = g.housePhase + (p + 0.5) * (2 * math.pi / pools)
            if math.abs(((a - SANDO + math.pi) % (2 * math.pi)) - math.pi) < 0.2 then
                continue
            end
            local aWorld = { g.pathR * math.cos(a), gy, g.pathR * math.sin(a) }
            local outR = g.channelR + g.channelWidth / 2
            local bWorld = { outR * math.cos(a), gy, outR * math.sin(a) }
            for _, bp in Bridge.arch(palette, aWorld, bWorld, 3.2, `P{g.tier}_{p}`) do
                table.insert(children, bp)
            end
        end
    end
    -- N tier-link slabs: a short slab at x≈0 (north promontory side) on each tier.
    for _, g in L.gardenTiers do
        local gy = g.height + GROUND_LIFT
        table.insert(
            children,
            Spec.part(`Link{g.tier}`, {
                Size = { 5, 0.3, 7 },
                CFrame = Spec.cframe({ 0, gy + 0.15, g.pathR }),
                Color = palette.gravel,
                Material = "Slate",
            })
        )
    end
    return Spec.model("Footpath", children)
end

return Footpath
