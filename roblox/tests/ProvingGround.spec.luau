--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ProvingGround = require("../tools/builders/ProvingGround")
local ProvingPlan = require("../src/shared/ProvingPlan")

local LETTERS = { Rack_A = "A", Rack_B = "B", Rack_C = "C", Rack_D = "D", Rack_E = "E" }

local function childNamed(spec: any, name: string): any?
    for _, c in (spec.children or {}) :: { any } do
        if c.name == name then
            return c
        end
    end
    return nil
end

local function findClass(spec: any, className: string): any?
    for _, c in (spec.children or {}) :: { any } do
        if c.className == className then
            return c
        end
        local deeper = findClass(c, className)
        if deeper then
            return deeper
        end
    end
    return nil
end

local function eachSpec(spec: any, fn: (any) -> ())
    fn(spec)
    for _, c in (spec.children or {}) :: { any } do
        eachSpec(c, fn)
    end
end

describe("ProvingGround — the yard the range fires from", function()
    local model = ProvingGround.build()

    test("every rack ProvingPlan can name exists as a BasePart with its plaque letter", function()
        for _, rackName in ProvingPlan.RACKS do
            local rack = childNamed(model, rackName)
            expect(rack ~= nil).toBe(true)
            assert(rack)
            expect(rack.className).toBe("Part") -- the server fires from rack.Position
            local gui = findClass(rack, "SurfaceGui")
            expect(gui ~= nil).toBe(true)
            assert(gui)
            local label = findClass(gui, "TextLabel") or gui.children and gui.children[1]
            expect(label ~= nil).toBe(true)
            assert(label)
            expect(label.properties.Text).toBe(LETTERS[rackName])
        end
    end)

    test("racks sit 12 studs apart along one line", function()
        -- 3D distance between adjacent racks (in ProvingPlan.RACKS order, which is the
        -- rack line's spatial order), not raw X: distance is yaw-invariant, so this
        -- keeps holding once Task 8 bakes a nonzero YAW_DEG.
        local positions = {}
        for _, rackName in ProvingPlan.RACKS do
            local rack = childNamed(model, rackName)
            assert(rack)
            local cf = rack.properties.CFrame
            table.insert(positions, { cf[1], cf[2], cf[3] })
        end
        for i = 2, #positions do
            local a, b = positions[i - 1], positions[i]
            local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
            local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
            -- Stations are 12 apart along the line; the bridge's catenary adds up to
            -- ~1.2 studs of dy between neighbours plus a small tilt displacement, so
            -- the tube-to-tube distance rides a little over 12, never exactly on it.
            expect(math.abs(dist - 12) < 0.5).toBe(true)
        end
    end)

    test("no firing post — the panel opens anywhere, nothing marks a spot", function()
        -- Owner ruling 2026-09-01: the location-bound panel was theater. The yard is
        -- racks only; a FiringPost reappearing here means someone resurrected the idea.
        expect(childNamed(model, "FiringPost") == nil).toBe(true)
    end)

    test("every rack carries all three bores at mortar proportions (owner ruling: 2/4/6 inch)", function()
        for _, rackName in ProvingPlan.RACKS do
            local rack = childNamed(model, rackName)
            assert(rack)
            -- Rack_X is itself the 6" tube; Tube4 and Tube2 stand beside it.
            local tubes = { rack, childNamed(rack, "Tube4"), childNamed(rack, "Tube2") }
            local bores = { 0.5, 1 / 3, 1 / 6 } -- 6", 4", 2" in studs (1 stud = 1 ft)
            for i, t in tubes do
                expect(t ~= nil).toBe(true)
                assert(t)
                local size = t.properties.Size
                expect(math.abs(size[2] - bores[i]) < 0.001).toBe(true)
                expect(size[2] == size[3]).toBe(true)
                -- Real display mortars run ~4-5.5:1 length-to-bore; the old 2:1 stubs
                -- read as buckets (owner: "these mortar tubes are huge").
                local ratio = size[1] / size[2]
                expect(ratio > 4 and ratio < 5.5).toBe(true)
            end
        end
    end)

    test("NOTHING IN THE YARD IS A LAUNCH SITE and nothing floats unanchored", function()
        eachSpec(model, function(spec)
            local props = spec.properties or {}
            expect(props.Tags == nil).toBe(true)
            if spec.className == "Part" then
                expect(props.Anchored).toBe(true)
            end
        end)
    end)
end)
