--!strict
-- THE ONE RECIPE SCHEMA. FireworkCatalog (shipped) and FireworkDrafts (proving) both hold
-- recipes; this module is the single definition of what a well-formed one is, so a typo'd
-- draft fails `lune run tests/run` instead of silently rendering a blank sky in a Play
-- session (an emitter with Texture == "" renders NOTHING — the documented 2026-07-20 trap).
-- Pure, no Roblox globals; runs under Lune.
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
        if ph.kind == "burst" and (typeof(ph.texture) ~= "string" or ph.texture == "") then
            return false, `phase {i}: a burst must name a non-empty texture (blank-sky trap)`
        end
        for _, key in { "color", "edgeColor" } do
            if ph[key] ~= nil and not validColor(ph[key]) then
                return false, `phase {i}: '{key}' must be three numbers in 0..255`
            end
        end
    end
    return true, nil
end

return FireworkRecipes
