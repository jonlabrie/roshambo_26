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
    -- heavy (owner, 2026-09-06: L shells "really need to be impressive"): the shell emits
    -- at WEIGHT_HEAVY x the particle budget and is charged that many admission slots, so
    -- the weighted sky total the mobile floor was measured against never grows. Catalog
    -- heavies must live in the L tube -- FireworkCatalog.spec holds that line.
    if recipe.heavy ~= nil and typeof(recipe.heavy) ~= "boolean" then
        return false, "heavy must be a boolean"
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
        local staged = {
            style = ph.style,
            points = ph.points,
            scatter = ph.scatter,
            share = ph.share,
            glow = ph.glow,
            boost = ph.boost,
        }
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
            if ph.glow ~= nil and (typeof(ph.glow) ~= "number" or ph.glow <= 0 or ph.glow > 4) then
                return false, `phase {i}: glow must be a number in (0, 4]`
            end
            -- A burst may carry a BOOST: a seeded per-phase chance of an upgraded break
            -- (owner design, 2026-09-04: "v2 is the floor but there's a 30% chance you'll
            -- get a larger radius, more stars"). All multipliers are budget-neutral by
            -- construction -- extra points DIVIDE the budget, never add particles.
            if ph.boost ~= nil then
                local b = ph.boost
                if typeof(b) ~= "table" then
                    return false, `phase {i}: boost must be a table`
                end
                if typeof(b.chance) ~= "number" or b.chance <= 0 or b.chance > 1 then
                    return false, `phase {i}: boost.chance must be a number in (0, 1]`
                end
                for _, key in { "spread", "glow", "lifeScale" } do
                    local v = (b :: any)[key]
                    if v ~= nil and (typeof(v) ~= "number" or v <= 0 or v > 4) then
                        return false, `phase {i}: boost.{key} must be a number in (0, 4]`
                    end
                end
                if
                    b.points ~= nil
                    and (
                        typeof(b.points) ~= "number"
                        or b.points % 1 ~= 0
                        or b.points < 1
                        or b.points > BurstStyles.MAX_POINTS - 1
                    )
                then
                    return false,
                        `phase {i}: boost.points must be an integer 1..{BurstStyles.MAX_POINTS - 1} (added to the base)`
                end
                -- The kicker's star color. Optional; absent means the default warm white.
                if b.kickerColor ~= nil and not validColor(b.kickerColor) then
                    return false, `phase {i}: boost.kickerColor must be a 3-element 0-255 array`
                end
                -- kicker = false opts a recipe out of the star pop + double-tap entirely
                -- (owner, 2026-09-05: wa's double ring IS the tell; the kicker is for shells
                -- whose surprise needs selling). Absent means true.
                if b.kicker ~= nil and typeof(b.kicker) ~= "boolean" then
                    return false, `phase {i}: boost.kicker must be a boolean`
                end
                -- kickerStreaks: the pop renders as velocity-parallel streaks instead of dots
                -- (owner, 2026-09-05: yashi's violet center kicker "is also streaks, not stars").
                if b.kickerStreaks ~= nil and typeof(b.kickerStreaks) ~= "boolean" then
                    return false, `phase {i}: boost.kickerStreaks must be a boolean`
                end
                -- salvo (owner, 2026-09-06): the kicker as a GROUPING of aerial salutes --
                -- count drawn per lucky shell, gaps drawn per shot ("variable grouping").
                -- Replaces the star pop + double-tap when present. Count admits 1..8: 3-4
                -- is kamuro's kicker, 5-8 reserved for standalone salute shells.
                if b.salvo ~= nil then
                    local s = b.salvo
                    if typeof(s) ~= "table" then
                        return false, `phase {i}: boost.salvo must be a table`
                    end
                    local c = s.count
                    if
                        typeof(c) ~= "table"
                        or typeof(c[1]) ~= "number"
                        or typeof(c[2]) ~= "number"
                        or c[1] % 1 ~= 0
                        or c[2] % 1 ~= 0
                        or c[1] < 1
                        or c[2] > 8
                        or c[1] > c[2]
                    then
                        return false, `phase {i}: boost.salvo.count must be an ordered integer pair in 1..8`
                    end
                    local g = s.gap
                    if
                        g ~= nil
                        and (
                            typeof(g) ~= "table"
                            or typeof(g[1]) ~= "number"
                            or typeof(g[2]) ~= "number"
                            or g[1] < 0.05
                            or g[2] > 1
                            or g[1] > g[2]
                        )
                    then
                        return false, `phase {i}: boost.salvo.gap must be an ordered seconds pair in 0.05..1`
                    end
                end
            end
            -- boostOnly (owner, 2026-09-05): the structural half of a surprise -- a phase that
            -- exists only when the shell's boost roll hits (wa's second concentric ring). It
            -- must have a roll to key off: some OTHER phase in the recipe must carry `boost`,
            -- or the phase can never fire and the recipe is lying about its own contents.
            if ph.boostOnly ~= nil then
                if typeof(ph.boostOnly) ~= "boolean" then
                    return false, `phase {i}: boostOnly must be a boolean`
                end
                if ph.boostOnly then
                    local hasRoll = false
                    for _, other in recipe.phases do
                        if other ~= ph and other.boost ~= nil then
                            hasRoll = true
                        end
                    end
                    if not hasRoll then
                        return false,
                            `phase {i}: boostOnly requires another phase carrying boost (nothing rolls the luck it keys off)`
                    end
                end
            end
        end
    end
    return true, nil
end

return FireworkRecipes
