--!strict
local harness = require("./harness")
local Waterwheel = require("../tools/builders/Waterwheel")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Waterwheel cluster builder", function()
    test("one Wheel part per layout center, at that center", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        local wheels = 0
        for _, c in spec.children :: any do
            local i = c.name:match("^Wheel(%d+)$")
            if i then
                wheels += 1
                local ctr = L.waterwheel.centers[tonumber(i) :: number]
                expect(c.properties.CFrame[1]).toBe(ctr[1])
                expect(c.properties.CFrame[3]).toBe(ctr[3])
            end
        end
        expect(wheels).toBe(#L.waterwheel.centers)
    end)
    test("PADDLES paddles ring every wheel", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        local counts: { [string]: number } = {}
        for _, c in spec.children :: any do
            local w = c.name:match("^Paddle(%d+)_%d+$")
            if w then
                counts[w] = (counts[w] or 0) + 1
            end
        end
        for i = 1, #L.waterwheel.centers do
            expect(counts[tostring(i)]).toBe(Waterwheel.PADDLES)
        end
    end)
    test("the driver carries the RatchetDrum", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        local found = false
        for _, c in spec.children :: any do
            if c.name == "RatchetDrum" then
                found = true
            end
        end
        expect(found).toBe(true)
    end)
end)

describe("Waterwheel (in-river undershot)", function()
    test("no Headrace flume when not overshot (undershot, current-driven)", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        local names = {}
        for _, c in spec.children :: any do
            names[c.name] = true
        end
        expect(names["Headrace"] == nil).toBe(true)
        expect(names["Wheel1"]).toBe(true)
    end)
    test("support posts stand on the riverbed (bedY), not floating", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name:match("^Support") then
                local cy = c.properties.CFrame[2]
                local h = c.properties.Size[2]
                expect(cy - h / 2 <= L.waterwheel.bedY + 1).toBe(true)
            end
        end
    end)
end)

