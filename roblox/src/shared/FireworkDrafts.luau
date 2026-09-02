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

-- 青 ao, blue: the ladder varies hue temperature at fixed spread.
local function ao(core: { number }, edge: { number })
    return {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin", sound = S_REPORT },
            { at = 0.02, kind = "ascent", anchor = "origin", color = { 160, 200, 255 } },
            {
                at = 3.0,
                kind = "burst",
                anchor = "apex",
                color = core,
                edgeColor = edge,
                spread = 40,
                droop = false,
            },
        },
    }
end

-- One color, three shapes: a SHAPE ladder. The variant name is the style it wears,
-- so a range ladder answers "which break suits this hue" in one firing.
local function shapeTrio(core: { number }, edge: { number }, ascent: { number })
    local function shell(style: string?, spread: number, points: number?, scatter: number?)
        return {
            phases = {
                { at = 0.0, kind = "report", anchor = "origin", sound = S_REPORT },
                { at = 0.02, kind = "ascent", anchor = "origin", color = ascent },
                {
                    at = 3.0,
                    kind = "burst",
                    anchor = "apex",
                    style = style,
                    color = core,
                    edgeColor = edge,
                    spread = spread,
                    points = points,
                    scatter = scatter,
                    droop = false,
                },
            },
        }
    end
    return {
        v1_peony = shell(nil, 42),
        v2_ring = shell("ring", 40),
        v3_palm = shell("palm", 34, 5, 6),
    }
end

FireworkDrafts.FAMILIES = {
    yashi = {
        v1 = yashi(4), -- owner's floor (2026-09-05: "four standard")
        v2 = yashi(5),
        v3 = yashi(6),
        -- BOOST PREVIEW at chance = 1 (owner, 2026-09-05: "sometimes 5 with a violet center
        -- kicker that is also streaks, not stars"): the fifth arm arrives via boost.points,
        -- the pop is violet velocity-parallel streaks. Deleted at promotion.
        boosted = {
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
                    points = 4,
                    scatter = 6,
                    droop = false,
                    boost = {
                        chance = 1,
                        points = 1,
                        glow = 1.15,
                        lifeScale = 1.1,
                        kickerColor = { 190, 90, 255 },
                        kickerStreaks = true,
                    },
                },
            },
        },
    },
    hotaru = {
        v1 = hotaru(24),
        v2 = hotaru(36),
        v3 = hotaru(48),
    },
    -- 青 ao, the blue: bright saturated blue peony. Blue is the HARDEST color in real
    -- pyro (copper compounds quench at flame temperatures), the mark of a serious maker
    -- -- which is exactly the premium story for the shelf. The ladder walks azure ->
    -- cobalt -> electric.
    ao = {
        v1 = ao({ 70, 150, 255 }, { 180, 220, 255 }),
        v2 = ao({ 40, 100, 255 }, { 140, 190, 255 }),
        v3 = ao({ 90, 180, 255 }, { 220, 240, 255 }),
    },
    -- 緑 midori: barium emerald, the classic vivid pyro green.
    midori = shapeTrio({ 60, 255, 110 }, { 180, 255, 190 }, { 150, 255, 180 }),
    -- 紫 murasaki: royal violet, historically a premium shell color.
    murasaki = shapeTrio({ 170, 60, 255 }, { 220, 170, 255 }, { 210, 170, 255 }),
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
