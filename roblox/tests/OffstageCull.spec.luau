--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local OffstageCull = require("../tools/builders/OffstageCull")

local function v(x: number, y: number, z: number): OffstageCull.Vec3
    return { x = x, y = y, z = z }
end

local OPTS: OffstageCull.Options = {
    maxSight = 800,
    nearTrailRadius = 80,
    targetFrac = 0.15,
    hitTolerance = 6,
}

-- A world where the caller decides what is visible. `blocked` names the (viewIndex, treeId)
-- pairs that are occluded; `solidBehind` names the trees with rock behind them.
local function world(blocked: { [string]: boolean }, solidBehind: { [string]: boolean })
    local seen: { [string]: boolean } = blocked
    return {
        lineOfSight = function(fromIndex: number, tree: OffstageCull.Tree): boolean
            return not seen[`{fromIndex}:{tree.id}`]
        end,
        terrainBehind = function(_fromIndex: number, tree: OffstageCull.Tree): boolean
            return solidBehind[tree.id] == true
        end,
    }
end

local function byId(results: { OffstageCull.Result }): { [string]: OffstageCull.Result }
    local m = {}
    for _, r in results do
        m[r.id] = r
    end
    return m
end

describe("OffstageCull.classify", function()
    local trees: { OffstageCull.Tree } = {
        { id = "hidden", base = v(0, 300, 200), height = 10 },
        { id = "onSky", base = v(50, 300, 200), height = 10 },
        { id = "onRock", base = v(100, 200, 60), height = 10 },
    }
    local views = { v(0, 120, 0), v(400, 120, 0) }

    test("a tree no viewpoint can see is OFFSTAGE", function()
        local w = world({ ["1:hidden"] = true, ["2:hidden"] = true }, {})
        local r = byId(OffstageCull.classify(trees, views, w.lineOfSight, w.terrainBehind, OPTS))
        expect(r.hidden.class).toBe("OFFSTAGE")
        expect(r.hidden.angular).toBe(0)
    end)

    test("a visible tree with open sky behind it is SKYLINE", function()
        local w = world({}, {})
        local r = byId(OffstageCull.classify(trees, views, w.lineOfSight, w.terrainBehind, OPTS))
        expect(r.onSky.class).toBe("SKYLINE")
    end)

    test("a visible tree with terrain behind it is AGAINST_ROCK", function()
        local w = world({}, { onRock = true })
        local r = byId(OffstageCull.classify(trees, views, w.lineOfSight, w.terrainBehind, OPTS))
        expect(r.onRock.class).toBe("AGAINST_ROCK")
    end)

    test("nearestApproach ignores sight: proximity alone disqualifies an impostor", function()
        -- the tree is invisible from both viewpoints, yet one of them is 20 studs away
        local close = { { id = "hidden", base = v(0, 120, 20), height = 10 } }
        local w = world({ ["1:hidden"] = true, ["2:hidden"] = true }, {})
        local r = byId(OffstageCull.classify(close, views, w.lineOfSight, w.terrainBehind, OPTS))
        expect(r.hidden.class).toBe("OFFSTAGE")
        expect(r.hidden.nearestApproach < 80).toBe(true)
        expect(r.hidden.nearTrail).toBe(true)
    end)

    test("angular size uses the CLOSEST viewpoint that can actually see it", function()
        -- block the near viewpoint; the far one is 400 away, so 10/400 = 0.025
        local one = { { id = "t", base = v(0, 120, 0), height = 10 } }
        local w = world({ ["1:t"] = true }, {})
        local r = byId(OffstageCull.classify(one, views, w.lineOfSight, w.terrainBehind, OPTS))
        expect(math.abs(r.t.angular - 0.025) < 1e-6).toBe(true)
    end)

    test("viewpoints beyond maxSight are ignored entirely", function()
        local far = { { id = "t", base = v(5000, 120, 0), height = 10 } }
        local w = world({}, {})
        local r = byId(OffstageCull.classify(far, views, w.lineOfSight, w.terrainBehind, OPTS))
        expect(r.t.class).toBe("OFFSTAGE")
    end)

    test("with no viewpoints at all, everything is OFFSTAGE", function()
        local w = world({}, {})
        local r = OffstageCull.classify(trees, {}, w.lineOfSight, w.terrainBehind, OPTS)
        for _, e in r do
            expect(e.class).toBe("OFFSTAGE")
        end
    end)

    test("deterministic: identical inputs give identical output, in a stable order", function()
        local w = world({ ["1:onRock"] = true }, { onSky = true })
        local a = OffstageCull.classify(trees, views, w.lineOfSight, w.terrainBehind, OPTS)
        local b = OffstageCull.classify(trees, views, w.lineOfSight, w.terrainBehind, OPTS)
        expect(#a).toBe(#b)
        for i = 1, #a do
            expect(a[i].id).toBe(b[i].id)
            expect(a[i].class).toBe(b[i].class)
            expect(a[i].angular).toBe(b[i].angular)
        end
    end)

    test("summarise counts each class and the near-trail holdback", function()
        local w = world({ ["1:hidden"] = true, ["2:hidden"] = true }, { onRock = true })
        local s =
            OffstageCull.summarise(OffstageCull.classify(trees, views, w.lineOfSight, w.terrainBehind, OPTS))
        expect(s.offstage).toBe(1)
        expect(s.skyline).toBe(1)
        expect(s.againstRock).toBe(1)
    end)
end)