describe("Waterwheel art pass (timber lattice)", function()
    local W = L.waterwheel
    local spec = Waterwheel.build(ZenDojo.palette, L)
    local function lattice(): { any }
        local out = {}
        for _, c in spec.children :: any do
            if c.name:match("^Wheel1T_") then
                table.insert(out, c)
            end
        end
        return out
    end
    test("Wheel1 becomes the invisible spin/spray proxy at full diameter", function()
        for _, c in spec.children :: any do
            if c.name == "Wheel1" then
                expect(c.properties.Transparency).toBe(1)
                expect(c.properties.CanCollide).toBe(false)
                expect(c.properties.Size[2]).toBe(2 * W.radius)
                expect(c.properties.Size[3]).toBe(2 * W.radius)
            end
        end
    end)
    test("the visible wheel: round hoops, joint-aligned spokes, steps, pegs", function()
        local counts = { HP = 0, SP = 0, RR = 0, ST = 0, PG = 0, HUB = 0, SH = 0, CL = 0 }
        for _, c in lattice() do
            local kind = c.name:match("^Wheel1T_(%u+)")
            if kind and counts[kind] ~= nil then
                counts[kind] += 1
            end
        end
        expect(counts.HP).toBe(2 * Waterwheel.RIM_SEGS) -- hoop chords, both faces
        expect(counts.SP).toBe(2 * Waterwheel.SPOKES) -- radial spokes, both faces
        expect(counts.RR).toBe(2 * Waterwheel.SPOKES) -- spoke-to-spoke reinforcing ring
        expect(counts.ST).toBe(Waterwheel.STEPS) -- tread boards between the hoops
        -- through-dowels: 4 per paddle + 2 per step + 2 per spoke (one each face)
        expect(counts.PG).toBe(4 * Waterwheel.PADDLES + 2 * Waterwheel.STEPS + 2 * Waterwheel.SPOKES)
        expect(counts.HUB).toBe(1) -- hub boss
        expect(counts.SH).toBe(4) -- octagonal shaft prism (4 boxes, 8 flats)
        expect(counts.CL).toBe(2) -- spinning shaft collars inboard of the bearing bands
        -- the rim reads ROUND (chords fine enough) and every spoke/paddle/step lands on a joint
        expect(Waterwheel.RIM_SEGS >= 36).toBe(true)
        expect(Waterwheel.RIM_SEGS % Waterwheel.SPOKES).toBe(0)
        expect(Waterwheel.RIM_SEGS % Waterwheel.PADDLES).toBe(0)
        expect(Waterwheel.RIM_SEGS % Waterwheel.STEPS).toBe(0)
    end)
    test("every lattice timber stays inside the wheel envelope", function()
        local ctr = W.centers[1]
        for _, c in lattice() do
            local dx = c.properties.CFrame[1] - ctr[1]
            local dy = c.properties.CFrame[2] - ctr[2]
            local dz = c.properties.CFrame[3] - ctr[3]
            -- yaw 90: the axle runs along world Z, the disc lives in the world X-Y plane.
            -- Shaft collars (CL) legitimately sit out at the pier bearings; the shaft
            -- prism (SH) is centred but runs through them — both stay on the axle line.
            if c.name:match("^Wheel1T_CL") then
                expect(math.sqrt(dx * dx + dy * dy) < 0.001).toBe(true)
            else
                expect(math.abs(dz) <= W.width / 2 + 0.6).toBe(true)
                expect(math.sqrt(dx * dx + dy * dy) <= W.radius + 0.001).toBe(true)
            end
        end
    end)
    test("paddles wear the wet mossy variant and clear the rim by only an inch or two", function()
        local ctr = W.centers[1]
        local rim = W.radius - Waterwheel.RIM_INSET -- the hoop outer edge
        local n = 0
        for _, c in spec.children :: any do
            if c.name:match("^Paddle1_%d+$") then
                n += 1
                expect(c.properties.MaterialVariant).toBe("MossyPaddle")
                expect(c.properties.Color).toBe(ZenDojo.palette.paddleWet)
                local dx = c.properties.CFrame[1] - ctr[1]
                local dy = c.properties.CFrame[2] - ctr[2]
                local reach = math.sqrt(dx * dx + dy * dy) + c.properties.Size[2] / 2
                expect(reach > rim + 0.05).toBe(true)
                expect(reach < rim + 0.35).toBe(true)
            end
        end
        expect(n).toBe(Waterwheel.PADDLES)
    end)
    test("axle, bearings, ratchet wear IronDark; lattice wears CypressWeathered", function()
        local bearings = 0
        for _, c in spec.children :: any do
            if c.name == "RatchetDrum" or c.name:match("^Bearing") then
                expect(c.properties.MaterialVariant).toBe("IronDark")
                if c.name:match("^Bearing%d") then -- rings only, not the BearingPlates
                    bearings += 1
                end
            end
            if c.name:match("^Axle%d+$") then
                expect(c.properties.Transparency).toBe(1) -- static VFX/axis proxy only
            end
        end
        expect(bearings).toBe(2) -- one in each pier, the shaft turns in them
        for _, c in lattice() do
            if c.name:match("^Wheel1T_CL") then
                expect(c.properties.MaterialVariant).toBe("IronDark") -- shaft collars are iron
            else
                expect(c.properties.MaterialVariant).toBe("CypressWeathered")
            end
        end
    end)
    test("deterministic: two builds emit identical geometry", function()
        local a = Waterwheel.build(ZenDojo.palette, L)
        local b = Waterwheel.build(ZenDojo.palette, L)
        expect(#a.children :: any).toBe(#b.children :: any)
        for i, ca in a.children :: any do
            local cb = (b.children :: any)[i]
            expect(ca.name).toBe(cb.name)
            for j = 1, 12 do
                expect(ca.properties.CFrame[j]).toBe(cb.properties.CFrame[j])
            end
        end
    end)
end)
