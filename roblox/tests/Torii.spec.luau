--!strict
local harness = require("./harness")
local Torii = require("../tools/builders/Torii")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

local spec = Torii.build(ZenDojo.palette, L)
local byName = {}
for _, c in spec.children :: any do
    byName[c.name] = c
end
local T = L.toriiGate

-- rotation-aware extents, because the kasagi segments are all tilted
local function span(part, ax: number)
    local cf, sz = part.properties.CFrame, part.properties.Size
    local row = { 4, 7, 10 }
    local e = 0
    for b = 1, 3 do
        e += math.abs(cf[row[ax] + b - 1]) * sz[b] / 2
    end
    return cf[ax] - e, cf[ax] + e
end

describe("Torii — the myōjin gate on the Overlook deck", function()
    test("it is a model named Torii with both pillars and the whole lintel assembly", function()
        expect(spec.name).toBe("Torii")
        for _, n in
            { "PillarNorth", "PillarSouth", "NemakiNorth", "NemakiSouth", "Nuki", "Gakuzuka", "Shimaki" }
        do
            expect(byName[n] ~= nil).toBe(true)
        end
        expect(byName["Kasagi1"] ~= nil).toBe(true)
    end)

    test("THE PILLARS STAND ON THE DECK, not in the air above it or sunk through it", function()
        -- The whole reason this gate is where it is. West of the deck the ground falls from 112.6
        -- to 109.7 and the two footings would differ by 1.7; the deck is a known 113.30. If a
        -- later edit moves the gate off the deck this is what should stop it.
        for _, n in { "PillarNorth", "PillarSouth" } do
            local lo = span(byName[n], 2)
            expect(math.abs(lo - T.pos[2]) < 0.001).toBe(true)
        end
    end)

    test("IT SPANS THE DECK'S EXIT, and the pillars stand outside the walkway", function()
        -- The UpperStep — the only way off the deck's west side — spans z 21.5..34.5. The gate
        -- frames that gap rather than standing in it, so nobody walks into a pillar on the way out.
        local n0, n1 = span(byName["PillarNorth"], 3)
        local s0, s1 = span(byName["PillarSouth"], 3)
        expect(n1 <= 21.5).toBe(true)
        expect(s0 >= 34.5).toBe(true)
    end)

    test("THE POSTS ARE ROUND", function()
        -- Spec.ROT.CYL_VERTICAL only RE-AIMS a cylinder's long axis; it does not make a part a
        -- cylinder. Both pillars carried that rotation and no Shape, so they were boxes standing
        -- on end and looked it. Nothing in the numbers said so.
        for _, n in { "PillarNorth", "PillarSouth", "NemakiNorth", "NemakiSouth" } do
            expect(byName[n].properties.Shape).toBe("Cylinder")
        end
    end)

    test("THE NUKI HANGS A FIXED GAP UNDER THE SHIMAKI", function()
        -- Owner's gate: three studs below the upper beam. Asserted as the CLEAR GAP, which is what
        -- the eye reads and what the gakuzuka fills — as a fraction of the pillar it drifted every
        -- time the gate's height changed.
        -- The owner's number, pinned as a literal. Comparing the built gap against T.nukiGap
        -- alone proves only that the builder honours its parameter — both sides move together, so
        -- it cannot notice the value itself drifting away from what was asked for.
        expect(T.nukiGap).toBeCloseTo(2.0, 0.001)
        local _, nukiTop = span(byName["Nuki"], 2)
        local shimakiLo = span(byName["Shimaki"], 2)
        expect(math.abs((shimakiLo - nukiTop) - T.nukiGap) < 0.001).toBe(true)
        -- and the strut fills exactly that gap, rather than floating in it
        local gLo, gHi = span(byName["Gakuzuka"], 2)
        expect(math.abs(gLo - nukiTop) < 0.001).toBe(true)
        expect(math.abs(gHi - shimakiLo) < 0.001).toBe(true)
    end)

    test("THE KUSABI SIT AT THE JOINT, not somewhere along the beam", function()
        -- They were placed as a fraction of the nuki's OVERHANG, so lengthening the nuki slid them
        -- outboard with it and stranded them mid-protrusion, pinning nothing (owner: "orphaned the
        -- kusabi nowhere near the posts"). A wedge belongs to the joint — it does not care how far
        -- the beam runs past it — so this is asserted against the PILLAR, which is the thing it is
        -- driven into, and it stays true whatever the nuki's length becomes.
        -- `dir` is which way "into the pillar" points for that side: the north kusabi sits at
        -- LOWER z than its pillar, so its inner edge must be GREATER than the pillar's near face,
        -- and the south one is the mirror of that.
        for _, side in { { "North", 1 }, { "South", -1 } } do
            local nm, dir = side[1] :: string, side[2] :: number
            local k0, k1 = span(byName[`Kusabi{nm}`], 3)
            local p0, p1 = span(byName[`Pillar{nm}`], 3)
            local kInner = if dir == 1 then k1 else k0
            local pFace = if dir == 1 then p0 else p1
            -- overlapping the pillar: neither merely touching it nor floating free of it
            expect((kInner - pFace) * dir > 0).toBe(true)
            expect(math.abs(kInner - pFace) < 0.15).toBe(true)
        end
    end)

    test("THE CENTRE IS CLOSED, and the sides are still walkable", function()
        -- 正中, the gate's centre line, is the kami's path — a player has to pass to one side. Both
        -- halves matter: too narrow and it stops nobody, too wide and it shuts the gate. The
        -- pillars are 15 apart, so this checks real walking room survives on each side.
        local b = byName["SeichuBar"]
        expect(b ~= nil).toBe(true)
        expect(b.properties.Transparency).toBe(1)
        expect(b.properties.CanCollide).toBe(true)
        -- EngawaBarrier passes Projectile and blocks players; Default would stop fireworks too
        expect(b.properties.CollisionGroup).toBe("EngawaBarrier")
        local bLo, bHi = span(b, 3)
        local pn = span(byName["PillarNorth"], 3)
        local _, ps = span(byName["PillarSouth"], 3)
        expect(math.abs((bLo + bHi) / 2 - T.pos[3]) < 0.001).toBe(true) -- actually centred
        expect(bLo - pn > 4).toBe(true)
        expect(ps - bHi > 4).toBe(true)
    end)

    test("the centre bar cannot be climbed over or stood on", function()
        -- It runs INTO the nuki rather than stopping under it. A gap would let a player squeeze
        -- over the top; stopping flush would hand them a ledge to stand on inside the gate.
        local _, barTop = span(byName["SeichuBar"], 2)
        local nLo, nTop = span(byName["Nuki"], 2)
        expect(barTop > nLo + 0.2).toBe(true) -- buried in the beam, not merely reaching it
        expect(barTop <= nTop + 0.001).toBe(true) -- and not poking out above it
        local barLo = span(byName["SeichuBar"], 2)
        expect(math.abs(barLo - T.pos[2]) < 0.001).toBe(true) -- down to the deck, no crawl gap
    end)

    test("THE TWO LINTELS ARE THE SAME LENGTH", function()
        -- Owner's gate: match the nuki to the shimaki above it. The nuki used to have its own
        -- overhang and came out two studs shorter, so the gate read as a stack of three different
        -- widths. Both now derive from one number in the builder — this is the assertion that
        -- notices if someone gives the nuki its own again.
        local nLo, nHi = span(byName["Nuki"], 3)
        local sLo, sHi = span(byName["Shimaki"], 3)
        expect(math.abs((nHi - nLo) - (sHi - sLo)) < 0.001).toBe(true)
        expect(math.abs(nLo - sLo) < 0.001).toBe(true) -- and flush at both ends, not just equal
    end)

    test("THE KASAGI IS CAPPED IN BLACK, and the cap oversails the timber", function()
        -- Fushimi Inari. The cap also covers the one face of a Z-running beam whose grain runs
        -- across it — but its job here is the black. It must oversail on every edge: a cap flush
        -- with the member under it is the coplanar-face defect this build has produced repeatedly.
        local ink = ZenDojo.palette.ink
        for i = 1, T.kasagiSegments do
            expect(byName[`KasagiCap{i}`].properties.Color).toBe(ink)
        end
        local kLo, kHi = span(byName["Kasagi1"], 3)
        local cLo, cHi = span(byName["KasagiCap1"], 3)
        expect(cLo < kLo - 0.05).toBe(true)
        local _, kTop = span(byName["Kasagi4"], 2)
        local cBot = span(byName["KasagiCap4"], 2)
        expect(math.abs(cBot - kTop) < 0.05).toBe(true) -- sits ON it, not floating
        expect(byName["KasagiCap1"].properties.Size[3] > byName["Kasagi1"].properties.Size[3]).toBe(true)
    end)

    test("YOU CAN WALK UNDER THE NUKI", function()
        -- The lowest thing spanning the opening. 6 studs is the WORKING avatar height — a bare
        -- R15 is ~5, hair adds one, and players wear hair.
        local lo = span(byName["Nuki"], 2)
        expect(lo - T.pos[2] >= 6.0).toBe(true)
    end)

    test("the kasagi RISES AT ITS ENDS — that is what makes it myōjin", function()
        -- A straight lintel is a shinmei torii, a different (and unpainted) form. The curve is
        -- sampled as segments, so check the outermost sits higher than the centre one.
        local mid = math.ceil(T.kasagiSegments / 2)
        local _, midTop = span(byName[`Kasagi{mid}`], 2)
        local _, endTop = span(byName["Kasagi1"], 2)
        expect(endTop > midTop + 0.3).toBe(true)
        local _, lastTop = span(byName[`Kasagi{T.kasagiSegments}`], 2)
        expect(math.abs(lastTop - endTop) < 0.001).toBe(true) -- and symmetric
    end)

    test("IT IS PAINTED, and only the joinery is not", function()
        local red = ZenDojo.palette.cypressVermilion
        local ink = ZenDojo.palette.ink
        for _, n in { "PillarNorth", "PillarSouth", "Nuki", "Gakuzuka", "Shimaki", "Kasagi1" } do
            expect(byName[n].properties.Color).toBe(red)
        end
        for _, n in { "NemakiNorth", "NemakiSouth", "KusabiNorth", "KusabiSouth" } do
            expect(byName[n].properties.Color).toBe(ink)
        end
    end)

    test("nothing reaches higher than the shop, let alone the bell tower", function()
        -- The gate is a threshold, not a landmark. It must not compete with what it points at.
        local top = -math.huge
        for _, c in spec.children :: any do
            local _, hi = span(c, 2)
            top = math.max(top, hi)
        end
        expect(top <= 131.36).toBe(true) -- Hanabiya's ridge
        expect(top <= L.towerTopY - 9.0).toBe(true) -- the owner's subordination gap to the tower
    end)
end)
