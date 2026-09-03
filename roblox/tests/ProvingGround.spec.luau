--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ProvingGround = require("../tools/builders/ProvingGround")
local ProvingPlan = require("../src/shared/ProvingPlan")

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

    test("every rack ProvingPlan can name exists as a BasePart -- and wears NO plaque", function()
        -- Owner, 2026-09-06: plaques off; station names live in the panel, not the world.
        for _, rackName in ProvingPlan.RACKS do
            local rack = childNamed(model, rackName)
            expect(rack ~= nil).toBe(true)
            assert(rack)
            expect(rack.className).toBe("Part") -- the server fires from the rack's CFrame
            expect(childNamed(rack, "Plaque") == nil).toBe(true)
            expect(findClass(rack, "SurfaceGui") == nil).toBe(true)
        end
    end)

    test("EVERY STATION STANDS EXACTLY WHERE THE OWNER PUT IT, muzzle skyward", function()
        -- The 2026-09-06 scatter: STATIONS is the owner's live-dragged survey, and the
        -- built rack must land on it -- position AND orientation, because the tube's
        -- axis is the launch heading the server fires along. Skyward is the safety
        -- half: a station accidentally flipped would fire into the deck it stands on.
        for i, station in ProvingGround.STATIONS do
            local rack = childNamed(model, ProvingPlan.RACKS[i])
            assert(rack)
            local cf = rack.properties.CFrame
            for k = 1, 12 do
                expect(math.abs(cf[k] - station.cf[k]) < 0.01).toBe(true)
            end
            -- muzzle axis = cylinder local X = rotation column one; its Y must be up
            expect(cf[7] > 0.05).toBe(true)
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
            local wall = 0.06 -- bore is the INNER diameter (owner ruling, deck-mortars gate);
            -- the drawn cylinder is bore + 2*wall, same wall the deck tubes hollow against
            for i, t in tubes do
                expect(t ~= nil).toBe(true)
                assert(t)
                local size = t.properties.Size
                expect(math.abs(size[2] - (bores[i] + 2 * wall)) < 0.001).toBe(true)
                expect(size[2] == size[3]).toBe(true)
                -- Real display mortars run ~4-5.5:1 length-to-BORE; the old 2:1 stubs
                -- read as buckets (owner: "these mortar tubes are huge").
                local ratio = size[1] / bores[i]
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
