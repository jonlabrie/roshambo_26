--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local Machiya = require("../tools/builders/Machiya")
local MachiyaShops = require("../tools/builders/MachiyaShops")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local ArenaLayout = require("../tools/builders/ArenaLayout")

local model = Machiya.build(ZenDojo.palette, ArenaLayout, MachiyaShops.hanabiya)

-- THE OWNER'S TRANSFORM, read back from the holdout block they placed in Studio 2026-08-05.
-- These are not proposals; a change here means the building moved.
local X0, X1 = -1.67, 16.26
local Z0, Z1 = 36.00, 52.00 -- deepened off the FRONT 2026-08-13; the back is the terrain cut
local FLOOR = 113.10
-- The holdout's fixed top is retired (owner: "approximate, and can be safely ignored"). What the
-- envelope test actually protects is the bell tower, so it now checks that directly.
--
-- 153.54 is the TOWER, measured across every RoshamboStage model on its footprint — the drum
-- storey stands on the shōrō's roof and carries on up. This was 136.5, which is only the Shoro
-- model's own top and so named the middle of the building. 9.0 is the owner's number from the
-- spec ("9 studs subordinate to the bell tower"); it was 5.0, which I had invented.
local SHORO_TOP, MIN_SHORO_GAP = ArenaLayout.towerTopY, 9.0

-- EVERY part, including those inside child models. The noren became nested models when each panel
-- turned into a chain of segments, and every envelope test here walks `model.children` — so the
-- panels silently dropped out of the promenade and bell-tower checks the moment they were grouped.
-- A test that stops seeing its subject still passes.
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

-- The same for z. CFrame row 3 is indices 10, 11, 12.
local function zspan(part)
    local cf, sz = part.properties.CFrame, part.properties.Size
    local cz = cf[3]
    local ext = math.abs(cf[10]) * sz[1] / 2 + math.abs(cf[11]) * sz[2] / 2 + math.abs(cf[12]) * sz[3] / 2
    return cz - ext, cz + ext
