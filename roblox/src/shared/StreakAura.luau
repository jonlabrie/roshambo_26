--!strict
-- How hard a player glows for the win-streak they currently have MONEY ON, and who is allowed to
-- see it.
--
-- ⚠ PURE, AND IT NAMES NO ROBLOX TYPE. This file is Lune-tested, and a `Color3` here breaks the
-- entire test run at require time — that is exactly what happened to `Kamon`, whose renderer had to
-- be split out into `KamonDraw`. `heat` is a number; the controller turns it into a colour.
--
-- ⚠ THE FLOOR IS AN ACCESS DECISION, NOT A TUNING NUMBER. This module first argued the opposite:
-- that rarity was the design, a 3-streak being ~1 in 27 so the arena stays dark. The owner's answer
-- on seeing it in play was "who cares about auras if only 2 or 3 are ever even visible on your
-- server?" Scarcity does stop clutter — but a signal almost nobody can display is a lottery, not a
-- flex. Owner ruling 2026-08-25: the floor is 2. "Let the kids dress up if they want."
--
-- ⚠ AND THE SIGNAL IS MOTION, NOT BRIGHTNESS. Owner: "the differences in color are not obvious (at
-- least, not in the singular)". Exactly right, and it is a flaw in the channel rather than the
-- palette: a transparency ramp is only readable COMPARATIVELY, and with the floor this low a lone
-- glowing player is the ordinary case. Rate and tempo can be read off one body — you count them.
-- So `emitRate` and `pulsePeriod` carry the streak, and the fill is only a faint floor under them.
local StreakAura = {}

StreakAura.MIN_STREAK = 2
local SATURATE_AT = 8 -- a 12-streak and a 30-streak look the same

-- Endpoints, floor -> saturated. Fill carries the signal; outline supports it; heat is decoration.
-- ⚠ Colour is deliberately the THIRD channel: a colourblind player must read the aura from fill
-- and outline alone, and the program bar is kid-first on phones.
-- ⚠ THE FILL IS DELIBERATELY FAINT. A Highlight is what Studio uses for selection and hover, and at
-- strength it reads as an editor affordance washing the avatar out — which is why the first version
-- was "not very compelling" (owner). It is a floor under the particles now, not the effect itself.
local FILL_NEAR, FILL_FAR = 0.95, 0.85
local OUTLINE_NEAR, OUTLINE_FAR = 0.7, 0.3

-- Particles per second, floor -> saturated. Countable, which is the whole point.
local RATE_NEAR, RATE_FAR = 6, 40
-- Seconds per pulse of the rim. A tempo is countable where a brightness is not.
local PERIOD_NEAR, PERIOD_FAR = 1.6, 0.7

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

-- 0..1 across the streak range, saturating. The shared curve behind every channel.
local function heatFor(streak: number): number
    if not StreakAura.visible(streak) then
        return 0
    end
    local span = math.max(1, SATURATE_AT - StreakAura.MIN_STREAK)
    return math.clamp((streak - StreakAura.MIN_STREAK) / span, 0, 1)
end

-- Fill transparency, outline transparency, and heat (0..1) for a streak.
function StreakAura.poseFor(streak: number): (number, number, number)
    if not StreakAura.visible(streak) then
        return 1, 1, 0
    end
    local heat = heatFor(streak)
    return FILL_NEAR + (FILL_FAR - FILL_NEAR) * heat, OUTLINE_NEAR + (OUTLINE_FAR - OUTLINE_NEAR) * heat, heat
end

-- Particles per second. ⚠ THE PRIMARY CHANNEL, because it is the one a viewer can read off a single
-- player: you count a trickle against a stream. Transparency needed a second player beside you.
function StreakAura.emitRate(streak: number): number
    if not StreakAura.visible(streak) then
        return 0
    end
    return RATE_NEAR + (RATE_FAR - RATE_NEAR) * heatFor(streak)
end

-- Seconds per pulse of the rim: slower at the floor, quicker as the run deepens.
function StreakAura.pulsePeriod(streak: number): number
    return PERIOD_NEAR + (PERIOD_FAR - PERIOD_NEAR) * heatFor(streak)
end

-- The rim's 0..1 brightness multiplier at a moment. Never below zero and never above one, so a
-- caller can multiply it into a transparency without clamping again.
function StreakAura.pulse(elapsed: number, streak: number): number
    local period = math.max(0.05, StreakAura.pulsePeriod(streak))
    return 0.5 - 0.5 * math.cos(2 * math.pi * elapsed / period)
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
