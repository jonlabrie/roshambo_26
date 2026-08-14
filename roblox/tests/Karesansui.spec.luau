--!strict
local harness = require("./harness")
local Karesansui = require("../tools/builders/Karesansui")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Karesansui garden (kerb + field + guard)", function()
    local spec = Karesansui.build(ZenDojo.palette, L)
    local K = L.karesansui
    local byName = {}
    for _, c in spec.children :: any do
        byName[c.name] = c
    end
    local function rectOf(part): { number } -- world XZ rect from CFrame + Size
        local cf, sz = part.properties.CFrame, part.properties.Size
        return { cf[1] - sz[1] / 2, cf[3] - sz[3] / 2, cf[1] + sz[1] / 2, cf[3] + sz[3] / 2 }
    end
    local function overlaps(a: { number }, b: { number }): boolean
        return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
    end
    test("every panel emits kerb x4, field, guard x4 — and nothing else", function()
        local count = 0
        for _, panel in { "Main" } do
            for _, side in { "N", "S", "E", "W" } do
                expect(byName[`Kerb{panel}{side}`] ~= nil).toBe(true)
                expect(byName[`Guard{panel}{side}`] ~= nil).toBe(true)
                count += 2
            end
            expect(byName[`Field{panel}`] ~= nil).toBe(true)
            count += 1
        end
        expect(#(spec.children :: any)).toBe(count)
    end)
    test("NOTHING intersects the corridors (the inviolable rule)", function()
        for _, c in spec.children :: any do
            for _, corr in K.corridors :: any do
                expect(overlaps(rectOf(c), corr)).toBe(false)
            end
        end
    end)
    test("fields sit inside their kerbs, proud of the terrace", function()
        for _, panel in { "Main" } do
            local key = "main"
            local p = K.panels[key]
            local f = rectOf(byName[`Field{panel}`])
            expect(f[1] >= p[1]).toBe(true)
            expect(f[2] >= p[2]).toBe(true)
            expect(f[3] <= p[3]).toBe(true)
            expect(f[4] <= p[4]).toBe(true)
            local cf = byName[`Field{panel}`].properties.CFrame
            local sz = byName[`Field{panel}`].properties.Size
            expect(cf[2] + sz[2] / 2).toBeCloseTo(K.floorY.main + K.slabProud, 0.001)
        end
    end)
    test("guards: invisible, 3.5 tall, EngawaBarrier group, on the kerb lines", function()
        for _, panel in { "Main" } do
            for _, side in { "N", "S", "E", "W" } do
                local g = byName[`Guard{panel}{side}`]
                expect(g.properties.Transparency).toBe(1)
                expect(g.properties.Size[2]).toBeCloseTo(K.guardH, 0.001)
                expect(g.properties.CollisionGroup).toBe("EngawaBarrier")
                expect(g.properties.CanCollide).toBe(true)
            end
        end
    end)
    test("kerb wears the POSTS' cypress, and stands proud", function()
        -- Was "the plinth vocabulary: Slate". The kerb belonged to the plinths while this was a
        -- garden the tower stood in; now it runs between the posts and belongs to their timber
        -- (owner's gate 2026-08-14).
        local k = byName.KerbMainN
        expect(k.properties.Material).toBe("Wood")
        local top = k.properties.CFrame[2] + k.properties.Size[2] / 2
        expect(top).toBeCloseTo(K.floorY.main + K.kerbProud, 0.001)
    end)

    test("every kerb wears the grain that was VERIFIED BY EYE", function()
        -- This asserts an observation, not a derivation. The cypress maps project from world axes,
        -- so a beam cannot fix its own grain by being turned — only the variant can — and the
        -- reasoned guess (rotated maps for the beams running the other way) was checked at the
        -- gate and was WRONG: it banded them across. All four take the unrotated maps.
        --
        -- So this test's job is narrow: hold what was seen, and fail loudly if someone
        -- reintroduces the plausible-but-wrong mapping. It cannot tell you the grain is right —
        -- only a person looking at it can do that.
        for _, side in { "N", "S", "W", "E" } do
            local k = byName[`KerbMain{side}`]
            expect(k ~= nil).toBe(true)
            expect(k.properties.Material).toBe("Wood")
            expect(k.properties.MaterialVariant).toBe("CypressWeathered")
        end
    end)
    test("field variants follow the panel's long axis", function()
        for _, panel in { "Main" } do
            local key = "main"
            local p = K.panels[key]
            local want = if (p[4] - p[2]) >= (p[3] - p[1]) then "RakedSandNS" else "RakedSandEW"
            expect(byName[`Field{panel}`].properties.MaterialVariant).toBe(want)
        end
    end)
end)
