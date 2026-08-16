--!strict
-- Chochin: THE canyon chōchin (hanging paper lantern), at full fidelity. Ported from
-- tools/studio/buildHanabiyaChochin.luau — the owner-gated Studio tool that built the accepted
-- Chochin_Hanabiya at 花火屋 (LS 0.65/0.9, 2026-08-13). Any caller that needs a chōchin uses
-- THIS module so there is one recipe, not a redrawn lookalike — an earlier attempt restated the
-- design at 10 slices/8 ribs with a plain hang rod instead of a ring, and the owner caught it.
--
-- The Studio tool and this module are the ONLY two copies of this design: Studio tools are
-- pasted whole into the command bar and cannot require this module, so they cannot share code.
-- tests/Chochin.spec.luau reads the tool's source as text and drift-checks these constants
-- against its literals — a change to either copy that isn't mirrored in the other fails CI.
--
-- THE GLYPH PLATES ARE FUNCTIONAL, NOT DECORATION. They carry the CollectionService tag
-- "RoundLantern" (emitted below via Spec's Tags property — see tests/JsonEmit and the existing
-- NorenSeg tag in Machiya.luau for the same mechanism, verified against this repo's Rojo
-- 7.7.0), which is how LanternController shows the last World Throw on every lantern in the
-- canyon and how PaperLanternDayNight finds the barrel to ride with nightFactor. Never drop the
-- plate or its tag, and never make it optional.
local Spec = require("./Spec")

local Chochin = {}

-- ===== the owner's numbers (LS 0.65/0.9, 2026-08-13 gate) =====
Chochin.LS = 0.65 / 0.9
Chochin.Rmax = 0.9 * Chochin.LS
Chochin.capR = 0.30 * Chochin.LS
Chochin.bodyH = 2.8 * Chochin.LS
Chochin.ringR = 0.22 * Chochin.LS
Chochin.tubeR = 0.05 * Chochin.LS
Chochin.HOOK_DROP = 0.22
Chochin.N = 18 -- paper-barrel slices
Chochin.CENTER_IDX = Chochin.N // 2 -- 9, the lit ChochinBody slice
Chochin.RIBS = 16
Chochin.RING_SEGMENTS = 14

Chochin.INK = { 0.18, 0.157, 0.118 } -- Color3.fromRGB(46, 40, 30) / 255 — ribs, caps
Chochin.METAL = { 0.47, 0.478, 0.502 } -- Color3.fromRGB(120, 122, 128) / 255 — ring, hook
Chochin.PAPER = { 0.784, 0.667, 0.561 } -- {200, 170, 143} / 255 — gradient-scaled per slice
Chochin.PAPER_T = 0.42
Chochin.LIGHT_COLOR = { 1.0, 0.659, 0.376 } -- Color3.fromRGB(255, 168, 96) / 255

-- The barrel silhouette: capR + (Rmax - capR) * sqrt(1 - d^6), d = |2t - 1|. sqrt and
-- multiplication only — no `^`, no trig — so the emitted floats are libm-arch-stable (arm64 vs
-- x86_64) for the genmodels drift check. The ring loop below is the only trig this module needs
-- (permitted: Machiya.luau already emits sin/cos in its stair/roof/hisashi specs and the arch
-- check passes there, because JsonEmit rounds near-zero residues to 0).
local function profile(tt: number): number
    local d = math.abs(2 * tt - 1)
    local d2 = d * d
    return Chochin.capR + (Chochin.Rmax - Chochin.capR) * math.sqrt(1 - d2 * d2 * d2)
end

