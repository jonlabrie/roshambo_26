### Task 3: Raked-sand texture tool

**Files:**
- Create: `roblox/tools/glyphs/rakedtex.cjs`
- Generated (committed): `roblox/tools/glyphs/raked/rakedsand_albedo_ns.png`, `rakedsand_albedo_ew.png`, `rakedsand_normal_ns.png`, `rakedsand_normal_ew.png`

**Interfaces:**
- Consumes: nothing (dependency-free Node, the glyphgen.cjs PNG-writer precedent — reuse its zlib/PNG encoding approach verbatim).
- Produces: four 512×512 tileable PNGs. Convention: the texture tile covers **8 studs** in-world (StudsPerTile = 8 at the Studio step), grooves at 0.8-stud pitch → **10 grooves per tile** (64 px pitch). NS = grooves running along image Y (world Z when applied); EW = the same rotated 90°.

- [ ] **Step 1: Write the tool**

`rakedtex.cjs`, structured like glyphgen.cjs (same PNG/zlib encoder functions — copy them):

```js
// Dependency-free raked-sand texture gen: tileable albedo + normal at 10 grooves/tile.
// Deterministic: integer LCG only (genmodels portability discipline).
const N = 512;
const PITCH = N / 10; // 64px = 0.8 studs at StudsPerTile 8
let seed = 20260724;
function lcg() { seed = (1103515245 * seed + 12345) % 2147483648; return seed / 2147483648; }

// height(x,y): cosine groove profile + LCG speckle; PERIODIC in both axes by construction
function height(x, y) {
    const phase = (2 * Math.PI * x) / PITCH;
    return 0.5 + 0.5 * Math.cos(phase); // crest at groove lines, trough between
}
// albedo: pale zen-sand base modulated by height + fine speckle
// normal: central differences of height with WRAPPED sampling (tileability), Y-up
//   nx = (h(x-1,y)-h(x+1,y))*S, nz = (h(x,y-1)-h(x,y+1))*S, ny = 1, normalize,
//   encode (n*0.5+0.5)*255 into RGB. S tuned so ridges read (~2.0).
// Emit NS (as computed) and EW (x/y swapped) for both albedo and normal.
```

Full implementation: generate the four buffers pixel-by-pixel, speckle = `0.9 + 0.2 * lcg()` multiplied into albedo channels (base RGB ≈ [222, 217, 202]), write PNGs with the copied encoder. End the script by asserting tileability: row 0 vs row N−1 and col 0 vs col N−1 of the height function differ by < 1e-9 (throw if not).

- [ ] **Step 2: Run + eyeball**

`node tools/glyphs/rakedtex.cjs` → four PNGs. Open the albedo locally (or `Read` them as images) — parallel pale grooves with subtle speckle, no visible seam when mentally tiled.

- [ ] **Step 3: Commit**

```bash
git add roblox/tools/glyphs/rakedtex.cjs roblox/tools/glyphs/raked/
git commit -m "feat(roblox): deterministic tileable raked-sand texture tool (albedo+normal, NS/EW)"
```

---

