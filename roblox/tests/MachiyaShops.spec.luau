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
        -- x0 is NOT the survey's 16.02: it registers to 花火屋's built east face at a
        -- 1.5 roji standoff (see the relationship test below).
        expect(s.envelope.x0).toBe(17.76)
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
        -- the owner's signage pass: MachiyaEast KEEPS the blank wall board —
        -- `board = true` is the blank contract, and naming this shop is
        -- deliberately out of scope (the wager-language ruling)
        expect(s.identity ~= nil and s.identity.board == true).toBe(true)
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

describe("accessories shell", function()
    local m = Machiya.build(ZenDojo.palette, ArenaLayout, MachiyaShops.accessories)
    local parts = allParts(m)
    test("subordinate to the tower", function()
        for _, p in parts do
            local topY = p.properties.CFrame[2] + p.properties.Size[2] / 2
            expect(topY <= ArenaLayout.towerTopY - 9.0).toBe(true)
        end
    end)
    test("has a dressing set and it stays inside the envelope", function()
        local e = MachiyaShops.accessories.envelope
        local d = find(m, "Dressing")
        expect(d ~= nil).toBe(true)
        for _, p in allParts(d) do
            expect(p.properties.CFrame[1] >= e.x0 and p.properties.CFrame[1] <= e.x1).toBe(true)
            expect(p.properties.CFrame[3] >= e.z0 and p.properties.CFrame[3] <= e.z1).toBe(true)
        end
    end)
end)

describe("accessories registers to the built neighbour", function()
    test("west edge is 花火屋's east face plus the 1.5-stud roji", function()
        -- Same stale-massing class the apparel gate caught, mirrored: the surveyed
        -- x0 (16.02) ran 0.24 studs INTO 花火屋's built east face (16.26). The shell
        -- registers to the BUILT edge (derive-from-what-it-touches): east face 16.26,
        -- plus the same 1.5 roji gap — so this drift class fails loudly forever.
        expect(MachiyaShops.accessories.envelope.x0 - 1.5).toBeCloseTo(
            MachiyaShops.hanabiya.envelope.x1,
            0.001
        )
    end)
end)

describe("per-shop noren panel count", function()
    -- The owner's round-1 gate correction on accessories: TWO wider panels per
    -- doorway, not three. perBay is a per-shop identity opt-in; the archetype's
    -- NOREN_PER_BAY default must keep every non-opting shop (花火屋, apparel)
    -- byte-for-byte unchanged — the model.json gates hold that side.
    local function panelsPerBay(m)
        local counts = {}
        for _, c in m.children do
            local bay = string.match(c.name, "^Noren(%d+)_%d+$")
            if bay then
                counts[bay] = (counts[bay] or 0) + 1
            end
        end
        return counts
    end
    test("accessories emits exactly 2 panels per open bay", function()
        local m = Machiya.build(ZenDojo.palette, ArenaLayout, MachiyaShops.accessories)
        local counts = panelsPerBay(m)
        local bays = 0
        for _, n in counts do
            bays += 1
            expect(n).toBe(2)
        end
        expect(bays).toBe(2) -- the open frontage's two doorways
    end)
    test("apparel still emits the default count per open bay", function()
        local m = Machiya.build(ZenDojo.palette, ArenaLayout, MachiyaShops.apparel)
        local counts = panelsPerBay(m)
        local bays = 0
        for _, n in counts do
            bays += 1
            expect(n).toBe(3)
        end
        expect(bays).toBe(2)
    end)
end)

-- Rotation-aware world AABB of a part spec: |R| * size / 2 about the centre.
-- Hoisted from the round-2 occlusion guard so every signage test shares it.
local function rotAABB(p)
    local cf, sz = p.properties.CFrame, p.properties.Size
    local lo, hi = {}, {}
    for i = 1, 3 do
        local r = 3 * (i - 1)
        local ext = (math.abs(cf[4 + r]) * sz[1] + math.abs(cf[5 + r]) * sz[2] + math.abs(cf[6 + r]) * sz[3])
            / 2
        lo[i], hi[i] = cf[i] - ext, cf[i] + ext
    end
    return lo, hi
end

