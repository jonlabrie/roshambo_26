--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local Machiya = require("../tools/builders/Machiya")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local ArenaLayout = require("../tools/builders/ArenaLayout")

local model = Machiya.build(ZenDojo.palette, ArenaLayout)

-- THE OWNER'S TRANSFORM, read back from the holdout block they placed in Studio 2026-08-05.
-- These are not proposals; a change here means the building moved.
local X0, X1 = -1.67, 16.26
local Z0, Z1 = 44.00, 52.00
local FLOOR, TOP = 113.10, 127.36

local function find(node, name)
    for _, c in node.children do
        if c.name == name then
            return c
        end
    end
    return nil
end

local function countPrefix(node, prefix)
    local n = 0
    for _, c in node.children do
        if (c.name :: string):sub(1, #prefix) == prefix then
            n += 1
        end
    end
    return n
end

-- A part's TRUE y extents, accounting for rotation. The naive centre +/- Size.Y/2 is wrong for
-- anything tilted, and this model's roof planes and shopfront eave are all tilted — the first
-- version of this helper let a sloping eave measure as though it were flat.
-- CFrame is { x, y, z, r00..r22 } row-major, so row 1 is indices 7, 8, 9.
local function yspan(part)
    local cf, sz = part.properties.CFrame, part.properties.Size
    local cy = cf[2]
    local r10, r11, r12 = cf[7], cf[8], cf[9]
    local ext = math.abs(r10) * sz[1] / 2 + math.abs(r11) * sz[2] / 2 + math.abs(r12) * sz[3] / 2
    return cy - ext, cy + ext
end

describe("Machiya — the owner's envelope", function()
    test("it is a model named Hanabiya", function()
        expect(model.name).toBe("Hanabiya")
        expect(model.className).toBe("Model")
    end)

    test("the floor slab spans the owner's footprint exactly", function()
        local slab = find(model, "FloorSlab")
        expect(slab ~= nil).toBe(true)
        expect(slab.properties.Size[1]).toBe(X1 - X0)
        expect(slab.properties.Size[3]).toBe(Z1 - Z0)
        -- centred on the footprint
        expect(math.abs(slab.properties.CFrame[1] - (X0 + X1) / 2) < 0.001).toBe(true)
        expect(math.abs(slab.properties.CFrame[3] - (Z0 + Z1) / 2) < 0.001).toBe(true)
    end)

    test("NOTHING RISES ABOVE THE OWNER'S TOP", function()
        -- The shop must stay 9 studs subordinate to the shōrō (136.5). A roof tweak that
        -- closes that gap is a defect, not a style change.
        for _, c in model.children do
            if c.properties.Size and c.properties.CFrame then
                local _, hi = yspan(c)
                expect(hi <= TOP + 0.001).toBe(true)
            end
        end
    end)

    test("nothing stands on the ground inside the promenade", function()
        -- shopCorridor z28..44 is inviolable at ground level. The eave is the ONE exception
        -- and is aerial — so anything reaching north of z44 must clear an avatar.
        for _, c in model.children do
            if c.properties.Size and c.properties.CFrame then
                local cz, dz = c.properties.CFrame[3], c.properties.Size[3]
                local lo = yspan(c)
                if cz - dz / 2 < Z0 - 0.001 then
                    -- AVATAR CLEARANCE, not a round number. A Roblox character stands about 5
                    -- studs; the rule this enforces is that the promenade stays WALKABLE, and the
                    -- shopfront eave is meant to be walked under. 6 was an arbitrary first guess
                    -- and it argued with a correctly-built hisashi.
                    expect(lo >= FLOOR + 5.2).toBe(true)
                end
            end
        end
    end)
end)

describe("Machiya — what makes it a shop and not a teahouse", function()
    test("the frontage is OPEN — no wall spans it", function()
        -- The single strongest signal that this is a machiya. A wall part sitting on the
        -- frontage line would make it another teahouse.
        for _, c in model.children do
            if c.properties.Size and c.properties.CFrame and (c.name :: string):sub(1, 4) == "Wall" then
                local cz = c.properties.CFrame[3]
                expect(math.abs(cz - Z0) > 1).toBe(true)
            end
        end
    end)

    test("it has front posts, a counter and an upper floor", function()
        expect(countPrefix(model, "FrontPost") >= 4).toBe(true)
        expect(find(model, "Counter") ~= nil).toBe(true)
        expect(find(model, "UpperFloor") ~= nil).toBe(true)
    end)

    test("the eave overhangs the frontage", function()
        local eave = find(model, "Eave")
        expect(eave ~= nil).toBe(true)
        expect(eave.properties.CFrame[3] - eave.properties.Size[3] / 2 < Z0).toBe(true)
    end)

    test("kōshi lattice fills the upper storey", function()
        expect(countPrefix(model, "Koshi") >= 6).toBe(true)
    end)

    test("the noren hangs under the eave and you can walk through it", function()
        expect(countPrefix(model, "Noren") >= 3).toBe(true)
        for _, c in model.children do
            if (c.name :: string):sub(1, 5) == "Noren" then
                expect(c.properties.CanCollide).toBe(false)
            end
        end
    end)
end)

describe("Machiya — the parts other tasks bind to", function()
    test("the Threshold volume is inset one stud from the frontage", function()
        local t = find(model, "Threshold")
        expect(t ~= nil).toBe(true)
        local cz, dz = t.properties.CFrame[3], t.properties.Size[3]
        expect(math.abs((cz - dz / 2) - (Z0 + 1)) < 0.001).toBe(true)
        expect(math.abs((cz + dz / 2) - Z1) < 0.001).toBe(true)
    end)

    test("the Threshold is tall enough that a jump cannot leave it", function()
        local t = find(model, "Threshold")
        local cy, dy = t.properties.CFrame[2], t.properties.Size[2]
        expect(math.abs((cy - dy / 2) - FLOOR) < 0.001).toBe(true)
        -- HumanoidRootPart stands ~3 above the floor and gains ~7 at the apex of a default jump.
        expect((cy + dy / 2) > FLOOR + 10).toBe(true)
    end)

    test("the Threshold is invisible and never collides or blocks a ray", function()
        local t = find(model, "Threshold")
        expect(t.properties.Transparency).toBe(1)
        expect(t.properties.CanCollide).toBe(false)
        expect(t.properties.CanQuery).toBe(false)
        expect(t.properties.CanTouch).toBe(false)
    end)

    test("the sign is one framed board carrying the whole name, facing the promenade", function()
        local k = find(model, "Kanban")
        expect(k ~= nil).toBe(true)
        expect(k.properties.CFrame[3] < (Z0 + Z1) / 2).toBe(true)
        local face = find(k, "Face")
        expect(face ~= nil).toBe(true)
        -- SizingMode is the whole trick: it defaults to FixedSize, under which the canvas is
        -- CanvasSize (800x600) and PixelsPerStud is IGNORED. That bug rendered the name as a
        -- speck and is the only reason the sign was ever split into three boards.
        expect(face.properties.SizingMode).toBe("PixelsPerStud")
        expect(face.properties.PixelsPerStud <= 40).toBe(true)
        local text = find(face, "Text")
        expect(text ~= nil).toBe(true)
        expect(text.properties.Text).toBe("花火屋")
    end)

    test("the sign is dark letters on a light ground, in a frame on all four sides", function()
        local k = find(model, "Kanban")
        local text = find(find(k, "Face"), "Text")
        -- A light panel with light lettering is invisible, and it is the kind of thing that
        -- survives review because both values look reasonable on their own.
        local panelLum = k.properties.Color[1] + k.properties.Color[2] + k.properties.Color[3]
        local inkLum = text.properties.TextColor3[1]
            + text.properties.TextColor3[2]
            + text.properties.TextColor3[3]
        expect(panelLum > inkLum + 1).toBe(true)
        expect(countPrefix(model, "KanbanFrame")).toBe(4)
    end)

    test("the shopfront is sliding doors standing OPEN, under shoji transoms", function()
        -- Open is the point: a machiya shopfront is doors pushed aside, not a hole. Every bay
        -- keeps most of its width clear.
        expect(countPrefix(model, "Transom") >= 5).toBe(true)
        expect(countPrefix(model, "DoorLeaf")).toBe(5)
        local slab = find(model, "FloorSlab")
        local frontage = slab.properties.Size[1]
        local covered = 0
        for _, c in model.children do
            if (c.name :: string):sub(1, 8) == "DoorLeaf" then
                covered += c.properties.Size[1]
            end
        end
        expect(covered < frontage * 0.45).toBe(true)
    end)
end)

describe("Machiya — the flush rule", function()
    test("front posts sit inside the slab, not proud of it", function()
        local slab = find(model, "FloorSlab")
        local sx0 = slab.properties.CFrame[1] - slab.properties.Size[1] / 2
        local sx1 = slab.properties.CFrame[1] + slab.properties.Size[1] / 2
        for _, c in model.children do
            if (c.name :: string):sub(1, 9) == "FrontPost" then
                local cx, dx = c.properties.CFrame[1], c.properties.Size[1]
                expect(cx - dx / 2 >= sx0 - 0.001).toBe(true)
                expect(cx + dx / 2 <= sx1 + 0.001).toBe(true)
            end
        end
    end)
end)
