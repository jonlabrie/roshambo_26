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

-- Colorway ruling (owner, 2026-09-06): signature hues sell in the shop, colorways live in
-- COLLECTIONS. The ao/midori/murasaki hue families that auditioned here were reframed as
-- collection palette material and pruned -- git history is the archive (last present at
-- commit 2cd90b4, with the ao and shapeTrio helpers).
-- 段 dan, the three-act show (owner design 2026-09-06, superseding the vocabulary-era
-- demo): act one, four SMALL peonies in colors dealt per shell from a five-color deck,
-- staggered; act two, the strobe with its pops and sizzle; act three, WHIZZERS -- comets
-- racing off in random directions, whistling, dead in half a second. The boost (the
-- audition's `boosted`) adds the encore: a salute salvo after the whizzers. L tube +
-- heavy (owner ruling). The ladder varies WHIZZER COUNT: v1 = 3, v2 = 4, v3 = 5.
local DAN_COLORS = {
    { 170, 60, 255 }, -- violet
    { 60, 255, 110 }, -- green
    { 70, 150, 255 }, -- blue
    { 255, 160, 60 }, -- orange
    { 255, 60, 50 }, -- red
}

-- Act redesign 2026-09-06 (owner, superseding the whizzer act same day): act two is
-- three CLUSTERS OF THROW GLYPHS -- rock, paper, scissors, one texture pin per phase --
-- that fall and then FLICKER into the shimmer (glyphfall's transparency curve carries
-- the act-two-to-three transition per glyph; whizzers stay in the vocabulary for a
-- future shell). The ladder varies ACT-ONE SEPARATION -- the owner's note: the small
-- peonies "should be spread out" -- via scatter (each mini-peony's single break point
-- lands that far from the apex), with glow 1.5 for the brightness note.
local function dan(separation: number, boost: any?)
    local function act1(at: number)
        return {
            at = at,
            kind = "burst",
            anchor = "apex",
            colorPool = DAN_COLORS,
            spread = 22, -- "smaller versions of our peony burst"
            scatter = separation,
            glow = 1.5,
            droop = false,
            share = 1,
        }
    end
    local function glyphs(at: number, texture: string, boostArg: any?)
        return {
            at = at,
            kind = "burst",
            anchor = "apex",
            style = "glyphfall",
            texture = texture,
            color = { 255, 255, 255 },
            droop = false,
            share = 2,
            boost = boostArg,
        }
    end
    return {
        heavy = true,
        phases = {
            { at = 0.0, kind = "report", anchor = "origin" },
            { at = 0.02, kind = "ascent", anchor = "origin", color = { 255, 214, 130 } },
            act1(3.0),
            act1(3.25),
            act1(3.5),
            act1(3.75),
            glyphs(4.8, BurstStyles.TEXTURES.glyph_rock),
            glyphs(4.95, BurstStyles.TEXTURES.glyph_paper),
            -- boost rides the LAST glyph phase: the salvo encore keys off its life and
            -- lands as the shimmer fades.
            glyphs(5.1, BurstStyles.TEXTURES.glyph_scissors, boost),
        },
    }
end

FireworkDrafts.FAMILIES = {
    dan = {
        v1 = dan(16),
        v2 = dan(26),
        v3 = dan(36),
        -- BOOST PREVIEW at chance = 1: the encore -- a 3-4 salute salvo as the glyph
        -- shimmer fades. Deleted at promotion.
        boosted = dan(26, { chance = 1, salvo = { count = { 3, 4 } } }),
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
