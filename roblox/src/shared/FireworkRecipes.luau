--!strict
-- THE ONE RECIPE SCHEMA. FireworkCatalog (shipped) and FireworkDrafts (proving) both hold
-- recipes; this module is the single definition of what a well-formed one is, so a typo'd
-- draft fails `lune run tests/run` instead of silently rendering a blank sky in a Play
-- session (an emitter with Texture == "" renders NOTHING — the documented 2026-07-20 trap).
-- Pure, no Roblox globals; runs under Lune.
local BurstStyles = require("./BurstStyles")
local FireworkRecipes = {}

-- The phase kinds FireworkController can draw. The vocabulary project widens this table;
-- widening it here without teaching the controller the word is exactly the drift this
-- module exists to catch, so the two must move together.
FireworkRecipes.KINDS = { report = true, ascent = true, burst = true } :: { [string]: boolean }

local ANCHORS = { origin = true, apex = true }

local function validColor(c: any): boolean
    if typeof(c) ~= "table" or #c ~= 3 then
        return false
    end
    for _, v in c :: { any } do
        if typeof(v) ~= "number" or v < 0 or v > 255 then
            return false
        end
    end
    return true
end

function FireworkRecipes.validate(recipe: any): (boolean, string?)
    if typeof(recipe) ~= "table" or typeof(recipe.phases) ~= "table" or #recipe.phases == 0 then
        return false, "a recipe is a table with a non-empty phases array"
    end
    local prevAt = 0
    for i, ph in recipe.phases :: { any } do
        if typeof(ph) ~= "table" then
            return false, `phase {i}: not a table`
        end
        if not FireworkRecipes.KINDS[ph.kind] then
            return false, `phase {i}: unknown kind '{tostring(ph.kind)}'`
        end
        if typeof(ph.at) ~= "number" or ph.at < 0 or ph.at < prevAt then
            return false, `phase {i}: 'at' must be a non-negative, non-decreasing number`
        end
        prevAt = ph.at
        if not ANCHORS[ph.anchor] then
            return false, `phase {i}: anchor must be 'origin' or 'apex'`
        end
        -- A burst MAY omit `texture`: the style's textureRole resolves one at render, and
        -- BurstStyles' tests guarantee every role id is non-empty — the blank-sky trap moved
        -- there (2026-09-03, after pinned recipe textures made the uploaded sprites
        -- unreachable: the recipe always won over the role). An EMPTY texture is still the
        -- trap and still fails.
        if
            ph.kind == "burst"
            and ph.texture ~= nil
            and (typeof(ph.texture) ~= "string" or ph.texture == "")
        then
            return false, `phase {i}: a burst's texture, when named, must be a non-empty string`
        end
        for _, key in { "color", "edgeColor" } do
            if ph[key] ~= nil and not validColor(ph[key]) then
                return false, `phase {i}: '{key}' must be three numbers in 0..255`
            end
        end
        local staged = { style = ph.style, points = ph.points, scatter = ph.scatter, share = ph.share }
        if ph.kind ~= "burst" then
            for field, v in staged do
                if v ~= nil then
                    return false, `phase {i}: '{field}' is a burst field`
                end
            end
        else
            if ph.style ~= nil and BurstStyles.STYLES[ph.style] == nil then
                return false, `phase {i}: unknown style '{tostring(ph.style)}'`
            end
            if ph.points ~= nil then
                if
                    typeof(ph.points) ~= "number"
                    or ph.points % 1 ~= 0
                    or ph.points < 1
                    or ph.points > BurstStyles.MAX_POINTS
                then
                    return false, `phase {i}: points must be an integer 1..{BurstStyles.MAX_POINTS}`
                end
            end
            if ph.scatter ~= nil and (typeof(ph.scatter) ~= "number" or ph.scatter < 0) then
                return false, `phase {i}: scatter must be a non-negative number`
            end
            if ph.share ~= nil and (typeof(ph.share) ~= "number" or ph.share <= 0) then
                return false, `phase {i}: share must be a positive number`
            end
        end
    end
    return true, nil
end

return FireworkRecipes