describe("signage — apparel's sode-kanban (blade sign)", function()
    local shop = MachiyaShops.apparel
    local e = shop.envelope
    local m = Machiya.build(ZenDojo.palette, ArenaLayout, shop)
    local blade = find(m, "SodeKanban")

    test("the blade REPLACES the wall kanban", function()
        expect(blade ~= nil).toBe(true)
        expect(find(m, "Kanban") == nil).toBe(true)
        local frames = 0
        for _, c in m.children do
            if (c.name :: string):sub(1, 11) == "KanbanFrame" then
                frames += 1
            end
        end
        expect(frames).toBe(0)
    end)

    test("it stands PERPENDICULAR to the facade, projecting into the street", function()
        local board = find(blade, "BladeBoard")
        expect(board ~= nil).toBe(true)
        -- thin in x: the board's faces look east/west, down the promenade
        expect(board.properties.Size[1] < 0.3).toBe(true)
        expect(board.properties.Size[2] >= 3.5).toBe(true)
        -- wholly north of the upper wall's street face (the stucco box at z0 + 0.30)
        local plo, phi = rotAABB(board)
        expect(phi[3] <= e.z0 + 0.30 + 1e-6).toBe(true)
        -- and inside the eave's own drip line: no NEW promenade encroachment
        expect(plo[3] >= e.z0 - 2.5).toBe(true)
    end)

    test("its lettering is VERTICAL — one label per character, descending, both faces", function()
        local board = find(blade, "BladeBoard")
        local chars = { "呉", "服", "屋" }
        for _, fname in { "FaceEast", "FaceWest" } do
            local face = find(board, fname)
            expect(face ~= nil).toBe(true)
            expect(face.properties.SizingMode).toBe("PixelsPerStud")
            local prevY = -1
            for i, ch in chars do
                local label = find(face, `Char{i}`)
                expect(label ~= nil).toBe(true)
                expect(label.properties.Text).toBe(ch)
                local pos = label.properties.Position.UDim2
                expect(pos[1][1]).toBe(0) -- one column
                expect(pos[2][1] > prevY).toBe(true) -- reading DOWN: tategaki
                prevY = pos[2][1]
            end
            expect(find(face, "Char4") == nil).toBe(true)
        end
    end)

    test("gold on black lacquer: light characters on a dark board", function()
        local board = find(blade, "BladeBoard")
        local label = find(find(board, "FaceEast"), "Char1")
        local panel = board.properties.Color
        local inkC = label.properties.TextColor3
        local diff = (inkC[1] + inkC[2] + inkC[3]) - (panel[1] + panel[2] + panel[3])
        expect(diff > 1).toBe(true)
    end)

    test("it clears the avatar, the hisashi and the roof spring", function()
        local eave = find(m, "Eave")
        local _, ehi = rotAABB(eave)
        for _, p in allParts(blade) do
            local plo, phi = rotAABB(p)
            -- the WHOLE blade lives above the hisashi: open air, nothing occluded
            expect(plo[2] > ehi[2]).toBe(true)
            -- and under the main roof's spring line (floor + storeys = +14)
            expect(phi[2] < e.floorY + 14.0 - 0.1).toBe(true)
        end
        -- the kamoi rule restated for the street: the underside never dips
        -- below the shop's own 6.8 head clearance
        local board = find(blade, "BladeBoard")
        local blo = rotAABB(board)
        expect(blo[2] >= e.floorY + 6.8).toBe(true)
    end)
end)

describe("signage — accessories' kake-kanban (hanging plaque)", function()
    local shop = MachiyaShops.accessories
    local e = shop.envelope
    local m = Machiya.build(ZenDojo.palette, ArenaLayout, shop)
    local kk = find(m, "KakeKanban")
    local plaque = kk and find(kk, "Plaque")

    test("the plaque REPLACES the wall kanban", function()
        expect(kk ~= nil).toBe(true)
        expect(plaque ~= nil).toBe(true)
        expect(find(m, "Kanban") == nil).toBe(true)
        local frames = 0
        for _, c in m.children do
            if (c.name :: string):sub(1, 11) == "KanbanFrame" then
                frames += 1
            end
        end
        expect(frames).toBe(0)
    end)

    test("it hangs UNDER the eave with real air, above head height", function()
        local eave = find(m, "Eave")
        local elo = rotAABB(eave)
        local plo, phi = rotAABB(plaque)
        -- clear even of the eave's LOWEST (outer) corner — the occlusion-guard
        -- defect class, restated for a sign that belongs under the soffit
        expect(phi[2] + 0.05 < elo[2]).toBe(true)
        -- the kamoi head-height rule: 6.8 above the floor, same as the doorway
        expect(plo[2] >= e.floorY + 6.8).toBe(true)
        -- under the eave: never back over the frontage line, never past the drip
        expect(phi[3] < e.z0).toBe(true)
        expect(plo[3] > e.z0 - 2.5).toBe(true)
    end)

    test("its hooks VISIBLY bridge the plaque to the eave's underside plane", function()
        local pTop = plaque.properties.CFrame[2] + plaque.properties.Size[2] / 2
        -- the eave's underside is a tilted PLANE: springs at floor + 9, drops 0.5
        -- over the 2.5 overhang, minus the slab's vertical half-thickness — the
        -- same math the chōchin hang derives its arm height from
        local hisashiLen = math.sqrt(2.5 * 2.5 + 0.5 * 0.5)
        for _, hn in { "PlaqueHookWest", "PlaqueHookEast" } do
            local h = find(kk, hn)
            expect(h ~= nil).toBe(true)
            local hBot = h.properties.CFrame[2] - h.properties.Size[2] / 2
            local hTop = h.properties.CFrame[2] + h.properties.Size[2] / 2
            local hz = h.properties.CFrame[3]
            local underside = e.floorY + 9.0 - 0.5 * (e.z0 - hz) / 2.5 - (0.25 / 2) * (hisashiLen / 2.5)
            expect(math.abs(hBot - pTop) < 0.01).toBe(true) -- seated on the plaque
            expect(math.abs(hTop - underside) < 0.02).toBe(true) -- reaching the soffit
        end
    end)

    test("horizontal per-character lettering — 小間物屋, one label each", function()
        local face = find(plaque, "Face")
        expect(face ~= nil).toBe(true)
        expect(face.properties.SizingMode).toBe("PixelsPerStud")
        local chars = { "小", "間", "物", "屋" }
        local prevX = -1
        for i, ch in chars do
            local label = find(face, `Char{i}`)
            expect(label ~= nil).toBe(true)
            expect(label.properties.Text).toBe(ch)
            local pos = label.properties.Position.UDim2
            expect(pos[2][1]).toBe(0) -- one row
            expect(pos[1][1] > prevX).toBe(true) -- reading east: yokogaki
            prevX = pos[1][1]
        end
        expect(find(face, "Char5") == nil).toBe(true)
    end)

    test("sumi on bare cedar: dark characters on a light board", function()
        local label = find(find(plaque, "Face"), "Char1")
        local panel = plaque.properties.Color
        local inkC = label.properties.TextColor3
        local diff = (panel[1] + panel[2] + panel[3]) - (inkC[1] + inkC[2] + inkC[3])
        expect(diff > 1).toBe(true)
    end)
end)

