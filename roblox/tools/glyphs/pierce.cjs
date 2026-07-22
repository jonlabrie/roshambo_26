// pierce.cjs — bake sukashibori cut-through alpha into a relief albedo.
// The Marigold SHADING map's deepest-black regions are the true pierced voids (verified: the
// green foliage shows through Nanda's bottom hole). Flood-fill the near-black pixels into
// connected components; components ≥ AREA_FRAC of the image become transparent (alpha 0); smaller
// dark specks (eye pupils, deep cracks) stay opaque. Output = RGBA albedo, AlphaMode.Transparency.
// Dependency-free. Deterministic.
//
// Usage: node pierce.cjs <albedo.png(RGBA)> <shading.png> <out.png> [threshold=22] [areaFrac=0.0015]
const fs = require("fs");
const { decode, encode } = require("./png.cjs");

function lum(d, i) { return 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2]; }

function main() {
  const [albedoPath, shadingPath, outPath, tArg, aArg] = process.argv.slice(2);
  if (!albedoPath || !shadingPath || !outPath) {
    console.error("usage: node pierce.cjs <albedo.png> <shading.png> <out.png> [threshold] [areaFrac]");
    process.exit(1);
  }
  const T = tArg ? Number(tArg) : 45; // gate-locked 2026-07-22 (16.7% pierced on Nanda)
  const AREA_FRAC = aArg ? Number(aArg) : 0.0015;

  const alb = decode(fs.readFileSync(albedoPath));
  const shd = decode(fs.readFileSync(shadingPath));
  const W = alb.width, H = alb.height, N = W * H;
  if (shd.width !== W || shd.height !== H) throw new Error("albedo/shading size mismatch");

  // near-black void mask from shading
  const isVoid = new Uint8Array(N);
  for (let i = 0; i < N; i++) if (lum(shd.data, i * 4) < T) isVoid[i] = 1;

  // connected components (4-connectivity, iterative flood fill)
  const label = new Int32Array(N).fill(-1);
  const minArea = Math.round(AREA_FRAC * N);
  const stack = [];
  let comp = 0;
  const kept = new Uint8Array(N); // 1 = pierce (transparent)
  let piercedPx = 0, keptComps = 0;
  for (let s = 0; s < N; s++) {
    if (!isVoid[s] || label[s] !== -1) continue;
    // BFS/DFS this component
    stack.length = 0; stack.push(s); label[s] = comp;
    const members = [s];
    while (stack.length) {
      const p = stack.pop();
      const x = p % W, y = (p / W) | 0;
      const nb = [];
      if (x > 0) nb.push(p - 1);
      if (x < W - 1) nb.push(p + 1);
      if (y > 0) nb.push(p - W);
      if (y < H - 1) nb.push(p + W);
      for (const q of nb) if (isVoid[q] && label[q] === -1) { label[q] = comp; stack.push(q); members.push(q); }
    }
    if (members.length >= minArea) {
      keptComps++;
      for (const p of members) { kept[p] = 1; piercedPx++; }
    }
    comp++;
  }

  // write RGBA albedo with pierced alpha
  const out = Buffer.from(alb.data);
  for (let i = 0; i < N; i++) out[i * 4 + 3] = kept[i] ? 0 : 255;
  fs.writeFileSync(outPath, encode(W, H, out));
  console.log(`pierce: T=${T} areaFrac=${AREA_FRAC} → ${comp} comps, ${keptComps} kept, pierced ${(100 * piercedPx / N).toFixed(1)}% of image`);
}
main();