-- Hem clearance, exactly as the Studio tool computes it — a conservative pre-check, not the
-- literal bottom-cap edge. Callers assert this against their own floor + MIN_HEM_CLEAR (kept at
-- the call site, per the owner's ruling that a low corner hang is acceptable).
function Chochin.hemY(armY: number): number
    return armY - 2 * Chochin.ringR - 0.13 * Chochin.LS - Chochin.bodyH - 0.13 * Chochin.LS
end

-- Relative luminance of a 0-1 RGB tint (standard Rec. 709 weights). Per-shop paper tints must
-- clear Chochin.LEGIBILITY_FLOOR: the glyph plate carries the RoundLantern tag, so EVERY
-- lantern in the canyon shows the last World Throw and dims with nightFactor — a dark barrel
-- would swallow that glyph at night, which is the lantern's actual job, not a colour nicety.
-- Canonical cream (Chochin.PAPER) measures ~0.684, comfortably above the floor.
Chochin.LEGIBILITY_FLOOR = 0.55
function Chochin.luminance(rgb01: { number }): number
    return 0.2126 * rgb01[1] + 0.7152 * rgb01[2] + 0.0722 * rgb01[3]
end

-- One lantern: a metal ring draped on a hook, an 18-slice gradient paper barrel with 16 ribs
-- and ink caps, and two glyph plates tagged RoundLantern. (x, z) is the hang point in the
-- horizontal plane; armY is the y the ring hangs from (the eave underside minus HOOK_DROP).
--
-- paperRGB255 is an OPTIONAL per-shop tint for the paper barrel only — never the glyph plates,
-- never the ring/ribs/caps ink or metal. It is written in the same 0-255 units as the Studio
-- tool's own `local PAPER = { 200, 170, 143 }` literal (human-readable RGB), NOT the 0-1 floats
-- Chochin.PAPER stores internally — this function does the /255 conversion. Omit it (or pass
-- nil) and the canonical cream (Chochin.PAPER) is used, unchanged — this is the default the
-- Studio tool, the path lanterns, and 花火屋's place-only lanterns all still get. The per-slice
-- gradient scaling (the `f` factor below) is unaffected either way; the tint only replaces the
-- base colour the gradient scales.
--
-- LEGIBILITY FLOOR: any tint passed here must keep the barrel light enough that the RoundLantern
-- glyph (the World Throw) still reads against it at night — see tests/Chochin.spec.luau's
-- luminance guard, which checks every tint the repo defines against a 0.55 floor.
-- Returns a Spec model named "Chochin<name>".
function Chochin.build(name: string, x: number, z: number, armY: number, paperRGB255: { number }?): any
    local LS, Rmax, bodyH = Chochin.LS, Chochin.Rmax, Chochin.bodyH
    local ringR, tubeR = Chochin.ringR, Chochin.tubeR
    local paper = Chochin.PAPER
    if paperRGB255 then
        paper = { paperRGB255[1] / 255, paperRGB255[2] / 255, paperRGB255[3] / 255 }
    end
    local kids: { any } = {}

    -- the eye under the eave the ring hangs from
    table.insert(
        kids,
        Spec.part("Hook", {
            Size = { 2 * tubeR, Chochin.HOOK_DROP, 2 * tubeR },
            CFrame = Spec.cframe({ x, armY + Chochin.HOOK_DROP / 2, z }),
            Color = Chochin.METAL,
            Material = "Metal",
            CanCollide = false,
            CanQuery = false,
            CanTouch = false,
            CastShadow = false,
        })
    )

    -- the metal ring draped over the hook — real loop geometry, not a straight rod: a circle of
    -- RING_SEGMENTS cylinder chords in the vertical (X-Y) plane facing the promenade.
    local ringCenter = { x, armY - ringR, z }
    for i = 0, Chochin.RING_SEGMENTS - 1 do
        local a0 = 2 * math.pi * i / Chochin.RING_SEGMENTS
        local a1 = 2 * math.pi * (i + 1) / Chochin.RING_SEGMENTS
        local p0 =
            { ringCenter[1] + ringR * math.sin(a0), ringCenter[2] + ringR * math.cos(a0), ringCenter[3] }
        local p1 =
            { ringCenter[1] + ringR * math.sin(a1), ringCenter[2] + ringR * math.cos(a1), ringCenter[3] }
        local pos, len, rot = Spec.segment(p0, p1)
        table.insert(
            kids,
            Spec.part("LoopSeg_" .. i, {
                Shape = "Cylinder",
                Size = { len + 0.02, 2 * tubeR, 2 * tubeR },
                CFrame = Spec.cframe(pos, rot),
                Color = Chochin.METAL,
                Material = "Metal",
                CanCollide = false,
                CanQuery = false,
                CanTouch = false,
                CastShadow = false,
            })
        )
    end

    -- paper barrel: an N-slice stack with a vertical gradient, centre brightest
    local ringBottom = armY - 2 * ringR
    local lcY = ringBottom - 0.13 * LS - bodyH / 2 + 0.05 * LS
    for i = 0, Chochin.N - 1 do
        local tt = (i + 0.5) / Chochin.N
        local r = profile(tt)
        local y = lcY + (tt - 0.5) * bodyH
        local d = math.abs(2 * tt - 1)
        local f = math.clamp(1 - 0.22 * d - (if tt > 0.5 then 0.15 * (2 * tt - 1) else 0), 0.4, 1)
        local isBody = i == Chochin.CENTER_IDX
        table.insert(
            kids,
            Spec.part(if isBody then "ChochinBody" else `Slice_{i}`, {
                Shape = "Cylinder",
                Size = { bodyH / Chochin.N * 1.15, 2 * r, 2 * r },
                CFrame = Spec.cframe({ x, y, z }, Spec.ROT.CYL_VERTICAL),
                Color = { paper[1] * f, paper[2] * f, paper[3] * f },
                Material = "Neon",
                Transparency = Chochin.PAPER_T,
                CanCollide = false,
                CanQuery = false,
                CanTouch = false,
                CastShadow = false,
                children = if isBody
                    then {
                        {
                            name = "ChochinLight",
                            className = "PointLight",
                            properties = {
                                Color = Chochin.LIGHT_COLOR,
                                Brightness = 1.1,
                                Range = 10,
                                Shadows = false,
                            },
                        },
                    }
                    else nil,
            })
        )
    end

    -- horizontal ribs
    for j = 1, Chochin.RIBS do
        local tt = (j - 0.5) / Chochin.RIBS
        local r = profile(tt) + 0.05 * LS
        table.insert(
            kids,
            Spec.part(`Rib_{j}`, {
                Shape = "Cylinder",
                Size = { 0.035 * LS, 2 * r, 2 * r },
                CFrame = Spec.cframe({ x, lcY + (tt - 0.5) * bodyH, z }, Spec.ROT.CYL_VERTICAL),
                Color = Chochin.INK,
                Material = "Wood",
                CanCollide = false,
                CanQuery = false,
                CanTouch = false,
                CastShadow = false,
            })
        )
    end

    -- top and bottom caps
    for _, cap in { { "CapTop", bodyH / 2 }, { "CapBottom", -bodyH / 2 } } do
        table.insert(
            kids,
            Spec.part(cap[1] :: string, {
                Shape = "Cylinder",
                Size = { 0.26 * LS, 0.66 * LS, 0.66 * LS },
                CFrame = Spec.cframe({ x, lcY + (cap[2] :: number), z }, Spec.ROT.CYL_VERTICAL),
                Color = Chochin.INK,
                Material = "Wood",
                CanCollide = false,
                CanQuery = false,
                CanTouch = false,
                CastShadow = false,
            })
        )
    end

    -- Glyph plates face ALONG the street (owner's gate): the promenade reads them from both
    -- directions, and glyph size follows plate size — LanternController builds the SurfaceGui
    -- from the plate at PixelsPerStud and fills 0.7 of it.
    for _, pl in { { "GlyphPlateA", -1, 90 }, { "GlyphPlateB", 1, -90 } } do
        table.insert(
            kids,
            Spec.part(pl[1] :: string, {
                Size = { 1.2 * LS, 1.6 * LS, 0.05 },
                CFrame = Spec.cframe(
                    { x + (pl[2] :: number) * (Rmax + 0.04), lcY, z },
                    Spec.yaw(pl[3] :: number)
                ),
                Transparency = 1,
                CanCollide = false,
                CanQuery = false,
                CanTouch = false,
                CastShadow = false,
                Tags = { "RoundLantern" },
            })
        )
    end

    return Spec.model(`Chochin{name}`, kids)
end

return Chochin