describe("signage — full-extent audit: the signs touch NOTHING they don't mount to", function()
    -- Rotation-aware AABB of every sign part against every other part of its own
    -- building — eave, roof, walls, noren, chōchin, dressing, all of it. The 1e-4
    -- tolerance admits the deliberate flush contacts (the blade arms' rear faces
    -- sit ON the upper wall's street face). The plaque's hooks are its hangers
    -- and are ALLOWED to meet the Eave — the one excluded pair; the plane test
    -- above pins the hook tops to the underside so "allowed to meet" can never
    -- drift into "buried".
    local function auditClear(m, signName, allowed)
        local sign = find(m, signName)
        expect(sign ~= nil).toBe(true)
        local signParts = allParts(sign)
        expect(#signParts > 0).toBe(true)
        local inSign = {}
        for _, p in signParts do
            inSign[p] = true
        end
        local worst = -math.huge
        for _, sp in signParts do
            local slo, shi = rotAABB(sp)
            for _, op in allParts(m) do
                if not inSign[op] and not (allowed and allowed[sp.name] == op.name) then
                    local olo, ohi = rotAABB(op)
                    local pen = math.huge
                    for ax = 1, 3 do
                        pen = math.min(pen, math.min(shi[ax], ohi[ax]) - math.max(slo[ax], olo[ax]))
                    end
                    if pen > worst then
                        worst = pen
                    end
                end
            end
        end
        expect(worst <= 1e-4).toBe(true)
    end
    test("apparel's blade", function()
        local m = Machiya.build(ZenDojo.palette, ArenaLayout, MachiyaShops.apparel)
        auditClear(m, "SodeKanban", nil)
    end)
    test("accessories' plaque", function()
        local m = Machiya.build(ZenDojo.palette, ArenaLayout, MachiyaShops.accessories)
        auditClear(m, "KakeKanban", { PlaqueHookWest = "Eave", PlaqueHookEast = "Eave" })
    end)
end)

describe("signage — MachiyaEast stays deliberately blank", function()
    test("a blank childless wall board, framed, hanging in open air", function()
        local m = Machiya.build(ZenDojo.palette, ArenaLayout, MachiyaShops.sportsbook)
        local k = find(m, "Kanban")
        expect(k ~= nil).toBe(true)
        expect(k.children == nil or #k.children == 0).toBe(true)
        local frames = 0
        for _, c in m.children do
            if (c.name :: string):sub(1, 11) == "KanbanFrame" then
                frames += 1
            end
        end
        expect(frames).toBe(4)
        -- the round-2 wall-board occlusion guard, kept for every wall kind: the
        -- panel's full rotation-aware extent must not intersect the Eave's in
        -- y AND z, and its bottom must clear the Eave's top — open air
        local eave = find(m, "Eave")
        local plo, phi = rotAABB(k)
        local elo, ehi = rotAABB(eave)
        local yOverlap = phi[2] > elo[2] and ehi[2] > plo[2]
        local zOverlap = phi[3] > elo[3] and ehi[3] > plo[3]
        expect(yOverlap and zOverlap).toBe(false)
        expect(plo[2] > ehi[2]).toBe(true)
    end)
end)
