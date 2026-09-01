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
local S_REPORT = "rbxassetid://87713703495045" -- launch-deck-2 (owner pick, 2026-09-03)

FireworkCatalog.RECIPES = {
    -- Hand-launched: low, fast, cheap. Deliberately the least spectacular — it is the one everybody
    -- has, and the mortar shells must feel like an upgrade.
    firecracker = {
        phases = {
            { at = 0.0, kind = "report", anchor = "origin", sound = S_REPORT },
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
            { at = 0.0, kind = "report", anchor = "origin", sound = S_REPORT },
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
            { at = 0.0, kind = "report", anchor = "origin", sound = S_REPORT },
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
            { at = 0.0, kind = "report", anchor = "origin", sound = S_REPORT },
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
} :: { [string]: any }

return FireworkCatalog
