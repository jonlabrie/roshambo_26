--!strict
-- HOW EACH SHELL LOOKS AND SOUNDS. The other half of the contract with server/src/fireworks.ts:
-- that side owns ids, prices and requirements; this side owns the recipe. They meet at one string,
-- and FireworkCatalog.spec asserts this table covers every id the server can sell.
--
-- A RECIPE IS A LIST OF PHASES — report, ascent, burst, and (for shells beyond these four)
-- sub-bursts. FireworkController just walks the list, so adding a shell never touches it. That is
-- the whole reason for the format: many distinct shells matter to this game's economics, and a
-- fixed ascent-then-burst chain would make every new kind of break a code change.
--
-- Pure data, no Roblox globals (colours are {r,g,b} 0-255 arrays), so it runs under Lune.
--
-- THE TEXTURE IS NOT OPTIONAL. A ParticleEmitter with Texture == "" renders nothing at all — no
-- error, no warning. Learned on the 2026-07-20 bench; see the roshambo-fireworks memory.
local FireworkCatalog = {}

-- The launch thump (owner's pick, 2026-09-03: launch-deck-2 from the kingsrow deck set). Ascent
-- phases carry NO sound (owner ruling: a real aerial shell's rise is mostly quiet from the
-- ground), and burst phases name none either -- the style's variant pool in BurstStyles.SOUNDS
-- covers them, one seeded pick per shell.

FireworkCatalog.RECIPES = {
    -- Hand-launched: low, fast, cheap. Deliberately the least spectacular — it is the one everybody
    -- has, and the mortar shells must feel like an upgrade.
    firecracker = {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin" },
            { at = 0.02, kind = "ascent", anchor = "origin", color = { 255, 200, 120 } },
            {
                at = 1.2,
                kind = "burst",
                anchor = "apex",
                color = { 255, 236, 170 },
                edgeColor = { 255, 200, 120 },
                spread = 18,
                droop = false,
            },
        },
    },
    -- The bench's proven radial break.
    peony = {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin" },
            { at = 0.02, kind = "ascent", anchor = "origin", color = { 255, 190, 200 } },
            {
                at = 3.0,
                kind = "burst",
                anchor = "apex",
                color = { 255, 120, 140 },
                edgeColor = { 255, 190, 200 },
                spread = 42,
                droop = false,
            },
        },
    },
    -- The bench's proven drooping break.
    willow = {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin" },
            { at = 0.02, kind = "ascent", anchor = "origin", color = { 220, 240, 255 } },
            {
                at = 3.1,
                kind = "burst",
                anchor = "apex",
                color = { 255, 190, 90 }, -- molten gold: a willow is golden by definition (owner caught the pale blue, 2026-09-03)
                edgeColor = { 255, 226, 160 },
                spread = 34,
                droop = true,
            },
        },
    },
    -- 石花, stone flower — the Rock shell. Stone-pale and slow, so the shell that only flies after
    -- an R round reads differently from the ones that fly any time.
    ishibana = {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin" },
            { at = 0.02, kind = "ascent", anchor = "origin", color = { 198, 194, 186 } },
            {
                at = 3.2,
                kind = "burst",
                anchor = "apex",
                color = { 226, 222, 210 },
                edgeColor = { 198, 194, 186 },
                spread = 26,
                droop = false,
            },
        },
    },
    -- 菊 kiku, chrysanthemum — the first shell promoted THROUGH the proving range
    -- (owner gate 2026-09-04: "that's the one, ship v2 kiku"). A tight gold peony that
    -- burns hot, and a DISTRIBUTION rather than a recording: ~30% of fires upgrade —
    -- wider, brighter, two extra break points, longer hang — announced by the white
    -- kicker pop and the double-tap report.
    -- 輪 wa, the red ring (promoted 2026-09-05; owner: v2 floor, 5 pts, M tube). The boost
    -- (30%) is STRUCTURAL: a wider concentric ring blooms 0.4s behind the first -- the first
    -- boostOnly shell -- with the kicker's stars burning bright orange (owner's pick).
    wa = {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin" },
            { at = 0.02, kind = "ascent", anchor = "origin", color = { 255, 180, 100 } },
            {
                at = 3.0,
                kind = "burst",
                anchor = "apex",
                style = "ring",
                color = { 255, 60, 40 },
                edgeColor = { 255, 240, 220 },
                spread = 42,
                droop = false,
                share = 3,
                -- kicker = false (owner, 2026-09-05): the double ring IS the tell -- "it's
                -- already obvious it was a bonus shell". The kicker stays in the engine for
                -- shells whose surprise needs selling.
                boost = { chance = 0.3, glow = 1.15, lifeScale = 1.1, kicker = false },
            },
            {
                at = 3.4,
                kind = "burst",
                anchor = "apex",
                style = "ring",
                color = { 255, 90, 60 },
                edgeColor = { 255, 240, 220 },
                spread = 60,
                droop = false,
                share = 2,
                boostOnly = true,
            },
        },
    },
    -- 椰子 yashi, the palm (promoted 2026-09-06; owner: M tube, 10). Four thick outward
    -- arms with the long rain (palm lifetime carries the extra 0.4s). The boost (30%)
    -- lands a FIFTH arm via boost.points, sold by a violet streak kicker that rains --
    -- the family's only streak treatment, so the lucky shell reads at a glance.
    yashi = {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin" },
            { at = 0.02, kind = "ascent", anchor = "origin", color = { 255, 210, 140 } },
            {
                at = 3.0,
                kind = "burst",
                anchor = "apex",
                style = "palm",
                color = { 255, 180, 60 },
                edgeColor = { 255, 230, 160 },
                points = 4,
                scatter = 6,
                droop = false,
                boost = {
                    chance = 0.3,
                    points = 1,
                    glow = 1.15,
                    lifeScale = 1.1,
                    kickerColor = { 190, 90, 255 },
                    kickerStreaks = true,
                },
            },
        },
    },
    kiku = {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin" },
            { at = 0.02, kind = "ascent", anchor = "origin", color = { 255, 214, 130 } },
            {
                at = 3.0,
                kind = "burst",
                anchor = "apex",
                color = { 255, 190, 90 },
                edgeColor = { 255, 150, 60 },
                spread = 38,
                glow = 1.5,
                boost = { chance = 0.3, spread = 1.32, glow = 1.2, points = 2, lifeScale = 1.15 },
                droop = false,
            },
        },
    },
} :: { [string]: any }

return FireworkCatalog
