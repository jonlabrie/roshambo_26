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

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local S_REPORT = "rbxasset://sounds/collide.wav"
local S_ASCENT = "rbxasset://sounds/swoosh.wav"
local S_BURST = "rbxasset://sounds/impact_explosion_03.mp3"

-- 菊 kiku, chrysanthemum: a tight peony with a distinct edge tint. The seed ladder —
-- three spreads of the same idea so the range's first session has a real comparison.
local function kiku(spread: number, edge: { number })
    return {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin", sound = S_REPORT },
            { at = 0.02, kind = "ascent", anchor = "origin", sound = S_ASCENT, color = { 255, 214, 130 } },
            {
                at = 1.15,
                kind = "burst",
                anchor = "apex",
                sound = S_BURST,
                texture = SPARKLE,
                color = { 255, 190, 90 },
                edgeColor = edge,
                spread = spread,
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
