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
local BurstStyles = require("./BurstStyles")

local FireworkDrafts = {}

-- 蛍 hotaru, strobe: a hanging cloud that flickers. The ladder varies spread.
local function hotaru(spread: number)
    return {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin" },
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

-- 黄金 kamuro, golden crown: long heavy drooping arms — and FLASHY now (owner, 2026-09-06:
-- "not flashy enough, even at the largest size"). Every shell carries the big eardeer boom
-- at starburst (salute_single pinned on the burst), and the boost kicker is a 3-4 salute
-- SALVO. The report pins the L tube's heavy grunt because drafts have no SHELL_MORTAR
-- entry and kamuro is bound for the L tube (owner: "kamuro L sounds right") — at
-- promotion the pin drops and SHELL_MORTAR's mortar:L resolves it. Ladder varies hang time.
local function kamuro(burstAt: number, boost: any?)
    return {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin", sound = BurstStyles.SOUNDS.launch_heavy },
            { at = 0.02, kind = "ascent", anchor = "origin", color = { 255, 200, 120 } },
            {
                at = burstAt,
                kind = "burst",
                anchor = "apex",
                style = "kamuro",
                color = { 255, 170, 40 },
                edgeColor = { 255, 220, 140 },
                droop = false,
                sound = BurstStyles.SOUNDS.salute_single, -- the always-boom, every shell
                boost = boost,
            },
        },
    }
end

-- Colorway ruling (owner, 2026-09-06): signature hues sell in the shop, colorways live in
-- COLLECTIONS. The ao/midori/murasaki hue families that auditioned here were reframed as
-- collection palette material and pruned -- git history is the archive (last present at
-- commit 2cd90b4, with the ao and shapeTrio helpers).
FireworkDrafts.FAMILIES = {
    hotaru = {
        v1 = hotaru(24),
        v2 = hotaru(36),
        v3 = hotaru(48),
    },
    kamuro = {
        v1 = kamuro(2.8),
        v2 = kamuro(3.0),
        v3 = kamuro(3.2),
        -- BOOST PREVIEW at chance = 1 (owner, 2026-09-06): the salvo kicker — 3-4 aerial
        -- salutes in variable grouping above the crown. Deleted at promotion.
        boosted = kamuro(3.0, { chance = 1, salvo = { count = { 3, 4 } } }),
    },
    dan = {
        v1 = {
            phases = {
                { at = 0.0, kind = "report", anchor = "origin" },
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
