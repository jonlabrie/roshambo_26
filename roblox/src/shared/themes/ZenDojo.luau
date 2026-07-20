--!strict
-- Zen Dojo theme (Edo Japan). Asset ids land in milestone 4b's art pass;
-- "0" means "placeholder visual / no sound" to the runtime players.
return {
    name = "ZenDojo",
    labels = { boardHeader = "世界 · THE WORLD" },
    sounds = {
        clack = "0",
        gong = "0",
        drumroll = "0",
        latch = "0",
        splash = "0",
        bank = "0",
        waterAmbience = "0",
    },
    models = { boulder = "0", paperSheet = "0", shears = "0", umbrella = "0" },
    palette = {
        moss = { 0.48, 0.54, 0.39 },
        ivory = { 0.87, 0.84, 0.76 },
        vermilion = { 0.63, 0.36, 0.27 },
        ink = { 0.18, 0.19, 0.22 },
        gold = { 0.83, 0.69, 0.40 },
        water = { 0.20, 0.35, 0.43 },
        gravel = { 0.79, 0.76, 0.70 },
        timber = { 0.42, 0.31, 0.20 },
        -- weathered temple palette (2026-07-20 Water Striker art pass; starting values)
        cypressWeathered = { 0.56, 0.55, 0.51 }, -- sun-bleached aged hinoki posts/beams/brackets
        bronzePatina = { 0.18, 0.25, 0.22 }, -- dark verdigris green-black bell
        slateTile = { 0.13, 0.14, 0.16 }, -- near-black hip-roof tile
        ironDark = { 0.16, 0.16, 0.18 }, -- hoop bands, collars, chains, gears
        paddleWet = { 0.34, 0.35, 0.33 }, -- darkened wet lower paddles
    },
    lighting = {
        clockTime = 16.5,
        brightness = 2.4,
        ambient = { 90, 88, 84 },
        outdoorAmbient = { 130, 120, 105 },
    },
}
