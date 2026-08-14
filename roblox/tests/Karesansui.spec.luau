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
    test("every panel emits kerb x4, field, guard x4, a cap per Z-runner — and nothing else", function()
        -- The "and nothing else" is the point: this is the inventory that catches a builder
        -- quietly gaining parts. It gained two on 2026-08-14 (the E/W capping boards) and this
        -- test is what made that a decision rather than a drift.
        local count = 0
        for _, panel in { "Main" } do
            for _, side in { "N", "S", "E", "W" } do
                local k = byName[`Kerb{panel}{side}`]
                expect(k ~= nil).toBe(true)
                expect(byName[`Guard{panel}{side}`] ~= nil).toBe(true)
                count += 2
                if byName[`KerbCap{panel}{side}`] then
                    count += 1
                end
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

    test("the grain that was VERIFIED BY EYE: beams unrotated, and the Z-runners capped", function()
        -- This holds an observation, not a derivation. The cypress maps project from world axes,
        -- so a beam cannot fix its own grain by being turned, and ONE BEAM CANNOT GET BOTH FACES
        -- RIGHT: a Z-running beam's sides want the unrotated maps and its top wants them turned.
        -- Both readings came from the owner looking, in two passes. The test's job is narrow —
        -- fail loudly if the plausible-but-wrong single-variant mapping comes back. It cannot tell
        -- anyone the grain is right; only a person looking at it can.
        for _, side in { "N", "S", "W", "E" } do
            local k = byName[`KerbMain{side}`]
            expect(k ~= nil).toBe(true)
            expect(k.properties.Material).toBe("Wood")
            expect(k.properties.MaterialVariant).toBe("CypressWeathered")
            -- capped exactly when the beam runs in Z, and only then
            local runsInX = k.properties.Size[1] > k.properties.Size[3]
            local cap = byName[`KerbCapMain{side}`]
            expect(cap ~= nil).toBe(not runsInX)
            if cap then
                expect(cap.properties.MaterialVariant).toBe("CypressVertical")
            end
        end
    end)

    test("the capping boards leave every kerb topping out on one line", function()
        -- The cap is not stacked ON the beam — the beam is shortened by exactly the cap's
        -- thickness. Otherwise the two capped sides would stand a cap proud of the other two and
        -- step at the corners, which is the sort of 0.08 nobody sees until they are standing on it.
        local want = K.floorY.main + K.kerbProud
        for _, side in { "N", "S", "W", "E" } do
            local k = byName[`KerbMain{side}`]
            local cap = byName[`KerbCapMain{side}`]
            local top = (cap or k).properties.CFrame[2] + (cap or k).properties.Size[2] / 2
            expect(top).toBeCloseTo(want, 0.001)
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
