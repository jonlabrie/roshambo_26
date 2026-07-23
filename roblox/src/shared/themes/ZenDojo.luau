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
        -- weathered temple palette (2026-07-20 Water Striker art pass). These are Color
        -- TINTS multiplied over the ambientCG PBR MaterialVariants (see
        -- tools/studio/setupCenterpieceMaterials.luau): near-neutral where the map already
        -- carries the color, a green tint for the (colorless steel) bell. Gate-tunable.
        cypressWeathered = { 0.85, 0.84, 0.81 }, -- light neutral over gray Wood059 (aged hinoki)
        bronzePatina = { 0.157, 0.196, 0.176 }, -- dark metal + subtle green patina (bell; locked at gate)
        slateTile = { 0.90, 0.90, 0.88 }, -- near-neutral over dark kawara RoofingTiles013A
        ironDark = { 0.50, 0.50, 0.53 }, -- mid over dark Metal046B (bands/collars/gears)
        paddleWet = { 0.7, 0.78, 0.58 }, -- moss-green tint over olive Wood065 (wet mossy paddles)
    },
    lighting = {
        clockTime = 16.5,
        brightness = 2.4,
        ambient = { 90, 88, 84 },
        outdoorAmbient = { 130, 120, 105 },
    },
}