end

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

    test("NOTHING CROWDS THE SHŌRŌ", function()
        -- The shop must stay clearly subordinate to the bell tower. This used to test against a
        -- fixed top from the holdout block; that number is gone, so it tests the thing the number
        -- was standing in for. A storey that grows into the shōrō is a defect, not a style change.
        for _, c in allParts(model) do
            local _, hi = yspan(c)
            expect(hi <= SHORO_TOP - MIN_SHORO_GAP).toBe(true)
        end
    end)

    -- ⚠ CORNER CHŌCHIN ARE EXEMPT FROM THE CLEARANCE RULE, by owner ruling (2026-09-06).
    -- Measured that day: every shop in the row hangs its lanterns with the hem 5.39 studs above
    -- its floor -- apparel, accessories and stats identically, because they share this formula
    -- and storey height. That is 1.01 short of the 6.4 avatar clearance this test enforces, and
    -- it is the state the row has SHIPPED in; the condition was invisible only because this
    -- describe block builds 花火屋, the one shop that had no lanterns until now.
    --
    -- Raising them is not available: the eave underside sits ~8.4 studs up, the lantern runs ~2.8
    -- from ring to hem, so clearing 6.4 would need the hook ABOVE the eave it hangs from. Sliding
    -- them further back under the eave buys at most 0.43, the eave's whole tilt.
    --
    -- The owner had already ruled this ("it's okay if they're low" -- see Machiya.luau's own
    -- assert, which permits a hem down to 5.0). This test simply did not know about the exception,
    -- the way it already knows about the eave. Skip the lantern subtree, not the rule.
    local function partsExceptChochin(node, out)
        out = out or {}
        for _, c in node.children or {} do
            if c.className == "Model" and (c.name :: string):sub(1, 7) == "Chochin" then
                continue
            end
            if c.properties and c.properties.Size and c.properties.CFrame then
                table.insert(out, c)
            end
            if c.children then
                partsExceptChochin(c, out)
            end
        end
        return out
    end

    test("nothing stands on the ground inside the promenade", function()
        -- The promenade is inviolable at ground level, and the frontage line is its south edge
        -- wherever that line currently sits. The eave is the ONE exception and is aerial — so
        -- anything reaching north of the frontage must clear an avatar.
        for _, c in partsExceptChochin(model) do
            do
                -- ROTATION-AWARE, like yspan. The naive centre − Size.Z/2 understates a tilted
                -- part's reach, and the noren segments are tilted by construction.
                local zlo = zspan(c)
                local lo = yspan(c)
                if zlo < Z0 - 0.001 then
                    -- AVATAR CLEARANCE. The WORKING avatar height is 6 studs, not the bare R15's
                    -- ~5 — hair adds a full stud and players wear it (owner's ruling 2026-08-13,
                    -- made by standing next to a 5-stud marker). The promenade must stay walkable.
                    expect(lo >= FLOOR + 6.4).toBe(true)
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

    test("THE COUNTER STANDS AT THE BACK, and the shop floor is in front of it", function()
        -- It was positioned relative to the FRONTAGE, which meant it marched north with the
        -- frontage the moment the shop was deepened — a counter halfway into the street, with
        -- the goods stacked between it and the customers. Measure it from the back wall.
        local counter = find(model, "Counter")
        local cz, dz = counter.properties.CFrame[3], counter.properties.Size[3]
        -- In the rear third of the plan. Not "within N studs of the wall" — that fought the
        -- shopkeeper's standing room, which is a separate requirement with its own test.
        expect(cz >= Z0 + 2 * (Z1 - Z0) / 3).toBe(true)
        -- and the point of the whole exercise: room for a crowd to stand and buy
        expect((cz - dz / 2) - Z0 >= 8).toBe(true)
    end)

    test("there is room to STAND behind the counter", function()
        -- The counter was pulled a stud forward to make space for a shopkeeper. Measure the gap
        -- against the wall's inner face, not the envelope, or the wall thickness gets counted
        -- as standing room.
        local counter = find(model, "Counter")
        local wall = find(model, "WallBack")
        local counterBack = counter.properties.CFrame[3] + counter.properties.Size[3] / 2
        local wallInner = wall.properties.CFrame[3] - wall.properties.Size[3] / 2
        expect(wallInner - counterBack >= 2.4).toBe(true)
    end)

    test("THE STAIR STANDS ON THE COUNTER'S BACK EDGE", function()
        -- The owner placed its foot there, so the two are bound: moving the counter has to move
        -- the stair. Derive one from the other in the builder and this stays true for free.
        local counter = find(model, "Counter")
        local tread = find(model, "StairTread1")
        expect(tread ~= nil).toBe(true)
        local counterBack = counter.properties.CFrame[3] + counter.properties.Size[3] / 2
        local treadBack = tread.properties.CFrame[3] + tread.properties.Size[3] / 2
        expect(math.abs(treadBack - counterBack) < 0.001).toBe(true)
    end)

    test("YOU CAN STAND UP AT THE TOP OF THE STAIR", function()
        -- The owner climbed it and their head came out through the roof — in first person you
        -- could see the sky through the ceiling. Nothing in the model was wrong; the attic was
        -- simply shorter than a person, and no test asked.
        --
        -- The roof is a tilted slab, so its underside is a plane rather than a number. Take the
        -- plane from the part's own CFrame and evaluate it where the stair arrives.
        local roof = find(model, "RoofNorth")
        local cf, sz = roof.properties.CFrame, roof.properties.Size
        -- the slab's local +Y in world terms: (r01, r11, r21)
        local ny, nz = cf[8], cf[11]
        local py = cf[2] - (sz[2] / 2) * ny
        local pz = cf[3] - (sz[2] / 2) * nz
        local floor = find(model, "UpperFloorNorth")
        local surface = floor.properties.CFrame[2] + floor.properties.Size[2] / 2
        local stairTopZ = floor.properties.CFrame[3] + floor.properties.Size[3] / 2
        local underside = py - (nz / ny) * (stairTopZ - pz)
        -- 6 studs is the WORKING avatar height: a bare R15 is ~5, hair adds a stud, players wear
        -- hair. Designing to 5 designs for a bald avatar nobody plays.
        expect(underside - surface >= 6.0).toBe(true)
    end)

    test("the attic ties run under the roof, not into it", function()
        -- They sit at the eave line, where the roof is at its LOWEST, and they run the full depth
        -- to both roof edges. So the clearance is smallest at their ends and it is only 0.23 —
        -- any flattening of the pitch drives the roof through the beam, and the beam is inside
        -- the attic where nobody looks until they are standing in it.
        local function underside(part, z)
            local cf, sz = part.properties.CFrame, part.properties.Size
            local ny, nz = cf[8], cf[11]
            local py = cf[2] - (sz[2] / 2) * ny
            local pz = cf[3] - (sz[2] / 2) * nz
            return py - (nz / ny) * (z - pz)
        end
        local north, south = find(model, "RoofNorth"), find(model, "RoofSouth")
        for _, side in { "West", "East" } do
            local t = find(model, "AtticTie" .. side)
            expect(t ~= nil).toBe(true)
            local top = t.properties.CFrame[2] + t.properties.Size[2] / 2
            local z0 = t.properties.CFrame[3] - t.properties.Size[3] / 2
            local z1 = t.properties.CFrame[3] + t.properties.Size[3] / 2
            expect(underside(north, z0) > top).toBe(true)
            expect(underside(south, z1) > top).toBe(true)
        end
    end)

    test("THE STRINGERS REACH THE UPPER FLOOR", function()
        -- They did not, twice over: built from the top TREAD they stopped a whole riser low, and
        -- then, once the top face reached the floor, the SQUARE END still left the corner short of
        -- the well's edge. Both are invisible in the numbers a builder prints and obvious standing
        -- on the landing. So measure the actual corner: transform the part's top-face, high-end
        -- corner out of its own CFrame and demand it land on the floor edge.
        local floorY, wellNorth
        for _, c in model.children do
            if c.name == "UpperFloorNorth" then
                floorY = c.properties.CFrame[2] + c.properties.Size[2] / 2
                wellNorth = c.properties.CFrame[3] + c.properties.Size[3] / 2
            end
        end
        for _, side in { "West", "East" } do
            local s = find(model, "StairStringer" .. side)
            expect(s ~= nil).toBe(true)
            local cf, sz = s.properties.CFrame, s.properties.Size
            -- row-major: rows are cf[4..6], cf[7..9], cf[10..12]
            local ly, lz = sz[2] / 2, -sz[3] / 2 -- top face, high (-Z) end
            local y = cf[2] + cf[8] * ly + cf[9] * lz
            local z = cf[3] + cf[11] * ly + cf[12] * lz
            expect(math.abs(y - floorY) < 0.01).toBe(true)
            expect(math.abs(z - wellNorth) < 0.01).toBe(true)
            -- AND THE FOOT IS IN THE FLOOR. The same square-cut arithmetic at the other end was
            -- left undone, so both stringers hovered an eighth of a stud above the boards. A
            -- joint that merely touches shows a seam; this one has to be buried.
            local lo = cf[2] + cf[8] * (-sz[2] / 2) + cf[9] * (sz[3] / 2)
            expect(lo < FLOOR - 0.1).toBe(true)
        end
    end)

    test("the stair timber does not wear the VERTICAL grain variant", function()
        -- CypressVertical's maps are rotated 90° and it exists for flat vertical members. On a
        -- tread — a horizontal board — it runs the grain across the plank instead of along it.
        for _, c in model.children do
            local n = c.name :: string
            if n:sub(1, 10) == "StairTread" or n:sub(1, 13) == "StairStringer" then
                expect(c.properties.MaterialVariant).toBe("CypressWeathered")
            end
        end
    end)

    test("THE STAIRWELL IS CUT WHERE THE STAIR NEEDS IT", function()
        -- The whole point of an opening. Walk every tread and check the column of air above it —
        -- one working avatar tall — against every piece of upper floor. A stair that climbs into
        -- its own ceiling looks completely correct in the explorer and is unusable in Play.
        local treads, floors = {}, {}
        for _, c in model.children do
            local n = c.name :: string
            if n:sub(1, 10) == "StairTread" then
                table.insert(treads, c)
            elseif n:sub(1, 10) == "UpperFloor" then
                table.insert(floors, c)
            end
        end
        expect(#treads >= 8).toBe(true)
        expect(#floors >= 2).toBe(true) -- an uncut single slab cannot pass this test
        for _, t in treads do
            local tp, ts = t.properties.CFrame, t.properties.Size
            local headLo = tp[2] + ts[2] / 2
            local headHi = headLo + 6.0
            for _, f in floors do
                local fp, fs = f.properties.CFrame, f.properties.Size
                local overlaps = math.abs(tp[1] - fp[1]) < (ts[1] + fs[1]) / 2 - 0.001
                    and math.abs(tp[3] - fp[3]) < (ts[3] + fs[3]) / 2 - 0.001
                    and fp[2] + fs[2] / 2 > headLo + 0.001
                    and fp[2] - fs[2] / 2 < headHi - 0.001
                expect(overlaps).toBe(false)
            end
        end
    end)

    test("THE FLANK BAYS ARE EQUAL, whatever the depth", function()
        -- The owner's gate was against an IRREGULAR rhythm (bays of 2.2 / 2.6 / 1.9), not against
        -- a count. So the module is what is fixed: deepening the shop adds bays, it does not
        -- stretch them. Collect the upper storey's posts, which carry the whole flank grid.
        local zs = {}
        for _, c in model.children do
            if (c.name :: string):sub(1, 17) == "SideUpperPostWest" then
                table.insert(zs, c.properties.CFrame[3])
            end
        end
        table.sort(zs)
        expect(#zs >= 3).toBe(true)
        local first = zs[2] - zs[1]
        for i = 2, #zs - 1 do
            expect(math.abs((zs[i + 1] - zs[i]) - first) < 0.001).toBe(true)
        end
        -- and the module itself holds, so a deeper shop reads at the same grain as a shallow one
        expect(math.abs(first - 4.0) < 0.6).toBe(true)
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
        for _, c in allParts(model) do
            if (c.name :: string):sub(1, 3) == "Seg" then
                expect(c.properties.CanCollide).toBe(false)
                expect(c.properties.Tags[1]).toBe("NorenSeg")
            end
        end
    end)

    test("EACH NOREN PANEL IS A JOINED CHAIN", function()
        -- A panel is segments hung end to end so it can bend. If a segment's top does not sit
        -- exactly on the one above, the panel comes apart — and it comes apart WORSE once the
        -- client sways it, because the sway walks the same chain from the same hinge. Both the
        -- rest pose and the animation depend on this holding.
        local panels = 0
        for _, m in model.children do
            if (m.name :: string):sub(1, 5) ~= "Noren" or not m.children then
                continue
            end
            panels += 1
            local segs = m.children
            expect(#segs >= 2).toBe(true)
            for s = 1, #segs - 1 do
                local a, b = segs[s], segs[s + 1]
                expect(a.name).toBe("Seg" .. s)
                local ah = a.properties.Size[2] / 2
                local bh = b.properties.Size[2] / 2
                -- a's bottom-centre, then b's top-centre, both out of their own CFrames
                local ay = a.properties.CFrame[2] + a.properties.CFrame[8] * -ah
                local az = a.properties.CFrame[3] + a.properties.CFrame[11] * -ah
                local by = b.properties.CFrame[2] + b.properties.CFrame[8] * bh
                local bz = b.properties.CFrame[3] + b.properties.CFrame[11] * bh
                expect(math.abs(ay - by) < 1e-6).toBe(true)
                expect(math.abs(az - bz) < 1e-6).toBe(true)
            end
        end
        expect(panels >= 3).toBe(true)
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

    test("the sign is one framed board, lettered ONE CHARACTER PER LABEL", function()
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
        -- One TextLabel per character (the owner's signage pass): the packed
        -- single-label run set the three kanji touching, and no Roblox font can
        -- space a CJK run — all 53 Enum.Font values fall through to one system
        -- fallback with identical metrics, so the CELLS are the only spacing
        -- control that exists.
        local chars = { "花", "火", "屋" }
        for i, ch in chars do
            local label = find(face, `Char{i}`)
            expect(label ~= nil).toBe(true)
            expect(label.className).toBe("TextLabel")
            expect(label.properties.Text).toBe(ch)
        end
        expect(find(face, "Char4") == nil).toBe(true)
        expect(find(face, "Text") == nil).toBe(true)
    end)

    test("and the characters sit WIDER than the packed single-label run did", function()
        -- The measured fallback metric: three kanji at size 48 run 99px — a 33px
        -- advance per character, so at TextSize 72 on a 32 px-per-stud canvas the
        -- old packed run advanced (33/48)*72/32 = 1.546875 studs centre to centre.
        -- "Slightly more spacing" is the owner's request; the per-character cells
        -- must clearly beat the packed advance.
        local k = find(model, "Kanban")
        local face = find(k, "Face")
        local centres = {}
        for i = 1, 3 do
            local label = find(face, `Char{i}`)
            local pos = label.properties.Position.UDim2
            local size = label.properties.Size.UDim2
            centres[i] = (pos[1][1] + size[1][1] / 2) * k.properties.Size[1]
            -- horizontal layout: every cell sits at the same height
            expect(pos[2][1]).toBe(0)
        end
        local packedAdvance = (33 / 48) * 72 / 32
        for i = 1, 2 do
            expect(centres[i + 1] - centres[i] > packedAdvance + 0.3).toBe(true)
        end
    end)

    test("the sign's letters CONTRAST with its board, in a frame on all four sides", function()
        local k = find(model, "Kanban")
        local text = find(find(k, "Face"), "Char1")
        -- Either polarity is fine — the sign began as dark ink on a light board and is now pale
        -- characters on dark wood. What is NOT fine is the two drifting together, which is the
        -- kind of thing that survives review because both values look reasonable on their own.
        local panelLum = k.properties.Color[1] + k.properties.Color[2] + k.properties.Color[3]
        local inkLum = text.properties.TextColor3[1]
            + text.properties.TextColor3[2]
            + text.properties.TextColor3[3]
        expect(math.abs(panelLum - inkLum) > 1).toBe(true)
        expect(countPrefix(model, "KanbanFrame")).toBe(4)
        -- Sized to the CHARACTERS, not to the building. At 0.62 of the frontage the name floated
        -- in the middle of a half-empty board; three glyphs want roughly 3:1.
        expect(k.properties.Size[1] / k.properties.Size[2] < 3.6).toBe(true)
    end)

    test("the shopfront opens in the MIDDLE, with the outer two bays walled", function()
        -- A machiya front is not open end to end. Five bays: the outer two are plastered infill,
        -- the middle three are the shop. Counting parts alone would let a future edit close the
        -- wrong two and still pass, so this checks WHICH bays are closed by position.
        -- EVERY BAY IS EITHER OPEN OR CLOSED — stated as an invariant rather than as two magic
        -- numbers, so changing the post count moves both sides together instead of failing.
        local posts = countPrefix(model, "FrontPost")
        local closed = countPrefix(model, "BayPanel")
        local open = countPrefix(model, "DoorLeaf")
        expect(closed + open).toBe(posts - 1)
        expect(closed).toBe(2) -- the outer two, whatever the post count
        -- NOT countPrefix("Transom"): that also catches the TransomBar lattice.
        expect(countPrefix(model, "Transom") - countPrefix(model, "TransomBar")).toBe(open)

        local panels, doors = {}, {}
        for _, c in model.children do
            local n = c.name :: string
            if n:sub(1, 8) == "BayPanel" then
                table.insert(panels, c.properties.CFrame[1])
            elseif n:sub(1, 8) == "DoorLeaf" then
                table.insert(doors, c.properties.CFrame[1])
            end
        end
        table.sort(panels)
        table.sort(doors)
        -- every closed panel sits OUTSIDE every door: the walls are the ends, not the middle
        expect(panels[1] < doors[1]).toBe(true)
        expect(panels[2] > doors[#doors]).toBe(true)
    end)

    test("and the doors in those middle bays stand OPEN", function()
        -- Open is the point: screens pushed aside, not a hole and not a wall.
        --
        -- MEASURED AS OVERLAP, NOT AS WIDTH. The leaf is now the full width of its bay and is SLID
        -- two-thirds away, so width alone says it covers everything while the bay is actually
        -- clear. What matters is how much of the opening the leaf still sits in front of.
        for _, c in model.children do
            local n = c.name :: string
            if n:sub(1, 7) == "Transom" and n:sub(1, 10) ~= "TransomBar" then
                local bayC, bayW = c.properties.CFrame[1], c.properties.Size[1]
                local leaf = find(model, "DoorLeaf" .. n:sub(8))
                expect(leaf ~= nil).toBe(true)
                local lc, lw = leaf.properties.CFrame[1], leaf.properties.Size[1]
                local overlap = math.max(
                    0,
                    math.min(bayC + bayW / 2, lc + lw / 2) - math.max(bayC - bayW / 2, lc - lw / 2)
                )
                expect(overlap < bayW * 0.40).toBe(true)
            end
        end
    end)

    test("the upper storey is a WALL with a window, not a row of bars", function()
        -- It shipped as lattice with nothing behind it, so you could see straight through the
        -- upper floor from the street. A machiya's upper front is plaster with one banded
        -- opening — the kōshi fills the window, it does not stand in for the wall.
        expect(countPrefix(model, "UpperWallFront")).toBe(4)
        local koshi, win = {}, nil
        for _, c in model.children do
            local n = c.name :: string
            if n:sub(1, 5) == "Koshi" then
                table.insert(koshi, c)
            elseif n == "UpperWallFrontWest" then
                win = c
            end
        end
        expect(#koshi > 0).toBe(true)
        -- every bar sits inboard of the west jamb's inner face: the lattice is IN the opening
        local jambInner = win.properties.CFrame[1] + win.properties.Size[1] / 2
        for _, k in koshi do
            expect(k.properties.CFrame[1] >= jambInner - 0.001).toBe(true)
        end
    end)
end)

describe("Machiya — the stucco box", function()
    -- THE TEST THIS BUILDING KEPT NEEDING. The render is ONE inset box, and it came apart twice by
    -- being nudged a panel at a time: side walls moved in by the setback while the front, the back
    -- and the gables still spanned the full envelope — each panel inset on its own axis and
    -- oversized on every other. Neither failure was visible to any test, only to the owner's eye.
    local S = 0.30
    local SX0, SX1 = X0 + S, X1 - S
    local SZ0, SZ1 = Z0 + S, Z1 - S

    local BOX = {
        { "WallWest", 1 },
        { "WallEast", 1 },
        { "WallBack", 3 },
        { "UpperWallWest", 1 },
        { "UpperWallEast", 1 },
        { "UpperWallBack", 3 },
        { "UpperWallFrontLow", 1 },
        { "UpperWallFrontHigh", 1 },
        { "GableWestNorth", 1 },
        { "GableEastNorth", 1 },
    }

    test("NO RENDER PANEL REACHES PAST THE BOX", function()
        for _, e in BOX do
            local part = find(model, e[1] :: string)
            expect(part ~= nil).toBe(true)
            local ax = e[2] :: number
            local c, w = part.properties.CFrame[ax], part.properties.Size[ax]
            local lo, hi = c - w / 2, c + w / 2
            local limLo = if ax == 1 then SX0 else SZ0
            local limHi = if ax == 1 then SX1 else SZ1
            expect(lo >= limLo - 0.001).toBe(true)
            expect(hi <= limHi + 0.001).toBe(true)
        end
    end)

    test("and no timber post is BURIED in the panel behind it", function()
        -- The other half of the same rule. A post enclosed by its own wall is invisible, which is
        -- how the upper storey shipped with a frame nobody could see.
        local pairs_ = {
            { "SidePostWest1", "WallWest", 1, -1 },
            { "SideUpperPostWest1", "UpperWallWest", 1, -1 },
            { "SidePostEast1", "WallEast", 1, 1 },
            { "SideUpperPostEast1", "UpperWallEast", 1, 1 },
        }
        for _, e in pairs_ do
            local post, wall = find(model, e[1] :: string), find(model, e[2] :: string)
            expect(post ~= nil).toBe(true)
            expect(wall ~= nil).toBe(true)
            local ax, dir = e[3] :: number, e[4] :: number
            local pc, pw = post.properties.CFrame[ax], post.properties.Size[ax]
            local wc, ww = wall.properties.CFrame[ax], wall.properties.Size[ax]
            local proud = if dir < 0 then (wc - ww / 2) - (pc - pw / 2) else (pc + pw / 2) - (wc + ww / 2)
            expect(proud > 0.05).toBe(true)
        end
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

-- ===== Task 3: the archetype's variants =====
-- A SYNTHETIC shell, deliberately not a surveyed one: these tests hold the archetype's
-- branches (frontage/interior/yaw/identity), not any owner's envelope.
local SHELL = {
    name = "TestShell",
    envelope = { x0 = 0, x1 = 16, z0 = 100, z1 = 113, floorY = 113.10 },
    yaw = 0,
    frontage = "open",
    interior = "shallow",
}
describe("machiya variants", function()
    test("shallow interior emits no stair, no attic, no well", function()
        local m = Machiya.build(ZenDojo.palette, ArenaLayout, SHELL)
        for _, p in allParts(m) do
            expect(string.find(p.name, "Stair") == nil).toBe(true)
            expect(string.find(p.name, "Attic") == nil).toBe(true)
        end
    end)
    test("koshi frontage closes the street wall and opens nothing", function()
        local closed = table.clone(SHELL)
        closed.frontage = "koshi"
        closed.interior = "none"
        local m = Machiya.build(ZenDojo.palette, ArenaLayout, closed :: any)
        local sawKoshi = false
        for _, p in allParts(m) do
            if string.find(p.name, "KoshiFront") then
                sawKoshi = true
            end
            expect(string.find(p.name, "Counter") == nil).toBe(true)
        end
        expect(sawKoshi).toBe(true)
    end)
    test("yaw rotates every part about the envelope centre", function()
        local turned = table.clone(SHELL)
        turned.yaw = 90
        local m0 = Machiya.build(ZenDojo.palette, ArenaLayout, SHELL)
        local m1 = Machiya.build(ZenDojo.palette, ArenaLayout, turned :: any)
        local a = allParts(m0)[1].properties.CFrame
        local b = allParts(m1)[1].properties.CFrame
        -- centre (8, 106.5): x' = cx + (z - cz), z' = cz - (x - cx) for +90°
        expect(b[1]).toBeCloseTo(8 + (a[3] - 106.5), 0.01)
        expect(b[3]).toBeCloseTo(106.5 - (a[1] - 8), 0.01)
    end)
    test("the identity kit dresses a shell, field by field", function()
        local Spec = require("../tools/builders/Spec")
        local kit = table.clone(SHELL)
        kit.identity = {
            noren = { color = { 0.2, 0.2, 0.4 }, segments = 3 },
            chochin = true,
            board = true,
            glow = { color = { 1, 0.8, 0.6 }, brightness = 1.5 },
            dress = function(ctx)
                return {
                    Spec.part("TestProp", {
                        Size = { 1, 1, 1 },
                        CFrame = Spec.cframe({ ctx.env.cx, ctx.env.floorY + 0.5, ctx.env.cz }),
                    }),
                }
            end,
        }
        local m = Machiya.build(ZenDojo.palette, ArenaLayout, kit :: any)
        -- chochin: the eave-corner pair, one model per corner
        expect(find(m, "ChochinWest") ~= nil).toBe(true)
        expect(find(m, "ChochinEast") ~= nil).toBe(true)
        -- noren: the kit's own colour rides the archetype's hang
        expect(find(m, "Noren2_1") ~= nil).toBe(true)
        -- board: 花火屋's framed kanban construction on the upper storey, BLANK —
        -- blank means the panel has no children (no SurfaceGui, no copy)
        local board = find(m, "Kanban")
        expect(board ~= nil).toBe(true)
        expect(board.children == nil or #board.children == 0).toBe(true)
        expect(countPrefix(m, "KanbanFrame")).toBe(4)
        -- glow: the interior lighting hooks exist
        local sawGlow = false
        for _, p in allParts(m) do
            if string.find(p.name, "InteriorGlow_") then
                sawGlow = true
            end
        end
        expect(sawGlow).toBe(true)
        -- dress: its specs land under the Dressing child model, not loose in the shell
        local dressing = find(m, "Dressing")
        expect(dressing ~= nil).toBe(true)
        expect(find(dressing, "TestProp") ~= nil).toBe(true)
        -- and interior "none" suppresses EXACTLY the glow — the rest of the kit stays
        local sealed = table.clone(kit)
        sealed.interior = "none"
        local m2 = Machiya.build(ZenDojo.palette, ArenaLayout, sealed :: any)
        for _, p in allParts(m2) do
            expect(string.find(p.name, "InteriorGlow_") == nil).toBe(true)
        end
        local sealedBoard = find(m2, "Kanban")
        expect(sealedBoard ~= nil).toBe(true)
        expect(sealedBoard.children == nil or #sealedBoard.children == 0).toBe(true)
        expect(find(m2, "ChochinWest") ~= nil).toBe(true)
    end)
    test("frontPosts 3 gives a two-bay front: both bays open, rail spans the frontage", function()
        -- The stats false front's case, held at the archetype level: the post
        -- count is per-shop (default 5), and at 3 posts / 2 bays there are no
        -- outer bays to close and no closed neighbour for a leaf to park behind.
        local narrow = table.clone(SHELL)
        narrow.frontPosts = 3
        local m = Machiya.build(ZenDojo.palette, ArenaLayout, narrow :: any)
        expect(countPrefix(m, "FrontPost")).toBe(3)
        expect(countPrefix(m, "BayPanel")).toBe(0)
        expect(countPrefix(m, "DoorLeaf")).toBe(0)
        expect(countPrefix(m, "Transom") - countPrefix(m, "TransomBar")).toBe(2)
        local hr = find(m, "HeadRail")
        -- corner posts are inset half a post (0.245): the rail spans post 1 to post 3
        expect(hr.properties.Size[1]).toBeCloseTo(16 - 0.49, 0.001)
        expect(hr.properties.CFrame[1]).toBeCloseTo(8, 0.001)
    end)
    test("the DEFAULT post count is untouched: 5 posts, closed ends, parked leaves", function()
        -- the inertness proof's test half — the byte gate on the three committed
        -- model.json assets is the other half
        local m = Machiya.build(ZenDojo.palette, ArenaLayout, SHELL)
        expect(countPrefix(m, "FrontPost")).toBe(5)
        expect(countPrefix(m, "BayPanel")).toBe(2)
        expect(countPrefix(m, "DoorLeaf")).toBe(2)
    end)
    test("koshi + full interior refuses loudly, not with nil arithmetic", function()
        local bad = table.clone(SHELL)
        bad.frontage = "koshi"
        bad.interior = "full"
        local ok, err = pcall(function()
            Machiya.build(ZenDojo.palette, ArenaLayout, bad :: any)
        end)
        expect(ok).toBe(false)
        expect(string.find(tostring(err), "koshi frontage cannot carry the full interior") ~= nil).toBe(true)
    end)
    -- The brief's yaw test reads part [1], which is the FloorSlab — dead on the envelope
    -- centre, so a yaw pass that silently did nothing would still pass it. This one holds
    -- EVERY part, nested noren segments included (the exact class of miss allParts exists
    -- to catch), and checks the rotation matrix turned too.
    test("yaw carries EVERY part, nested noren segments included", function()
        local flat = table.clone(SHELL)
        flat.interior = "full" -- full interior so the nested Noren models exist
        local spun = table.clone(flat)
        spun.yaw = 90
        local m0 = Machiya.build(ZenDojo.palette, ArenaLayout, flat :: any)
        local m1 = Machiya.build(ZenDojo.palette, ArenaLayout, spun :: any)
        -- the nested subject is actually present
        local sawNoren = false
        for _, c in m1.children do
            if string.find(c.name, "Noren") then
                sawNoren = true
            end
        end
        expect(sawNoren).toBe(true)
        local A, B = allParts(m0), allParts(m1)
        expect(#A).toBe(#B)
        local cx, cz = 8, 106.5
        for i, pa in A do
            local ca, cb = pa.properties.CFrame, B[i].properties.CFrame
            expect(cb[1]).toBeCloseTo(cx + (ca[3] - cz), 0.01)
            expect(cb[2]).toBeCloseTo(ca[2], 0.01)
            expect(cb[3]).toBeCloseTo(cz - (ca[1] - cx), 0.01)
            -- rotation: R' = Ry(90) * R, checked on the top row (r00' = -r20, r02' = r22)
            expect(cb[4]).toBeCloseTo(-ca[10], 0.01)
            expect(cb[6]).toBeCloseTo(ca[12], 0.01)
        end
    end)
end)
