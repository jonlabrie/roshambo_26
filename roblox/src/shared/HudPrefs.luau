--!strict
-- The HUD preferences merge/default rule, in ONE place. Pure: no Roblox globals, no I/O, so it
-- runs under Lune — unlike main.server.luau, which is a Roblox-runtime file Lune never loads and
-- so cannot be covered by this repo's test harness at all.
--
-- This exists because the rule used to live inline in main.server.luau's SetHudPreference handler,
-- correct by reading, unguarded by any test: a future edit that replaced the merge base with a
-- fresh `{escalationPrompts = true, resultSplash = true}` literal — discarding `current` entirely
-- — was the exact bug this task was shaped to avoid, one layer deeper, and nothing caught it.
-- Extracting the rule here gives it a home a Lune test CAN see.
local HudPrefs = {}

export type Prefs = {
    escalationPrompts: boolean,
    resultSplash: boolean,
    statusBars: boolean,
    -- Who may see this player's streak aura: HIDDEN | FRIENDS | PUBLIC. ⚠ The first NON-BOOLEAN
    -- member of this table, so it cannot use the `type(x) == "boolean"` guard its neighbours use.
    auraVisibility: string,
}
export type Patch = {
    escalationPrompts: boolean?,
    resultSplash: boolean?,
    statusBars: boolean?,
    auraVisibility: string?,
}

-- ⚠ DUPLICATED FROM `StreakAura.VISIBILITY` ON PURPOSE. Requiring StreakAura here would put a
-- rendering concern inside the preferences rule, and this file is the one that must stay boring.
-- Three string constants that have never changed are a cheaper coupling than that; if a fourth
-- ever appears, both lists fail their own tests loudly rather than drifting.
local VISIBILITIES = { HIDDEN = true, FRIENDS = true, PUBLIC = true }
local DEFAULT_VISIBILITY = "PUBLIC"

-- Absent = both ON. This is the profile's own default (see server/src/models/User.ts), so a fresh
-- row and a row this server has never seen must agree with it.
HudPrefs.DEFAULTS = {
    escalationPrompts = true,
    resultSplash = true,
    statusBars = true,
    auraVisibility = DEFAULT_VISIBILITY,
} :: Prefs

-- Returns a NEW table — never mutates `current`. A caller holding the pre-merge row (the
-- failure-revert in SetHudPreference) must still see the value it captured, not one this merge
-- edited out from under it.
--
-- Only keys PRESENT in `patch` AND holding a boolean overwrite `current`'s value; anything else
-- (nil, a missing key, a stray string) leaves `current`'s value alone. One remote carries every
-- preference, so a body naming only one of them must never silently reset the other to a default.
-- Is this a value `auraVisibility` may take? Exposed because main.server.luau must validate a
-- remote's body before it reaches the queue, and that file is a Roblox-runtime file Lune never
-- loads -- so the rule has to live HERE, where a test can see it.
function HudPrefs.isVisibility(v: any): boolean
    return VISIBILITIES[v] == true
end

function HudPrefs.merge(current: Prefs, patch: Patch): Prefs
    local next: Prefs = {
        escalationPrompts = current.escalationPrompts,
        resultSplash = current.resultSplash,
        statusBars = current.statusBars,
        auraVisibility = current.auraVisibility or DEFAULT_VISIBILITY,
    }
    if type(patch.escalationPrompts) == "boolean" then
        next.escalationPrompts = patch.escalationPrompts
    end
    if type(patch.resultSplash) == "boolean" then
        next.resultSplash = patch.resultSplash
    end
    if type(patch.statusBars) == "boolean" then
        next.statusBars = patch.statusBars
    end
    -- ⚠ VALIDATED AGAINST THE SET, not merely type-checked. An unrecognised string must leave the
    -- stored value ALONE — a privacy setting knocked back to a default by a malformed body, or by
    -- a caller's typo, is worse than one that refuses the write.
    if VISIBILITIES[patch.auraVisibility] then
        next.auraVisibility = patch.auraVisibility :: string
    end
    return next
end

-- The wire shape of a GET /players response's preference half, defaulted the same way everywhere
-- it is read: absent (or anything but literal `false`) means ON, because that is what the
-- database defaults to for documents written before these fields existed (no migration was run).
function HudPrefs.fromProfile(data: any): Prefs
    return {
        escalationPrompts = data.escalationPrompts ~= false,
        resultSplash = data.resultSplash ~= false,
        -- The grade/rank bars over other players' heads. Same absent-means-ON rule as its
        -- neighbours: no migration was run, so a row written before this field existed must read
        -- as enabled rather than silently hiding a feature.
        statusBars = data.statusBars ~= false,
        -- Absent means PUBLIC, the same absent-means-permissive rule as its neighbours, and safe
        -- for the same reason it is safe in StreakAura: a streak is ALREADY public in the 番付
        -- room. An unrecognised value defaults too — no migration was run, so a row written before
        -- this field existed must read as PUBLIC rather than as silently hidden.
        auraVisibility = if VISIBILITIES[data.auraVisibility]
            then data.auraVisibility
            else DEFAULT_VISIBILITY,
    }
end

return HudPrefs
