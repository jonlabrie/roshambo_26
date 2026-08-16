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

    test("stats carries the owner-approved two-bay envelope", function()
        local s = MachiyaShops.stats
        expect(s ~= nil).toBe(true)
        expect(s.name).toBe("MachiyaStats")
        expect(s.envelope.x0).toBe(-33.92)
        expect(s.envelope.x1).toBe(-23.92)
        expect(s.envelope.z0).toBe(35.23)
        expect(s.envelope.z1).toBe(43.23)
        expect(s.envelope.floorY).toBe(113.30)
        expect(s.yaw).toBe(0)
        expect(s.frontage).toBe("open")
        expect(s.interior).toBe("shallow")
        -- the archetype's per-shop post count: 3 posts, 2 bays — a small false front
        expect(s.frontPosts).toBe(3)
        -- the sign reads 番付 — banzuke, the Edo ranking list: literally a
        -- leaderboard, carrying no wagering sense
        expect(s.identity.board.kind).toBe("wall")
        expect(s.identity.board.text).toBe("番付")
        expect(s.identity.noren.mon).toBe("番")
    end)

    test("the Machiya_East siting is dropped — no registry entry keeps it", function()
        -- Owner's ruling 2026-08-15: the shell was re-sited west of apparel; the
        -- old entry was RENAMED and re-sited, not left as a stale dead sibling.
        expect((MachiyaShops :: any).sportsbook == nil).toBe(true)
        for _, shop in MachiyaShops :: any do
            if type(shop) == "table" and shop.envelope then
                expect(shop.name == "MachiyaEast").toBe(false)
                expect(shop.envelope.x0 == 63.57).toBe(false)
            end
        end
    end)
end)

