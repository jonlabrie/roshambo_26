# World-Throw glyph images

`glyphgen.cjs` (dependency-free Node SDF rasteriser) renders the R/P/S glyphs from the PWA
SVGs (`src/components/Symbols.tsx`) as 6 white 512×512 PNGs — a `core` + a uniformly-wider
`outline` layer per symbol. They are uploaded to Roblox and tinted at runtime (ink outline +
gold core) by `roblox/src/shared/Glyphs.luau` (asset IDs live there). To regenerate + re-upload:

    node roblox/tools/glyphs/glyphgen.cjs        # writes ./glyphs/*.png
    # serve over http (Roblox upload needs http URLs), then MCP upload_image, then
    # paste the new rbxassetid://… into Glyphs.luau (IMAGE map).
