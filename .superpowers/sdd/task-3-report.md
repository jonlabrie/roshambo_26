# Task 3 report: raked-sand texture tool

**Status:** DONE

**Commit:** `7acac3c` on branch `m4b-zendojo-art-pass` (not pushed)

**Output summary** (`node tools/glyphs/rakedtex.cjs`, run from `roblox/`, exit 0):
```
rakedsand_albedo_ns.png: 512x512 bitDepth=8 colorType=6 signature OK
rakedsand_albedo_ew.png: 512x512 bitDepth=8 colorType=6 signature OK
rakedsand_normal_ns.png: 512x512 bitDepth=8 colorType=6 signature OK
rakedsand_normal_ew.png: 512x512 bitDepth=8 colorType=6 signature OK
tileability OK: height(edge)===height(edge+N) across both axes for NS and EW
```
All four PNGs opened and eyeballed: pale parallel grooves with speckle in the albedo maps
(NS vertical, EW horizontal — correctly rotated 90°), green-dominant tangent-space normal
maps with matching groove-direction banding, no visible seam when mentally tiled.

**Concerns:**
1. **PITCH deviates from the brief's "64px" comment.** The brief's skeleton says `const PITCH = N / 10; // 64px...` but `512/10 = 51.2`, not 64 — the comment and the formula contradict each other (64px pitch would need N=640, or would only give 8 grooves across 512px). I kept the literal formula `PITCH = N/10` (giving exactly 10 grooves per tile, non-integer 51.2px pitch, which still tiles perfectly since `512/51.2 = 10` exactly) because "10 cosine grooves per tile" is stated as the primary requirement in two places, and only the inline comment says 64px. Flagging in case 64px pitch (8 grooves) was actually intended.
2. **EW derivation choice.** Interpreted "EW = the same content rotated 90° (x/y swapped)" as applying to the *entire* pixel content (grooves + speckle grain), not just the height formula — so EW's speckle is the transpose of NS's LCG-generated grain array (same values, swapped x/y), and EW's height/normal are computed directly via `heightEW(x,y) = heightNS(y,x)` (no buffer-transpose hacks for the normal map, since naively swapping R/B channels of a transposed normal buffer would be geometrically wrong — computed the true gradient of `heightEW` directly instead).
3. **Tileability assertion checks `height(edge) vs height(edge+N)`**, not the brief's literal "row 0 vs row N−1" — the latter isn't actually a valid tileability condition for a period that evenly divides N (adjacent-edge pixels needn't be equal; the real requirement is that the pattern doesn't jump in phase when the tile repeats, i.e. `h(0) === h(N)`). Implemented the mathematically correct version; it passes with exact (0) difference for both NS and EW.
4. LCG uses the exact `(1103515245 * state + 12345) % 2147483648` formula matching existing Luau precedent in this repo (`FoliageScatter.luau`, `BellDrive.luau`, etc.) even though the multiplication exceeds JS's 53-bit safe-integer precision for large seeds — this is deterministic (same output every run) but not a "true" bit-exact LCG. No cross-platform fixture depends on this sequence, so it's fine for a speckle-only, Node-side texture generator.
5. PNG color type is RGBA (colorType 6, matching glyphgen.cjs's encoder) with alpha hardcoded to 255 (opaque) on every pixel, per the brief's "match its encoder's channel layout; opaque alpha."

**Files:**
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tools/glyphs/rakedtex.cjs`
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tools/glyphs/raked/rakedsand_albedo_ns.png`
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tools/glyphs/raked/rakedsand_albedo_ew.png`
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tools/glyphs/raked/rakedsand_normal_ns.png`
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tools/glyphs/raked/rakedsand_normal_ew.png`

## Fix-up: normal map channel convention (post-review)

**Issue:** the original normal map encoded the out-of-surface component into G ("Y-up",
world-space-flavored reading), leaving the maps green-dominant. Roblox `MaterialVariant`
NormalMaps expect the standard tangent-space convention: R = X slope, G = Y slope (image V
axis), B = out-of-surface Z — flat areas should read ~(128,128,255) lilac-blue, blue-dominant
overall.

**Change:** rewrote `normalAt()` in `rakedtex.cjs` to compute
`n = normalize(-dhdx*S, -dhdy*S, 1)` with `dhdx`/`dhdy` as standard central differences
(wrapped sampling preserved for tileable seams), and left the existing
`R=nx, G=ny, B=nz` channel write in `renderNormal()` unchanged — since nz(=1, dominant after
normalize) now correctly carries the out-of-surface component, that alone makes the encoding
blue-dominant. Updated the header comment above `normalAt()` to describe the corrected
convention.

**Verification:**
- Re-ran `node tools/glyphs/rakedtex.cjs` from `roblox/` → exit 0, same one-line-per-file
  summary and tileability assertion as before.
- `md5`/`md5sum` on both albedo PNGs before and after the fix are byte-identical
  (`rakedsand_albedo_ns.png` = `2f75c9f9b8b2462564a17bc8a57bbe8b`,
  `rakedsand_albedo_ew.png` = `94f15318ec334f6be38341f9314be776`) — confirms the albedo
  path was untouched by the normal-map fix, as expected.
- Read both regenerated normal PNGs as images: both now read lilac-blue and blue-dominant,
  with groove-direction banding still correctly oriented (NS vertical, EW horizontal).

**Fix commit:** `d8b1641` — "fix(roblox): rakedtex normal maps in standard tangent-space
encoding (blue-dominant)" (not pushed).
