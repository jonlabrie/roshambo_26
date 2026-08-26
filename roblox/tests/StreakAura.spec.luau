--!strict
local harness = require("./harness")
local StreakAura = require("../src/shared/StreakAura")
local describe, test, expect = harness.describe, harness.test, harness.expect

local V = StreakAura.VISIBILITY

-- A viewer who wants to see auras, looking at a stranger. Each test overrides what it cares about.
local function ctx(over: { [string]: any }?): any
    local base = {
        streak = 5,
        visibility = V.PUBLIC,
        isSelf = false,
        isFriend = false,
        viewerWantsAuras = true,
        force = nil,
    }
    for k, v in over or {} do
        base[k] = v
    end
    return base
end

describe("StreakAura", function()
    test("nothing glows below the floor -- a common streak is noise, not a flex", function()
        -- ⚠ Roughly a third of players win any given round, so a 1- or 2-streak is ordinary. The
        -- whole reason an aura works where a worn banner did not is that it is RARE: a 3-streak is
        -- about 1 in 27. Lower the floor and it becomes the thing it was meant to avoid.
        for s = -3, StreakAura.MIN_STREAK - 1 do
            expect(StreakAura.visible(s)).toBe(false)
        end
        expect(StreakAura.visible(StreakAura.MIN_STREAK)).toBe(true)
        expect(StreakAura.visible(99)).toBe(true)
    end)

    test("a deeper streak glows HARDER, and never inverts", function()
        local prevFill, prevOutline = 2, 2
        for s = StreakAura.MIN_STREAK, 12 do
            local fill, outline, heat = StreakAura.poseFor(s)
            expect(fill <= prevFill).toBe(true) -- transparency FALLS as the streak deepens
            expect(outline <= prevOutline).toBe(true)
            expect(heat >= 0 and heat <= 1).toBe(true)
            prevFill, prevOutline = fill, outline
        end
        -- and it genuinely MOVES across the range, rather than being flat and monotonic-by-default
        local f3 = StreakAura.poseFor(StreakAura.MIN_STREAK)
        local f12 = StreakAura.poseFor(12)
        expect(f3 - f12 > 0.1).toBe(true)
    end)

    test("the glow SATURATES rather than running away", function()
        -- A 12-streak and a 30-streak look the same. Without this an improbable run would white
        -- out the screen for everyone near it.
        local f12, o12, h12 = StreakAura.poseFor(12)
        local f30, o30, h30 = StreakAura.poseFor(30)
        expect(f12).toBe(f30)
        expect(o12).toBe(o30)
        expect(h12).toBe(h30)
        expect(h12).toBe(1)
    end)

    test("every value stays inside the range Roblox will accept", function()
        for s = -5, 40 do
            local fill, outline, heat = StreakAura.poseFor(s)
            expect(fill >= 0 and fill <= 1).toBe(true)
            expect(outline >= 0 and outline <= 1).toBe(true)
            expect(heat >= 0 and heat <= 1).toBe(true)
        end
    end)

    test("below the floor the pose is FULLY transparent, not merely faint", function()
        -- The controller also gates on visible(), but a pose that leaked a faint glow would make
        -- the two disagree, and the failure would look like a rendering bug rather than a rule.
        local fill, outline = StreakAura.poseFor(0)
        expect(fill).toBe(1)
        expect(outline).toBe(1)
    end)

    -- ===== visibility =====

    test("PUBLIC shows to anyone; HIDDEN shows to no one but yourself", function()
        expect(StreakAura.shows(ctx({ visibility = V.PUBLIC }))).toBe(true)
        expect(StreakAura.shows(ctx({ visibility = V.HIDDEN }))).toBe(false)
        -- ⚠ you always see your OWN, whatever you chose -- hiding from other players is not the
        -- same as hiding from yourself, and a setting that made your own state unreadable would
        -- read as the feature being broken.
        expect(StreakAura.shows(ctx({ visibility = V.HIDDEN, isSelf = true }))).toBe(true)
    end)

    test("FRIENDS shows to friends and to nobody else", function()
        expect(StreakAura.shows(ctx({ visibility = V.FRIENDS, isFriend = true }))).toBe(true)
        expect(StreakAura.shows(ctx({ visibility = V.FRIENDS, isFriend = false }))).toBe(false)
        expect(StreakAura.shows(ctx({ visibility = V.FRIENDS, isFriend = false, isSelf = true }))).toBe(true)
    end)

    test("an unknown or absent visibility falls back to PUBLIC, never to leaking", function()
        -- Absent means PUBLIC, matching HudPrefs' absent-means-on convention and the fact that a
        -- streak is already public in the stats room. But a value we do not RECOGNISE is different
        -- from one that is missing: it means something upstream is wrong, and the safe reading of a
        -- broken privacy field is the permissive default only because the datum itself is public.
        expect(StreakAura.shows(ctx({ visibility = nil }))).toBe(true)
        expect(StreakAura.shows(ctx({ visibility = "GARBAGE" }))).toBe(true)
    end)

    test("the VIEWER's own off-switch wins over every force value", function()
        -- ⚠ An override exists to make a moment legible, not to put something on a screen whose
        -- owner switched it off. This is the one rule force never beats.
        for _, f in { nil, "SHOW", "SHOW_EVEN_IF_HIDDEN", "HIDE" } do
            expect(StreakAura.shows(ctx({ viewerWantsAuras = false, force = f }))).toBe(false)
        end
        -- even for your own aura: your screen is yours
        expect(StreakAura.shows(ctx({ viewerWantsAuras = false, isSelf = true }))).toBe(false)
    end)

    test("force HIDE beats a PUBLIC subject, and costs them nothing", function()
        expect(StreakAura.shows(ctx({ visibility = V.PUBLIC, force = "HIDE" }))).toBe(false)
        expect(StreakAura.shows(ctx({ visibility = V.PUBLIC, force = "HIDE", isSelf = true }))).toBe(false)
    end)

    test("⚠ force SHOW lifts the FRIENDS gate but NEVER an explicit HIDDEN", function()
        -- THE ASYMMETRY IS THE WHOLE POINT. Forcing a public player hidden costs them nothing.
        -- Forcing a HIDDEN player visible overrides a privacy choice they made deliberately, so it
        -- requires a DIFFERENT value that a caller has to name. Reaching it by accident is the
        -- failure this test exists to prevent.
        expect(StreakAura.shows(ctx({ visibility = V.FRIENDS, isFriend = false, force = "SHOW" }))).toBe(true)
        expect(StreakAura.shows(ctx({ visibility = V.HIDDEN, force = "SHOW" }))).toBe(false)
        expect(StreakAura.shows(ctx({ visibility = V.HIDDEN, force = "SHOW_EVEN_IF_HIDDEN" }))).toBe(true)
    end)

    test("no force value can conjure a glow that is not there", function()
        -- Below the floor there is nothing to show. An override changes WHO sees a streak, never
        -- whether one exists.
        for _, f in { "SHOW", "SHOW_EVEN_IF_HIDDEN" } do
            expect(StreakAura.shows(ctx({ streak = 0, force = f }))).toBe(false)
            expect(StreakAura.shows(ctx({ streak = 2, force = f, isSelf = true }))).toBe(false)
        end
    end)

    test("a valid visibility is recognised, and garbage is not", function()
        expect(StreakAura.isVisibility(V.HIDDEN)).toBe(true)
        expect(StreakAura.isVisibility(V.FRIENDS)).toBe(true)
        expect(StreakAura.isVisibility(V.PUBLIC)).toBe(true)
        expect(StreakAura.isVisibility("hidden")).toBe(false) -- case matters; the wire value is exact
        expect(StreakAura.isVisibility("")).toBe(false)
        expect(StreakAura.isVisibility(nil)).toBe(false)
        expect(StreakAura.isVisibility(3)).toBe(false)
    end)
end)