describe("stats registers to the built neighbour", function()
    test("east edge is apparel's west face minus the 1.5-stud roji", function()
        -- The same relationship the row's other two neighbour tests pin: the
        -- shell registers to the BUILT edge (derive-from-what-it-touches) at the
        -- row's own 1.5 roji — so this drift class fails loudly forever.
        expect(MachiyaShops.stats.envelope.x1 + 1.5).toBeCloseTo(MachiyaShops.apparel.envelope.x0, 0.001)
    end)
    test("the street line is continuous: z0 and floorY ride apparel's", function()
        expect(MachiyaShops.stats.envelope.z0).toBe(MachiyaShops.apparel.envelope.z0)
        expect(MachiyaShops.stats.envelope.floorY).toBe(MachiyaShops.apparel.envelope.floorY)
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
                -- the Threshold is the shop's invisible trigger VOLUME, deliberately
                -- spanning the whole floor to the eave line — customers stand inside
                -- it; it is not geometry, so standing in it is not a collision
                if op.name == "Threshold" then
                    continue
                end
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
    test("apparel's nobori", function()
        local m = Machiya.build(ZenDojo.palette, ArenaLayout, MachiyaShops.apparel)
        auditClear(m, "Nobori", nil)
    end)
    test("accessories' plaque", function()
        local m = Machiya.build(ZenDojo.palette, ArenaLayout, MachiyaShops.accessories)
        auditClear(m, "KakeKanban", { PlaqueHookWest = "Eave", PlaqueHookEast = "Eave" })
    end)
end)

describe("signage — apparel's nobori (the blade was an anachronism)", function()
    -- Owner gate, round 3: a high perpendicular blade reads Shōwa, not Edo/Meiji —
    -- period signage sat at human level and the tsushi-nikai was not display space.
    -- The replacement is a 幟: a cloth banner on a pole at the shop mouth, 呉服屋
    -- running down it — a cloth merchant advertising with cloth.
    local shop = MachiyaShops.apparel
    local e = shop.envelope
    local m = Machiya.build(ZenDojo.palette, ArenaLayout, shop)
    local nobori = find(m, "Nobori")

    test("the nobori REPLACES the blade outright — no blade, no wall kanban", function()
        expect(nobori ~= nil).toBe(true)
        expect(find(m, "SodeKanban") == nil).toBe(true)
        expect(find(m, "Kanban") == nil).toBe(true)
    end)

    test("pole, top bar, base and ties: the banner's rig is all there", function()
        expect(find(nobori, "NoboriPole") ~= nil).toBe(true)
        expect(find(nobori, "NoboriBase") ~= nil).toBe(true)
        local bar = find(nobori, "NoboriBar")
        expect(bar ~= nil).toBe(true)
        -- the bar runs ALONG Z (holding the cloth's top edge), not across the street
        local blo, bhi = rotAABB(bar)
        expect(bhi[3] - blo[3] > bhi[1] - blo[1]).toBe(true)
        expect(bhi[3] - blo[3] > bhi[2] - blo[2]).toBe(true)
        -- ring/tie attachments down the pole side, riding the chain's own joints
        local ties = 0
        for _, c in nobori.children do
            if (c.name :: string):sub(1, 9) == "NoboriTie" then
                ties += 1
            end
        end
        expect(ties >= 2).toBe(true)
    end)

    test("the cloth is a JOINED CHAIN, one character per segment, lettered both faces", function()
        -- same invariant as the noren chain test: each segment's top sits exactly
        -- on the bottom of the one above, whatever the lean, so the cloth bends
        -- instead of tearing — and 呉/服/屋 ride the segments top to bottom
        local chars = { "呉", "服", "屋" }
        local prevBottom = nil
        for i, ch in chars do
            local seg = find(nobori, `Seg{i}`)
            expect(seg ~= nil).toBe(true)
            local cf, sz = seg.properties.CFrame, seg.properties.Size
            local hh = sz[2] / 2
            -- up vector from the rotation columns: (r01, r11, r21)
            local top = { cf[1] + cf[5] * hh, cf[2] + cf[8] * hh, cf[3] + cf[11] * hh }
            local bottom = { cf[1] - cf[5] * hh, cf[2] - cf[8] * hh, cf[3] - cf[11] * hh }
            if prevBottom then
                for ax = 1, 3 do
                    expect(math.abs(top[ax] - prevBottom[ax]) < 1e-6).toBe(true)
                end
            end
            prevBottom = bottom
            for _, fname in { "FaceEast", "FaceWest" } do
                local face = find(seg, fname)
                expect(face ~= nil).toBe(true)
                local label = find(face, "Char1")
                expect(label ~= nil).toBe(true)
                expect(label.properties.Text).toBe(ch)
            end
            -- reading DOWN: each segment sits below the one before
            if i > 1 then
                local prev = find(nobori, `Seg{i - 1}`)
                expect(seg.properties.CFrame[2] < prev.properties.CFrame[2]).toBe(true)
            end
        end
        expect(find(nobori, "Seg4") == nil).toBe(true)
    end)

    test("still-air BY DESIGN: the cloth is not tagged for NorenSway", function()
        -- NorenSway rebuilds each tagged segment's orientation as
        -- CFrame.Angles(rx, 0, az) from the X-euler alone — it assumes yaw-0
        -- street-facing noren panels. These segments face east/west and lean about
        -- Z, so adoption would need the client script to learn to preserve yaw —
        -- a client-script change, which is its own gate. Until then, tagging them
        -- would SNAP the cloth flat on the first frame, so they ship untagged.
        for i = 1, 3 do
            local seg = find(nobori, `Seg{i}`)
            expect(seg.properties.Tags == nil).toBe(true)
        end
    end)

    test("it stands OUT FRONT — beyond the drip line, flanking its own shopfront", function()
        -- Round-4 rule clarification (owner, verbatim: the promenade "isn't
        -- exactly 'inviolable' when it comes to e.g. signage — it's simply not
        -- someplace we want to place buildings"). So the banner stands ON the
        -- promenade where it can be seen — but BEYOND the eave's drip line
        -- (z0 - 2.5), never under the soffit: a banner tucked under an overhang
        -- has the first kanban's exact defect. In x it stays inside its own
        -- frontage: flanking its shopfront, not a neighbour's.
        for _, p in allParts(nobori) do
            local plo, phi = rotAABB(p)
            expect(phi[3] <= e.z0 - 2.5 - 0.15).toBe(true) -- beyond the drip, with air
            expect(plo[1] >= e.x0).toBe(true)
            expect(phi[1] <= e.x1).toBe(true)
        end
        -- grounded at the surveyed front grade (the NW front probe, 113.30),
        -- with a tenth of a stud buried against local grade variance
        local base = find(nobori, "NoboriBase")
        local blo = rotAABB(base)
        expect(math.abs(blo[2] - (e.floorY - 0.1)) < 0.01).toBe(true)
    end)

    test("NOTHING shares its footprint — no eave, hisashi or chōchin above it", function()
        -- the first kanban's defect, inverted into a guard: open sky. No other
        -- part of the building may overlap the banner in x AND z at all — which
        -- proves nothing overhangs it (the eave ends at the drip line it stands
        -- beyond; the corner chōchin is west of it).
        local nParts = allParts(nobori)
        local inSign = {}
        for _, p in nParts do
            inSign[p] = true
        end
        for _, sp in nParts do
            local slo, shi = rotAABB(sp)
            for _, op in allParts(m) do
                if not inSign[op] and op.name ~= "Threshold" then
                    local olo, ohi = rotAABB(op)
                    local xOverlap = math.min(shi[1], ohi[1]) - math.max(slo[1], olo[1]) > 1e-4
                    local zOverlap = math.min(shi[3], ohi[3]) - math.max(slo[3], olo[3]) > 1e-4
                    expect(xOverlap and zOverlap).toBe(false)
                end
            end
        end
    end)

    test("both doorways and the hugging lane stay clear", function()
        -- doorways: the open bays span the frontage's middle; the banner fronts
        -- the CLOSED west bay and must not reach the westmost opening's edge
        local doorwayWestEdge = -17.6075 + 0.245 -- post2's east face, bay 2's west jamb
        local lane = math.huge
        for _, p in allParts(nobori) do
            local plo, phi = rotAABB(p)
            expect(phi[1] < doorwayWestEdge - 0.5).toBe(true)
            -- the walking lane hugging the frontage: banner stand to the
            -- frontage plane, measured at ground level (colliding parts only —
            -- the cloth is walk-through, and hangs aerial anyway)
            if p.properties.CanCollide ~= false then
                lane = math.min(lane, e.z0 - phi[3])
            end
        end
        expect(lane >= 2.5).toBe(true)
    end)
end)

describe("shop mon — 丸に文字 on every noren", function()
    -- The owner's ruling: the crest was arguably the era's primary shop
    -- identifier. A ring enclosing one kanji, resist-dyed white, riding the
    -- cloth: it lives INSIDE the swaying segment as its SurfaceGui, so the
    -- segment's own CFrame — the one NorenSway animates — is literally the
    -- transform that carries it.
    -- monPanelByBay: which panel of each open bay carries the crest. Odd counts
    -- centre it; accessories' even pair FLANKS THE CENTRAL POST (owner, round
    -- 4): bay 2's east panel and bay 3's west panel, a matched set across the
    -- post between the doorways. diaPx pins the grown ring sizes (round 4:
    -- apparel's noren dropped to 4 segments so its ring could take the taller
    -- segment's allowance).
    local CASES = {
        {
            key = "hanabiya",
            char = "花",
            nPanels = 3,
            nSegs = 3,
            monPanelByBay = { ["2"] = 2, ["3"] = 2 },
            diaPx = 89,
        },
        {
            key = "apparel",
            char = "呉",
            nPanels = 3,
            nSegs = 4,
            monPanelByBay = { ["2"] = 2, ["3"] = 2 },
            diaPx = 74,
        },
        {
            key = "accessories",
            char = "小",
            nPanels = 2,
            nSegs = 4,
            monPanelByBay = { ["2"] = 2, ["3"] = 1 },
            diaPx = 74,
        },
        -- stats: both bays of the two-bay front are open, so the doorways are
        -- bays 1 and 2; odd panel count centres the crest on each middle panel
        {
            key = "stats",
            char = "番",
            nPanels = 3,
            nSegs = 4,
            monPanelByBay = { ["1"] = 2, ["2"] = 2 },
            diaPx = 74,
        },
    }
    for _, case in CASES do
        test(`{case.key}'s noren carries 丸に{case.char} — one per doorway, on the cloth`, function()
            local m = Machiya.build(ZenDojo.palette, ArenaLayout, (MachiyaShops :: any)[case.key])
            -- the open bays, found by their first panel
            local bays = {}
            for _, c in m.children do
                local bay = string.match(c.name :: string, "^Noren(%d+)_1$")
                if bay then
                    table.insert(bays, bay)
                end
            end
            expect(#bays).toBe(2) -- two doorways
            for _, bay in bays do
                local mons = 0
                for k = 1, case.nPanels do
                    local panel = find(m, `Noren{bay}_{k}`)
                    expect(panel ~= nil).toBe(true)
                    for si = 1, case.nSegs do
                        local seg = find(panel, `Seg{si}`)
                        expect(seg ~= nil).toBe(true)
                        local mon = if seg.children then find(seg, "Mon") else nil
                        if mon then
                            mons += 1
                            -- ON the animated cloth: the host segment is the
                            -- NorenSway-tagged part, second from the top (the
                            -- upper-middle of the panel, where a noren crest sits)
                            expect(k).toBe(case.monPanelByBay[tostring(bay)])
                            expect(si).toBe(2)
                            expect(seg.properties.Tags[1]).toBe("NorenSeg")
                            -- the ring: a circular frame with a stroke, facing the street
                            expect(mon.properties.Face).toBe("Front")
                            local ring = find(mon, "Ring")
                            expect(ring ~= nil).toBe(true)
                            expect(find(ring, "Circle") ~= nil).toBe(true) -- UICorner
                            expect(find(ring, "Rim") ~= nil).toBe(true) -- UIStroke
                            local label = find(ring, "Char1")
                            expect(label ~= nil).toBe(true)
                            expect(label.properties.Text).toBe(case.char)
                            -- sized to read without covering the panel: the ring
                            -- stays within 62% of the panel's width and inside
                            -- its own segment's face
                            local diaPx = ring.properties.Size.UDim2[1][2]
                            expect(diaPx).toBe(case.diaPx)
                            local diaStuds = diaPx / mon.properties.PixelsPerStud
                            expect(diaStuds <= 0.62 * seg.properties.Size[1]).toBe(true)
                            expect(diaStuds <= 0.9 * seg.properties.Size[2]).toBe(true)
                            expect(diaStuds >= 0.25 * seg.properties.Size[1]).toBe(true)
                        end
                    end
                end
                expect(mons).toBe(1) -- ONE mon per doorway
            end
        end)
    end
end)

describe("stats shell — the two-bay false front", function()
    local shop = MachiyaShops.stats
    local e = shop.envelope
    local m = Machiya.build(ZenDojo.palette, ArenaLayout, shop)
    local parts = allParts(m)

    test("three posts, two bays, BOTH open — no closed ends, no parked leaves", function()
        -- A two-bay front has no outer bays to close (owner's ruling), and a
        -- parked sliding leaf needs a CLOSED neighbour to hide its slid-away
        -- third behind — with none anywhere, the screens ship stored and the
        -- whole elevation is the opening.
        local posts, panels, leaves, transoms = 0, 0, 0, 0
        for _, c in m.children do
            local n = c.name :: string
            if n:sub(1, 9) == "FrontPost" then
                posts += 1
            elseif n:sub(1, 8) == "BayPanel" then
                panels += 1
            elseif n:sub(1, 8) == "DoorLeaf" then
                leaves += 1
            elseif n:sub(1, 7) == "Transom" and n:sub(1, 10) ~= "TransomBar" then
                transoms += 1
            end
        end
        expect(posts).toBe(3)
        expect(panels).toBe(0)
        expect(leaves).toBe(0)
        expect(transoms).toBe(2)
    end)

    test("the head rail spans the WHOLE frontage — both bays are the opening", function()
        local hr = find(m, "HeadRail")
        expect(hr ~= nil).toBe(true)
        -- corner post centres are inset half a post from the envelope's ends,
        -- so the open span is W - POST_W (0.49)
        expect(hr.properties.Size[1]).toBeCloseTo((e.x1 - e.x0) - 0.49, 0.001)
        expect(hr.properties.CFrame[1]).toBeCloseTo((e.x0 + e.x1) / 2, 0.001)
    end)

    test("noren hang in BOTH doorways — bays 1 and 2, three panels each", function()
        for bay = 1, 2 do
            for k = 1, 3 do
                expect(find(m, `Noren{bay}_{k}`) ~= nil).toBe(true)
            end
        end
    end)

    test("the wall kanban reads 番付, per-character, framed and contrasting", function()
        local k = find(m, "Kanban")
        expect(k ~= nil).toBe(true)
        local face = find(k, "Face")
        expect(face ~= nil).toBe(true)
        local c1, c2 = find(face, "Char1"), find(face, "Char2")
        expect(c1 ~= nil).toBe(true)
        expect(c2 ~= nil).toBe(true)
        expect(c1.properties.Text).toBe("番")
        expect(c2.properties.Text).toBe("付")
        expect(find(face, "Char3") == nil).toBe(true)
        local frames = 0
        for _, c in m.children do
            if (c.name :: string):sub(1, 11) == "KanbanFrame" then
                frames += 1
            end
        end
        expect(frames).toBe(4)
        -- ink and board must not drift together (the row's contrast rule)
        local panel = k.properties.Color
        local inkC = c1.properties.TextColor3
        expect(math.abs((panel[1] + panel[2] + panel[3]) - (inkC[1] + inkC[2] + inkC[3])) > 1).toBe(true)
        -- the wall-board occlusion guard: the board hangs in open air above the eave
        local eave = find(m, "Eave")
        local plo = rotAABB(k)
        local _, ehi = rotAABB(eave)
        expect(plo[2] > ehi[2]).toBe(true)
    end)

    test("ONE chōchin, at the west corner — the roji corner stays bare", function()
        -- The east corner sits on the 1.5 roji, where a barrel would truly
        -- intersect apparel's own west lantern (both shops share z0 AND floorY,
        -- so the pair hangs at identical y/z 1.2 studs apart — sum of barrel
        -- radii 1.3). One lantern, west corner, no clip.
        expect(find(m, "ChochinWest") ~= nil).toBe(true)
        expect(find(m, "ChochinEast") == nil).toBe(true)
    end)

    test("every part has positive size — the narrow front never emits inverted geometry", function()
        -- The archetype's mushiko-mado window was 12 studs wide unconditionally;
        -- on a 10-wide envelope that made NEGATIVE jamb widths. The window now
        -- follows the stucco box, and this holds the whole model to it.
        expect(#parts > 0).toBe(true)
        for _, p in parts do
            for ax = 1, 3 do
                expect(p.properties.Size[ax] > 0).toBe(true)
            end
        end
        local jamb = find(m, "UpperWallFrontWest")
        expect(jamb ~= nil).toBe(true)
        expect(jamb.properties.Size[1] >= 0.99).toBe(true)
    end)

    test("full-extent clearances: the roji, the promenade line, the tower", function()
        for _, p in parts do
            if p.name == "Threshold" then
                continue
            end
            local lo, hi = rotAABB(p)
            -- east: nothing reaches past apparel's west face minus 0.8 — the
            -- ridge/eave overhangs (<= 0.6) stay inside the 1.5 roji
            expect(hi[1] <= MachiyaShops.apparel.envelope.x0 - 0.8).toBe(true)
            -- north: at GROUND level nothing crosses the frontage plane at all;
            -- what does cross is AERIAL only — the tilted eave's AABB corner
            -- (z0 - 2.52) and the west chōchin's barrel under it (z0 - 2.84),
            -- the same overhang every accepted shop on the row carries — and
            -- stays a full storey up (the barrel's own hem guard is floor + 5)
            if lo[2] < e.floorY + 4.9 then
                expect(lo[3] >= e.z0 - 1e-6).toBe(true)
            else
                expect(lo[3] >= e.z0 - 2.9).toBe(true)
            end
            -- subordinate to the tower, same as every shell on the square
            expect(hi[2] <= ArenaLayout.towerTopY - 9.0).toBe(true)
        end
    end)

    test("cross-shop audit: NOTHING intersects the built apparel shop", function()
        -- rotation-aware AABB of every stats part against every apparel part —
        -- the neighbour-clip class the corner chōchin would have committed
        local ma = Machiya.build(ZenDojo.palette, ArenaLayout, MachiyaShops.apparel)
        local aParts = allParts(ma)
        for _, sp in parts do
            if sp.name == "Threshold" then
                continue
            end
            local slo, shi = rotAABB(sp)
            for _, op in aParts do
                if op.name == "Threshold" then
                    continue
                end
                local olo, ohi = rotAABB(op)
                local pen = math.huge
                for ax = 1, 3 do
                    pen = math.min(pen, math.min(shi[ax], ohi[ax]) - math.max(slo[ax], olo[ax]))
                end
                expect(pen <= 1e-4).toBe(true)
            end
        end
    end)
end)

describe("stats rear doorway — the cavern's mouth (identity.rearDoor)", function()
    local shop = MachiyaShops.stats
    local e = shop.envelope
    local m = Machiya.build(ZenDojo.palette, ArenaLayout, shop)
    local parts = allParts(m)
    -- the shell's own planes, restated from the archetype's constants
    local S, WALL_T, POST_W = 0.30, 0.5, 0.49
    local CX = (e.x0 + e.x1) / 2
    local SZ1 = e.z1 - S -- the stucco box's back face
    local HEAD = e.floorY + 6.8 -- the kamoi line every doorway in this building clears
    local STOREY_H = 9.0

    test("the registry names the capability: width 6.0, pine-green noren, 4 segments", function()
        local rd = shop.identity.rearDoor
        expect(rd ~= nil).toBe(true)
        expect(rd.width).toBe(6.0)
        expect(rd.noren ~= nil).toBe(true)
        for i = 1, 3 do
            expect(rd.noren.color[i]).toBe(shop.identity.noren.color[i])
        end
        expect(rd.noren.segments).toBe(4)
    end)

    test("the back wall OPENS: WallBack is replaced by flanks, a header, posts and a lintel", function()
        expect(find(m, "WallBack") == nil).toBe(true)
        for _, nm in
            {
                "WallBackWest",
                "WallBackEast",
                "WallBackHead",
                "RearDoorPostWest",
                "RearDoorPostEast",
                "RearDoorLintel",
            }
        do
            expect(find(m, nm) ~= nil).toBe(true)
        end
    end)

    test("the opening is 6.0 clear, centred, and heads at the shop's own kamoi", function()
        local pw = find(m, "RearDoorPostWest")
        local pe = find(m, "RearDoorPostEast")
        -- clear width is post inner face to post inner face
        local innerW = pw.properties.CFrame[1] + pw.properties.Size[1] / 2
        local innerE = pe.properties.CFrame[1] - pe.properties.Size[1] / 2
        expect(innerE - innerW).toBeCloseTo(6.0, 0.001)
        expect((innerW + innerE) / 2).toBeCloseTo(CX, 0.001)
        -- posts stand floor to the kamoi; the lintel bears on them
        for _, p in { pw, pe } do
            expect(p.properties.CFrame[2] - p.properties.Size[2] / 2).toBeCloseTo(e.floorY, 0.001)
            expect(p.properties.CFrame[2] + p.properties.Size[2] / 2).toBeCloseTo(HEAD, 0.001)
        end
        local lin = find(m, "RearDoorLintel")
        expect(lin.properties.CFrame[2] - lin.properties.Size[2] / 2).toBeCloseTo(HEAD, 0.001)
        -- and it spans post outer edge to post outer edge — it bears, it does not float
        expect(lin.properties.Size[1]).toBeCloseTo(6.0 + 2 * POST_W, 0.001)
        expect(lin.properties.CFrame[1]).toBeCloseTo(CX, 0.001)
    end)

    test("every member registers to the wall's own faces — flush outside edges", function()
        -- stucco pieces sit exactly where WallBack sat: outer face on SZ1, WALL_T thick
        for _, nm in { "WallBackWest", "WallBackEast", "WallBackHead" } do
            local p = find(m, nm)
            expect(p.properties.CFrame[3] + p.properties.Size[3] / 2).toBeCloseTo(SZ1, 0.001)
            expect(p.properties.Size[3]).toBeCloseTo(WALL_T, 0.001)
        end
        -- timber frame: outer face flush on the wall's outer face (the plane the bore meets),
        -- standing proud of the INNER face into the vestibule
        for _, nm in { "RearDoorPostWest", "RearDoorPostEast", "RearDoorLintel" } do
            local p = find(m, nm)
            expect(p.properties.CFrame[3] + p.properties.Size[3] / 2).toBeCloseTo(SZ1, 0.001)
            expect(p.properties.CFrame[3] - p.properties.Size[3] / 2 < SZ1 - WALL_T).toBe(true)
        end
        -- the flanks MEET the posts (no gap, no overlap)
        local pw, fw = find(m, "RearDoorPostWest"), find(m, "WallBackWest")
        expect(fw.properties.CFrame[1] + fw.properties.Size[1] / 2).toBeCloseTo(
            pw.properties.CFrame[1] - pw.properties.Size[1] / 2,
            0.001
        )
        local pe, fe = find(m, "RearDoorPostEast"), find(m, "WallBackEast")
        expect(fe.properties.CFrame[1] - fe.properties.Size[1] / 2).toBeCloseTo(
            pe.properties.CFrame[1] + pe.properties.Size[1] / 2,
            0.001
        )
        -- and the flanks run to the side walls' inner faces, closing the corner as WallBack did
        expect(fw.properties.CFrame[1] - fw.properties.Size[1] / 2).toBeCloseTo(e.x0 + S + WALL_T, 0.001)
        expect(fe.properties.CFrame[1] + fe.properties.Size[1] / 2).toBeCloseTo(e.x1 - S - WALL_T, 0.001)
        -- the header sits ON the lintel and rises to the storey top
        local hd, lin = find(m, "WallBackHead"), find(m, "RearDoorLintel")
        expect(hd.properties.CFrame[2] - hd.properties.Size[2] / 2).toBeCloseTo(
            lin.properties.CFrame[2] + lin.properties.Size[2] / 2,
            0.001
        )
        expect(hd.properties.CFrame[2] + hd.properties.Size[2] / 2).toBeCloseTo(e.floorY + STOREY_H, 0.001)
        expect(hd.properties.Size[1]).toBeCloseTo(lin.properties.Size[1], 0.001)
    end)

    test(
        "the floor runs THROUGH the opening at 113.30 — no step, nothing collidable in the passage",
        function()
            -- the slab's top IS the threshold, and it reaches the envelope's back edge
            local slab = find(m, "FloorSlab")
            expect(slab.properties.CFrame[2] + slab.properties.Size[2] / 2).toBeCloseTo(e.floorY, 0.001)
            expect(slab.properties.CFrame[3] + slab.properties.Size[3] / 2).toBeCloseTo(e.z1, 0.001)
            -- nothing collidable occupies the passage box: clear width, floor to head, through the wall
            local box = {
                lo = { CX - 3.0, e.floorY + 0.01, SZ1 - WALL_T - 0.4 },
                hi = { CX + 3.0, HEAD - 0.01, e.z1 },
            }
            for _, p in parts do
                if p.properties.CanCollide == false then
                    continue
                end
                if p.name == "FloorSlab" then
                    continue
                end
                local lo, hi = rotAABB(p)
                local pen = math.huge
                for ax = 1, 3 do
                    pen = math.min(pen, math.min(hi[ax], box.hi[ax]) - math.max(lo[ax], box.lo[ax]))
                end
                expect(pen <= 1e-4).toBe(true)
            end
        end
    )

    test("a pine-green noren hangs in the opening, on the VESTIBULE side, chained and tagged", function()
        for k = 1, 3 do
            local panel = find(m, `RearNoren_{k}`)
            expect(panel ~= nil).toBe(true)
            local prevZ = nil
            for s = 1, 4 do
                local seg = find(panel, `Seg{s}`)
                expect(seg ~= nil).toBe(true)
                expect(seg.properties.Tags[1]).toBe("NorenSeg")
                for i = 1, 3 do
                    expect(seg.properties.Color[i]).toBe(shop.identity.noren.color[i])
                end
                -- the sway client's rebuild assumes yaw 0 (±z-facing panels): top row {1,0,0}
                local cf = seg.properties.CFrame
                expect(cf[4]).toBeCloseTo(1, 0.001)
                expect(cf[5]).toBeCloseTo(0, 0.001)
                expect(cf[6]).toBeCloseTo(0, 0.001)
                -- inside the clear opening
                expect(cf[1] - seg.properties.Size[1] / 2 >= CX - 3.0).toBe(true)
                expect(cf[1] + seg.properties.Size[1] / 2 <= CX + 3.0).toBe(true)
                -- on the vestibule side of the wall's inner face
                expect(cf[3] < SZ1 - WALL_T).toBe(true)
                -- the hem walks INTO the vestibule (-z), which is what reads as cloth
                if prevZ then
                    expect(cf[3] < prevZ).toBe(true)
                end
                prevZ = cf[3]
                expect(seg.properties.CanCollide).toBe(false)
            end
            -- the chain hangs from the kamoi: the top segment's top is at HEAD
            local s1 = find(panel, "Seg1")
            local _, hi = rotAABB(s1)
            expect(hi[2]).toBeCloseTo(HEAD, 0.05)
        end
    end)

    test("the other three shells are UNTOUCHED: solid WallBack, no rear-door parts", function()
        -- default-off is the contract; the byte gate on the committed assets is the other half
        for _, key in { "hanabiya", "apparel", "accessories" } do
            local other = Machiya.build(ZenDojo.palette, ArenaLayout, (MachiyaShops :: any)[key])
            expect(find(other, "WallBack") ~= nil).toBe(true)
            for _, c in other.children do
                local nm = c.name :: string
                expect(nm:sub(1, 8) == "RearDoor").toBe(false)
                expect(nm:sub(1, 9) == "RearNoren").toBe(false)
                expect(nm:sub(1, 9) == "WallBackW").toBe(false)
                expect(nm:sub(1, 9) == "WallBackE").toBe(false)
                expect(nm:sub(1, 9) == "WallBackH").toBe(false)
            end
        end
    end)
end)
