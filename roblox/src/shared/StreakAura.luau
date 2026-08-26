--!strict
-- How hard a player glows for the win-streak they currently have MONEY ON, and who is allowed to
-- see it.
--
-- ⚠ PURE, AND IT NAMES NO ROBLOX TYPE. This file is Lune-tested, and a `Color3` here breaks the
-- entire test run at require time — that is exactly what happened to `Kamon`, whose renderer had to
-- be split out into `KamonDraw`. `heat` is a number; the controller turns it into a colour.
--
-- ⚠ RARITY IS THE DESIGN. About a third of players win any given round, so a 3-streak is roughly
-- 1 in 27 and a 5-streak 1 in 240: the arena is dark most of the time and the glow is scarce
-- exactly when it is impressive. Four worn answers were rejected before this one, and the worn
-- sashimono failed on precisely this axis — everyone wore one at once. Lowering MIN_STREAK turns
-- this back into that.
local StreakAura = {}

StreakAura.MIN_STREAK = 3
local SATURATE_AT = 8 -- a 12-streak and a 30-streak look the same

-- Endpoints, floor -> saturated. Fill carries the signal; outline supports it; heat is decoration.
-- ⚠ Colour is deliberately the THIRD channel: a colourblind player must read the aura from fill
-- and outline alone, and the program bar is kid-first on phones.
local FILL_NEAR, FILL_FAR = 0.85, 0.55
local OUTLINE_NEAR, OUTLINE_FAR = 0.6, 0.15

StreakAura.VISIBILITY = { HIDDEN = "HIDDEN", FRIENDS = "FRIENDS", PUBLIC = "PUBLIC" }

-- The system's per-moment override. NOT persisted, and not symmetric — see `shows`.
StreakAura.FORCE = { HIDE = "HIDE", SHOW = "SHOW", SHOW_EVEN_IF_HIDDEN = "SHOW_EVEN_IF_HIDDEN" }

export type Context = {
    streak: number,
    visibility: string?, -- the SUBJECT's choice; absent means PUBLIC
    isSelf: boolean?,
    isFriend: boolean?,
    viewerWantsAuras: boolean?, -- the VIEWER's own preference; absent means yes
    force: string?,
}

function StreakAura.isVisibility(v: any): boolean
    return v == StreakAura.VISIBILITY.HIDDEN
        or v == StreakAura.VISIBILITY.FRIENDS
        or v == StreakAura.VISIBILITY.PUBLIC
end

function StreakAura.visible(streak: number): boolean
    return streak >= StreakAura.MIN_STREAK
end

-- Fill transparency, outline transparency, and heat (0..1) for a streak.
function StreakAura.poseFor(streak: number): (number, number, number)
    if not StreakAura.visible(streak) then
        return 1, 1, 0
    end
    local span = math.max(1, SATURATE_AT - StreakAura.MIN_STREAK)
    local heat = math.clamp((streak - StreakAura.MIN_STREAK) / span, 0, 1)
    return FILL_NEAR + (FILL_FAR - FILL_NEAR) * heat, OUTLINE_NEAR + (OUTLINE_FAR - OUTLINE_NEAR) * heat, heat
end

-- Does THIS viewer see THIS subject's aura?
--
-- ⚠ FORCE IS NOT SYMMETRIC, AND THAT ASYMMETRY IS THE WHOLE POINT. Forcing a PUBLIC player hidden
-- costs them nothing — it is what a client should do when twenty people are glowing on a phone.
-- Forcing a HIDDEN player visible overrides a privacy choice they made deliberately, so it is a
-- SEPARATE VALUE a caller has to name: `SHOW` lifts only the friends gate, and
-- `SHOW_EVEN_IF_HIDDEN` is the one that overrides an explicit hide. No caller reaches it by
-- accident, which is the point.
--
-- Precedence, and the order matters more than any single rule:
--   1. the VIEWER's own off-switch, above every force value — an override exists to make a moment
--      legible, not to put something on a screen whose owner turned it off
--   2. force HIDE
--   3. no streak worth showing — an override changes WHO sees a streak, never whether one exists
--   4. your own aura, whatever you chose: hiding from other players is not hiding from yourself
--   5. the subject's own setting
function StreakAura.shows(ctx: Context): boolean
    if ctx.viewerWantsAuras == false then
        return false
    end
    if ctx.force == StreakAura.FORCE.HIDE then
        return false
    end
    if not StreakAura.visible(ctx.streak) then
        return false
    end
    if ctx.isSelf then
        return true
    end

    -- ⚠ An UNRECOGNISED value is treated as PUBLIC, the same as an absent one. That is only safe
    -- because the datum itself is already public — the 番付 room shows live runs to everyone. Do
    -- not copy this defaulting to a field that guards something private.
    local vis = if StreakAura.isVisibility(ctx.visibility)
        then ctx.visibility
        else StreakAura.VISIBILITY.PUBLIC

    if vis == StreakAura.VISIBILITY.HIDDEN then
        return ctx.force == StreakAura.FORCE.SHOW_EVEN_IF_HIDDEN
    end
    if vis == StreakAura.VISIBILITY.FRIENDS then
        return ctx.isFriend == true
            or ctx.force == StreakAura.FORCE.SHOW
            or ctx.force == StreakAura.FORCE.SHOW_EVEN_IF_HIDDEN
    end
    return true
end

return StreakAura
