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
    test("the floor is an ACCESS decision, and it is deliberately low", function()
        -- ⚠ THIS REPLACES A TEST THAT ARGUED THE OPPOSITE. The first version defended a floor of 3
        -- on rarity -- a 3-streak is about 1 in 27, so the arena stays dark. The owner's answer on
        -- seeing it in play: "who cares about auras if only 2 or 3 are ever even visible on your
        -- server?" Scarcity stops clutter, but a signal almost nobody can display is a lottery
        -- rather than a flex. Owner ruling 2026-08-25: the floor is 2, "let the kids dress up if
        -- they want" -- it decides who is ALLOWED TO BE SEEN, which is not a tuning number.
        expect(StreakAura.MIN_STREAK).toBe(2)
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
        -- and it genuinely MOVES across the range, rather than being flat and monotonic-by-default.
        -- ⚠ Measured on the OUTLINE now: the fill was deliberately flattened to a faint floor when
        -- the particles took over as the signal, so asserting a wide fill swing would be asserting
        -- the very thing that was just removed on purpose.
        local fNear, oNear = StreakAura.poseFor(StreakAura.MIN_STREAK)
        local fFar, oFar = StreakAura.poseFor(12)
        expect(oNear - oFar > 0.2).toBe(true)
        expect(fNear - fFar > 0.05).toBe(true)
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
            expect(StreakAura.shows(ctx({ streak = StreakAura.MIN_STREAK - 1, force = f, isSelf = true }))).toBe(
                false
            )
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

describe("StreakAura motion", function()
    test("the emit rate is COUNTABLE, which transparency was not", function()
        -- ⚠ THE FAILURE THIS FIXES: "the differences in color are not obvious (at least, not in the
        -- singular)". A transparency ramp is only readable COMPARATIVELY -- you cannot tell 0.73
        -- from 0.85 without a second player beside you -- and thanks to the floor, one player alone
        -- is the common case. Rate and count read off a single body.
        expect(StreakAura.emitRate(StreakAura.MIN_STREAK - 1)).toBe(0)
        -- ⚠ NON-decreasing, not strictly increasing: the rate SATURATES, and an earlier version of
        -- this test demanded both at once — it contradicted the saturation test two below it.
        local prev = -1
        for s = StreakAura.MIN_STREAK, 12 do
            local r = StreakAura.emitRate(s)
            expect(r >= prev).toBe(true)
            prev = r
        end
        -- it must still genuinely climb before it saturates
        expect(StreakAura.emitRate(StreakAura.MIN_STREAK + 1) > StreakAura.emitRate(StreakAura.MIN_STREAK)).toBe(
            true
        )
        -- and the steps are big enough to COUNT, not a smooth ramp nobody can read
        local lo = StreakAura.emitRate(StreakAura.MIN_STREAK)
        local hi = StreakAura.emitRate(12)
        expect(hi >= lo * 3).toBe(true)
    end)

    test("the emit rate saturates, so a phone is never asked for an unbounded stream", function()
        expect(StreakAura.emitRate(12)).toBe(StreakAura.emitRate(40))
    end)

    test("the pulse is a TEMPO, and it quickens with the streak", function()
        -- Brightness is not readable in isolation; a beat is. Count the pulses, not the lumens.
        local slow = StreakAura.pulsePeriod(StreakAura.MIN_STREAK)
        local fast = StreakAura.pulsePeriod(12)
        expect(fast < slow).toBe(true)
        expect(fast > 0).toBe(true)
        for s = StreakAura.MIN_STREAK, 20 do
            expect(StreakAura.pulsePeriod(s) > 0).toBe(true) -- never zero: a divisor downstream
        end
    end)

    test("the pulse stays inside 0..1 and actually moves", function()
        local lo, hi = 2, -1
        for t = 0, 6, 0.02 do
            local v = StreakAura.pulse(t, 5)
            expect(v >= 0 and v <= 1).toBe(true)
            lo, hi = math.min(lo, v), math.max(hi, v)
        end
        expect(hi - lo > 0.5).toBe(true) -- a pulse that barely moves is not a pulse
    end)

    test("the FILL is only a faint floor now -- the particles carry it", function()
        -- Owner, 2026-08-25: keep the fill "very faint as a floor". A Highlight is what Studio uses
        -- for selection, and at strength it reads as an editor affordance washing the avatar out.
        local nearFill = StreakAura.poseFor(StreakAura.MIN_STREAK)
        local farFill = StreakAura.poseFor(20)
        expect(nearFill > 0.9).toBe(true)
        expect(farFill > 0.8).toBe(true)
    end)
end)
