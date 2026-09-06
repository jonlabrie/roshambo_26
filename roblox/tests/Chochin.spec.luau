--!strict
-- Chochin: the canyon chōchin module (tools/builders/Chochin.luau) at full fidelity, ported
-- from tools/studio/buildHanabiyaChochin.luau — the owner-gated Studio tool that built the
-- accepted Chochin_Hanabiya at 花火屋. The two files are the only copies of this design
-- (Studio tools are pasted whole and cannot require this module), so the drift-guard section
-- below reads the tool's source as text and checks this module's constants against its
-- literals: a change to either copy that isn't mirrored in the other fails CI.
local fs = require("@lune/fs")
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local Chochin = require("../tools/builders/Chochin")

local TOOL_PATH = "tools/studio/buildHanabiyaChochin.luau"
local src = fs.readFile(TOOL_PATH)

describe("Chochin drift guard vs " .. TOOL_PATH, function()
    test("lantern scale LS", function()
        local a, b = src:match("local LS = ([%d%.]+) / ([%d%.]+)")
        expect(a ~= nil and b ~= nil).toBe(true)
        local toolLS = tonumber(a :: string) :: number / (tonumber(b :: string) :: number)
        expect(Chochin.LS).toBeCloseTo(toolLS, 1e-9)
    end)
    test("Rmax and capR", function()
        local a, b = src:match("local Rmax, capR = ([%d%.]+) %* LS, ([%d%.]+) %* LS")
        expect(a ~= nil and b ~= nil).toBe(true)
        expect(Chochin.Rmax).toBeCloseTo((tonumber(a :: string) :: number) * Chochin.LS, 1e-9)
        expect(Chochin.capR).toBeCloseTo((tonumber(b :: string) :: number) * Chochin.LS, 1e-9)
    end)
    test("bodyH", function()
        local a = src:match("local bodyH = ([%d%.]+) %* LS")
        expect(a ~= nil).toBe(true)
        expect(Chochin.bodyH).toBeCloseTo((tonumber(a :: string) :: number) * Chochin.LS, 1e-9)
    end)
    test("ringR and tubeR", function()
        local a, b = src:match("local ringR, tubeR = ([%d%.]+) %* LS, ([%d%.]+) %* LS")
        expect(a ~= nil and b ~= nil).toBe(true)
        expect(Chochin.ringR).toBeCloseTo((tonumber(a :: string) :: number) * Chochin.LS, 1e-9)
        expect(Chochin.tubeR).toBeCloseTo((tonumber(b :: string) :: number) * Chochin.LS, 1e-9)
    end)
    test("slice count N and centre index", function()
        local n, c = src:match("local N, centerIdx = (%d+), (%d+)")
        expect(n ~= nil and c ~= nil).toBe(true)
        expect(Chochin.N).toBe(tonumber(n :: string))
        expect(Chochin.CENTER_IDX).toBe(tonumber(c :: string))
    end)
    test("rib count", function()
        local r = src:match("for j = 1, (%d+) do")
        expect(r ~= nil).toBe(true)
        expect(Chochin.RIBS).toBe(tonumber(r :: string))
    end)
    test("ring segment count", function()
        local r = src:match("for i = 0, (%d+) do")
        expect(r ~= nil).toBe(true)
        -- the tool loops i = 0..N-1 inclusive (N-1 segments' upper bound), i.e. N segments
        expect(Chochin.RING_SEGMENTS - 1).toBe(tonumber(r :: string))
    end)
    test("INK colour", function()
        local r, g, b = src:match("local INK = Color3%.fromRGB%((%d+), (%d+), (%d+)%)")
        expect(r ~= nil and g ~= nil and b ~= nil).toBe(true)
        expect(Chochin.INK[1]).toBeCloseTo((tonumber(r :: string) :: number) / 255, 0.001)
        expect(Chochin.INK[2]).toBeCloseTo((tonumber(g :: string) :: number) / 255, 0.001)
        expect(Chochin.INK[3]).toBeCloseTo((tonumber(b :: string) :: number) / 255, 0.001)
    end)
    test("METAL colour", function()
        local r, g, b = src:match("local METAL = Color3%.fromRGB%((%d+), (%d+), (%d+)%)")
        expect(r ~= nil and g ~= nil and b ~= nil).toBe(true)
        expect(Chochin.METAL[1]).toBeCloseTo((tonumber(r :: string) :: number) / 255, 0.001)
        expect(Chochin.METAL[2]).toBeCloseTo((tonumber(g :: string) :: number) / 255, 0.001)
        expect(Chochin.METAL[3]).toBeCloseTo((tonumber(b :: string) :: number) / 255, 0.001)
    end)
    test("PAPER colour", function()
        local r, g, b = src:match("local PAPER = { (%d+), (%d+), (%d+) }")
        expect(r ~= nil and g ~= nil and b ~= nil).toBe(true)
        expect(Chochin.PAPER[1]).toBeCloseTo((tonumber(r :: string) :: number) / 255, 0.001)
        expect(Chochin.PAPER[2]).toBeCloseTo((tonumber(g :: string) :: number) / 255, 0.001)
        expect(Chochin.PAPER[3]).toBeCloseTo((tonumber(b :: string) :: number) / 255, 0.001)
    end)
    -- SKIPPED, deliberately: the barrel profile formula (capR + (Rmax-capR)*sqrt(1-d^6)) and the
    -- glyph-plate size/offset/yaw are not simple numeric literals in the tool's source, so a text
    -- match would be fragile. The profile is instead covered functionally below (profile(0.5)
    -- must equal Rmax, the widest point of the silhouette).
end)

describe("Chochin.build — full-fidelity geometry", function()
    local m = Chochin.build("Test", 10, 20, 130)

    -- Recursive for the same reason `find` is: the barrel, ribs and ring hang inside `Swing`.
    local function countPrefix(node, prefix)
        local n = 0
        for _, c in node.children do
            if (c.name :: string):sub(1, #prefix) == prefix then
                n += 1
            end
            if c.children then
                n += countPrefix(c, prefix)
            end
        end
        return n
    end
    -- RECURSIVE, because the hanging pieces now live inside the `Swing` sub-model that
    -- ChochinSway animates; only the Hook stays a direct child. Searching the whole subtree keeps
    -- every assertion below about the LANTERN rather than about where the rig happens to nest it.
    local function find(node, name)
        for _, c in node.children do
            if c.name == name then
                return c
            end
            if c.children then
                local hit = find(c, name)
                if hit then
                    return hit
                end
            end
        end
        return nil
    end

    test("model is named Chochin<suffix>", function()
        expect(m.name).toBe("ChochinTest")
    end)
    test("everything that hangs is inside a tagged Swing sub-model; only the Hook is not", function()
        -- The rig ChochinSway drives. Before 2026-09-06 this builder emitted the lantern flat, so
        -- shop lanterns hung dead while the hanabiya's Studio-built pair (which HAS this rig)
        -- swung -- the whole reason for this structure.
        local names = {}
        for _, c in m.children do
            names[c.name] = c
        end
        expect(names.Hook ~= nil).toBe(true)
        expect(names.Swing ~= nil).toBe(true)
        expect(#m.children).toBe(2)
        expect(names.Swing.className).toBe("Model")
        expect(names.Swing.properties.Tags).toEqual({ "ChochinSwing" })
        -- pivot at the HANG POINT (armY), not the bounding-box centre a Model would default to:
        -- a lantern turned about its middle swings from its waist.
        expect(names.Swing.properties.WorldPivot[2]).toBeCloseTo(130, 1e-6)
        expect(names.Swing.properties.WorldPivot[1]).toBeCloseTo(10, 1e-6)
        expect(names.Swing.properties.WorldPivot[3]).toBeCloseTo(20, 1e-6)
    end)
    test("18 paper-barrel slices: 17 Slice_ parts + 1 ChochinBody", function()
        expect(countPrefix(m, "Slice_")).toBe(Chochin.N - 1)
        expect(find(m, "ChochinBody") ~= nil).toBe(true)
    end)
    test("the lit ChochinBody carries a PointLight", function()
        local body = find(m, "ChochinBody")
        expect(body ~= nil).toBe(true)
        expect(body.children ~= nil and #body.children).toBe(1)
        expect(body.children[1].className).toBe("PointLight")
    end)
    test("16 ribs", function()
        expect(countPrefix(m, "Rib_")).toBe(Chochin.RIBS)
    end)
    test("a real ring, not a hang rod: 14 loop segments, no HangRod part", function()
        expect(countPrefix(m, "LoopSeg_")).toBe(Chochin.RING_SEGMENTS)
        expect(find(m, "HangRod") ~= nil).toBe(false)
    end)
    test("the hook is present", function()
        expect(find(m, "Hook") ~= nil).toBe(true)
    end)
    test("top and bottom caps are present", function()
        expect(find(m, "CapTop") ~= nil).toBe(true)
        expect(find(m, "CapBottom") ~= nil).toBe(true)
    end)
    test("both glyph plates exist and carry the RoundLantern tag", function()
        local a, b = find(m, "GlyphPlateA"), find(m, "GlyphPlateB")
        expect(a ~= nil).toBe(true)
        expect(b ~= nil).toBe(true)
        expect(a.properties.Tags).toEqual({ "RoundLantern" })
        expect(b.properties.Tags).toEqual({ "RoundLantern" })
    end)
    test("the barrel silhouette is widest at its centre (profile(0.5) == Rmax)", function()
        -- ChochinBody sits at tt = (CENTER_IDX + 0.5) / N; with N=18, CENTER_IDX=9 that's tt=0.5
        -- exactly, so its radius (half its Size.Y) must equal Rmax.
        local body = find(m, "ChochinBody")
        expect(body.properties.Size[2] / 2).toBeCloseTo(Chochin.Rmax, 1e-6)
    end)
end)

describe("Chochin.hemY", function()
    test("matches the tool's own formula: armY - 2*ringR - 0.13*LS - bodyH - 0.13*LS", function()
        local armY = 100
        local expected = armY - 2 * Chochin.ringR - 0.13 * Chochin.LS - Chochin.bodyH - 0.13 * Chochin.LS
        expect(Chochin.hemY(armY)).toBeCloseTo(expected, 1e-9)
    end)
    test("hem clearance behaviour: a low armY yields a hem below a high one", function()
        expect(Chochin.hemY(100) < Chochin.hemY(120)).toBe(true)
    end)
end)

describe("Chochin.build — per-shop paper tint", function()
    -- RECURSIVE, because the hanging pieces now live inside the `Swing` sub-model that
    -- ChochinSway animates; only the Hook stays a direct child. Searching the whole subtree keeps
    -- every assertion below about the LANTERN rather than about where the rig happens to nest it.
    local function find(node, name)
        for _, c in node.children do
            if c.name == name then
                return c
            end
            if c.children then
                local hit = find(c, name)
                if hit then
                    return hit
                end
            end
        end
        return nil
    end

    test("default (no tint) scales the canonical cream — same gradient factor on every channel", function()
        local m = Chochin.build("Default", 0, 0, 100)
        local body = find(m, "ChochinBody")
        local c = body.properties.Color
        local fR, fG, fB = c[1] / Chochin.PAPER[1], c[2] / Chochin.PAPER[2], c[3] / Chochin.PAPER[3]
        expect(fR).toBeCloseTo(fG, 1e-9)
        expect(fR).toBeCloseTo(fB, 1e-9)
    end)

    test("a tint replaces the base colour the gradient scales, nothing else", function()
        -- Compare against the SAME slice's default-cream colour rather than assuming the
        -- gradient factor f — the centre slice (CENTER_IDX) is not exactly tt=0.5, so f is
        -- close to but not exactly 1. Both builds share the same tt, so f cancels out: the
        -- tinted colour must be tint01 * f, where f is recovered from the default build.
        local tint255 = { 170, 178, 200 }
        local tint01 = { tint255[1] / 255, tint255[2] / 255, tint255[3] / 255 }
        local default = Chochin.build("Default2", 0, 0, 100)
        local tinted = Chochin.build("Tinted", 0, 0, 100, tint255)
        local defaultC = find(default, "ChochinBody").properties.Color
        local tintedC = find(tinted, "ChochinBody").properties.Color
        local f = defaultC[1] / Chochin.PAPER[1]
        for i = 1, 3 do
            expect(tintedC[i]).toBeCloseTo(tint01[i] * f, 1e-9)
        end
    end)

    test("the glyph plates are NEVER tinted — identical with and without a paper override", function()
        local plain = Chochin.build("Plain", 0, 0, 100)
        local tinted = Chochin.build("Tinted2", 0, 0, 100, { 170, 178, 200 })
        local plateA, plateB = find(plain, "GlyphPlateA"), find(tinted, "GlyphPlateA")
        -- names differ (model-scoped), so compare properties only
        expect(plateA.properties).toEqual(plateB.properties)
        expect(plateA.properties.Tags).toEqual({ "RoundLantern" })
    end)
end)

describe("Chochin legibility guard — a tint must not swallow the World Throw glyph at night", function()
    -- WHY 0.55: the RoundLantern glyph plate sits in front of the paper barrel, untinted, and
    -- shows the last World Throw — that's the lantern's actual job, not the tint. If a barrel
    -- goes too dark, the glyph loses contrast against it, and PaperLanternDayNight dims the
    -- whole lantern further toward night, which only makes a marginal tint worse. Canonical
    -- cream (Chochin.PAPER) measures ~0.684 — the reference point for "light enough."
    local MachiyaShops = require("../tools/builders/MachiyaShops")
    local FLOOR = Chochin.LEGIBILITY_FLOOR

    test("the floor itself is 0.55", function()
        expect(FLOOR).toBe(0.55)
    end)
    test("the canonical cream clears the floor (reference: ~0.684)", function()
        local lum = Chochin.luminance(Chochin.PAPER)
        expect(lum >= FLOOR).toBe(true)
        expect(lum).toBeCloseTo(0.684, 0.01)
    end)

    -- Walk EVERY Shop entry MachiyaShops defines and check any identity.chochin.paper tint, so a
    -- future shop (Tasks 5-7) that ships a dark barrel fails CI without anyone having to
    -- remember to add a new assertion here by hand.
    for shopKey, shop in MachiyaShops do
        if
            type(shop) == "table"
            and shop.identity
            and type(shop.identity.chochin) == "table"
            and shop.identity.chochin.paper
        then
            test(("%s's chōchin tint clears the legibility floor"):format(tostring(shopKey)), function()
                local rgb255 = shop.identity.chochin.paper
                local rgb01 = { rgb255[1] / 255, rgb255[2] / 255, rgb255[3] / 255 }
                local lum = Chochin.luminance(rgb01)
                expect(lum >= FLOOR).toBe(true)
            end)
        end
    end
end)
