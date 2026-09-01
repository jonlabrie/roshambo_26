--!strict
-- THE PROVING RANGE'S WORKING FILE. Families of candidate recipes, same format as
-- FireworkCatalog.RECIPES (see its header), fired at the range as "draft:<family>/<variant>".
-- Claude authors here; the owner judges in Play; an approved variant MOVES to FireworkCatalog
-- (plus the shared fixture and server/src/fireworks.ts) and the rest of its family is pruned in
-- the same or a following commit — git history is the archive, this file stays short.
--
-- NEVER add a draft to shared-fixtures/firework-shells.json: the CI contract would then demand
-- the server price it. Every entry here is schema-checked by FireworkDrafts.spec against
-- FireworkRecipes, so a typo fails `lune run tests/run` rather than rendering a blank sky.
-- Pure data + string parsing, no Roblox globals; runs under Lune.
local FireworkDrafts = {}

local S_REPORT = "rbxassetid://87713703495045" -- launch-deck-2 (owner pick, 2026-09-03)

-- 菊 kiku, chrysanthemum: a tight peony with a distinct edge tint. The seed ladder —
-- three spreads of the same idea so the range's first session has a real comparison.
local function kiku(spread: number, edge: { number })
    return {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin", sound = S_REPORT },
            { at = 0.02, kind = "ascent", anchor = "origin", color = { 255, 214, 130 } },
            {
                at = 3.0,
                kind = "burst",
                anchor = "apex",
                color = { 255, 190, 90 },
                edgeColor = edge,
                spread = spread,
                droop = false,
            },
        },
    }
end

-- 輪 wa, ring: a planar circle of points. The ladder varies spread.
local function wa(spread: number)
    return {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin", sound = S_REPORT },
            { at = 0.02, kind = "ascent", anchor = "origin", color = { 255, 180, 100 } },
            {
                at = 3.0,
                kind = "burst",
                anchor = "apex",
                style = "ring",
                color = { 255, 60, 40 },
                edgeColor = { 255, 240, 220 },
                spread = spread,
                droop = false,
            },
        },
    }
end

-- 椰子 yashi, palm: thick outward-aimed arms. The ladder varies point count.
local function yashi(points: number)
    return {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin", sound = S_REPORT },
            { at = 0.02, kind = "ascent", anchor = "origin", color = { 255, 210, 140 } },
            {
                at = 3.0,
                kind = "burst",
                anchor = "apex",
                style = "palm",
                color = { 255, 180, 60 },
                edgeColor = { 255, 230, 160 },
                points = points,
                scatter = 6,
                droop = false,
            },
        },
    }
end

-- 蛍 hotaru, strobe: a hanging cloud that flickers. The ladder varies spread.
local function hotaru(spread: number)
    return {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin", sound = S_REPORT },
            { at = 0.02, kind = "ascent", anchor = "origin", color = { 210, 225, 245 } },
            {
                at = 3.0,
                kind = "burst",
                anchor = "apex",
                style = "strobe",
                color = { 235, 245, 255 },
                edgeColor = { 180, 220, 255 },
                spread = spread,
                droop = false,
            },
        },
    }
end

-- 黄金 kamuro, golden crown: long heavy drooping arms. The ladder varies burst hang time.
local function kamuro(burstAt: number)
    return {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin", sound = S_REPORT },
            { at = 0.02, kind = "ascent", anchor = "origin", color = { 255, 200, 120 } },
            {
                at = burstAt,
                kind = "burst",
                anchor = "apex",
                style = "kamuro",
                color = { 255, 170, 40 },
                edgeColor = { 255, 220, 140 },
                droop = false,
            },
        },
    }
end

FireworkDrafts.FAMILIES = {
    kiku = {
        v1 = kiku(28, { 255, 240, 200 }),
        v2 = kiku(38, { 255, 150, 60 }),
        v3 = kiku(50, { 200, 90, 40 }),
    },
    wa = {
        v1 = wa(30),
        v2 = wa(42),
        v3 = wa(56),
    },
    yashi = {
        v1 = yashi(4),
        v2 = yashi(5),
        v3 = yashi(6),
    },
    hotaru = {
        v1 = hotaru(24),
        v2 = hotaru(36),
        v3 = hotaru(48),
    },
    kamuro = {
        v1 = kamuro(2.8),
        v2 = kamuro(3.0),
        v3 = kamuro(3.2),
    },
    dan = {
        v1 = {
            phases = {
                { at = 0.0, kind = "report", anchor = "origin", sound = S_REPORT },
                {
                    at = 0.02,
                    kind = "ascent",
                    anchor = "origin",
                    color = { 255, 214, 130 },
                },
                {
                    at = 3.0,
                    kind = "burst",
                    anchor = "apex",
                    color = { 255, 190, 90 },
                    edgeColor = { 200, 100, 50 },
                    spread = 30,
                    droop = false,
                    share = 2,
                },
                {
                    at = 3.6,
                    kind = "burst",
                    anchor = "apex",
                    style = "strobe",
                    color = { 235, 245, 255 },
                    edgeColor = { 180, 220, 255 },
                    points = 5,
                    scatter = 9,
                    droop = false,
                    share = 1,
                },
                {
                    at = 4.5,
                    kind = "burst",
                    anchor = "apex",
                    style = "kamuro",
                    color = { 255, 170, 40 },
                    edgeColor = { 255, 220, 140 },
                    droop = false,
                    share = 1,
                },
            },
        },
    },
} :: { [string]: { [string]: any } }

function FireworkDrafts.resolve(id: string): any?
    local family, variant = id:match("^draft:([%w_]+)/([%w_]+)$")
    if family == nil or variant == nil then
        return nil
    end
    local fam = FireworkDrafts.FAMILIES[family :: string]
    return fam and fam[variant :: string] or nil
end

function FireworkDrafts.variantsOf(family: string): { string }
    local out: { string } = {}
    local fam = FireworkDrafts.FAMILIES[family]
    if fam then
        for name in fam do
            table.insert(out, name)
        end
        table.sort(out)
    end
    return out
end

function FireworkDrafts.familyNames(): { string }
    local out: { string } = {}
    for name in FireworkDrafts.FAMILIES do
        table.insert(out, name)
    end
    table.sort(out)
    return out
end

return FireworkDrafts
