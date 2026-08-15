--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local MachiyaShops = require("../tools/builders/MachiyaShops")
local Machiya = require("../tools/builders/Machiya")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local ArenaLayout = require("../tools/builders/ArenaLayout")

-- Helpers copied from Machiya.spec.luau — the harness has no shared helpers module.
-- EVERY part, including those inside child models (see Machiya.spec's note on the
-- noren panels silently dropping out of envelope checks when they were grouped).
local function allParts(node, out)
    out = out or {}
    for _, c in node.children or {} do
        if c.properties and c.properties.Size and c.properties.CFrame then
            table.insert(out, c)
        end
        if c.children then
            allParts(c, out)
        end
    end
    return out
end

local function find(node, name)
    for _, c in node.children do
        if c.name == name then
            return c
        end
    end
    return nil
end

describe("MachiyaShops registry", function()
    test("hanabiya carries the owner's envelope verbatim", function()
        local h = MachiyaShops.hanabiya
        expect(h.name).toBe("Hanabiya")
        expect(h.envelope.x0).toBe(-1.67)
        expect(h.envelope.x1).toBe(16.26)
        expect(h.envelope.z0).toBe(36.00)
        expect(h.envelope.z1).toBe(52.00)
        expect(h.envelope.floorY).toBe(113.10)
        expect(h.yaw).toBe(0)
        expect(h.frontage).toBe("open")
        expect(h.interior).toBe("full")
    end)

    test("apparel carries the surveyed Machiya_1 envelope", function()
        local s = MachiyaShops.apparel
        expect(s.name).toBe("MachiyaApparel")
        expect(s.envelope.x0).toBe(-22.42)
        -- x1 is NOT the survey's 2.30: it registers to 花火屋's built west face at a
        -- 1.5 roji standoff (see the relationship test below).
        expect(s.envelope.x1).toBe(-3.17)
        expect(s.envelope.z0).toBe(35.23)
        expect(s.envelope.z1).toBe(48.48)
        expect(s.envelope.floorY).toBe(113.30)
        expect(s.yaw).toBe(0)
        expect(s.frontage).toBe("open")
        expect(s.interior).toBe("shallow")
    end)

    test("accessories carries the surveyed Machiya_4 envelope", function()
        local s = MachiyaShops.accessories
        expect(s.name).toBe("MachiyaAccessories")
        expect(s.envelope.x0).toBe(16.02)
        expect(s.envelope.x1).toBe(32.65)
        expect(s.envelope.z0).toBe(36.34)
        expect(s.envelope.z1).toBe(49.58)
        expect(s.envelope.floorY).toBe(113.21)
        expect(s.yaw).toBe(0)
        expect(s.frontage).toBe("open")
        expect(s.interior).toBe("shallow")
    end)

    test("sportsbook carries the surveyed Machiya_East envelope", function()
        local s = MachiyaShops.sportsbook
        expect(s.name).toBe("MachiyaEast")
        expect(s.envelope.x0).toBe(63.57)
        expect(s.envelope.x1).toBe(84.97)
        expect(s.envelope.z0).toBe(40.96)
        expect(s.envelope.z1).toBe(54.20)
        expect(s.envelope.floorY).toBe(109.74)
        expect(s.yaw).toBe(0)
        expect(s.frontage).toBe("koshi")
        expect(s.interior).toBe("none")
    end)
end)

describe("apparel shell", function()
    local m = Machiya.build(ZenDojo.palette, ArenaLayout, MachiyaShops.apparel)
    local parts = allParts(m)
    test("subordinate to the tower", function()
        for _, p in parts do
            local topY = p.properties.CFrame[2] + p.properties.Size[2] / 2
            expect(topY <= ArenaLayout.towerTopY - 9.0).toBe(true)
        end
    end)
    test("has a dressing set and it stays inside the envelope", function()
        local e = MachiyaShops.apparel.envelope
        local d = find(m, "Dressing")
        expect(d ~= nil).toBe(true)
        for _, p in allParts(d) do
            expect(p.properties.CFrame[1] >= e.x0 and p.properties.CFrame[1] <= e.x1).toBe(true)
            expect(p.properties.CFrame[3] >= e.z0 and p.properties.CFrame[3] <= e.z1).toBe(true)
        end
    end)
end)

describe("apparel registers to the built neighbour", function()
    test("east edge is 花火屋's west face minus the 1.5-stud roji", function()
        -- The massing block predates the built shop, and its surveyed x1 (2.30) ran
        -- ~3.97 studs INTO 花火屋. The shell registers to the BUILT edge
        -- (derive-from-what-it-touches): west face −1.67, minus a 1.5 roji gap —
        -- so this drift class fails loudly forever.
        expect(MachiyaShops.apparel.envelope.x1 + 1.5).toBeCloseTo(MachiyaShops.hanabiya.envelope.x0, 0.001)
    end)
end)
