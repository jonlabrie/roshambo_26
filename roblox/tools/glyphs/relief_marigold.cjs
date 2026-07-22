// relief_marigold.cjs — Marigold normal + shading → Roblox SurfaceAppearance maps.
//   <name>_normal.png  (Marigold surface-normal) → <out>_normal.png   (passthrough; optional green flip)
//   <name>_shading.png (Marigold IID shading)    → <out>_albedo.png   (weathered cypress × shading-AO)
// AO = shading luminance clamped to [p1,p99] percentiles, then floored so darkest = FLOOR (not black).
// Dependency-free (Node built-ins + local png.cjs). Deterministic.
//
// Usage: node relief_marigold.cjs <normal.png> <shading.png> <outPrefix> [--flipG]
const fs = require("fs");
const path = require("path");
const { decode, encode } = require("./png.cjs");

const CYPRESS = [150, 132, 104]; // weathered cypress albedo
const FLOOR = 0.28; // AO floor: darkest shading → 0.28 * cypress (never pure black)
const P_LO = 0.01, P_HI = 0.99; // percentile clamp for the shading→AO normalization

function lum(d, i) { return 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2]; }

function percentile(vals, p) {
  const idx = Math.min(vals.length - 1, Math.max(0, Math.floor(p * (vals.length - 1))));
  return vals[idx];
}

function main() {
  const [normalPath, shadingPath, outPrefix, ...flags] = process.argv.slice(2);
  if (!normalPath || !shadingPath || !outPrefix) {
    console.error("usage: node relief_marigold.cjs <normal.png> <shading.png> <outPrefix> [--flipG]");
    process.exit(1);
  }
  const flipG = flags.includes("--flipG");

  const nrm = decode(fs.readFileSync(normalPath));
  const shd = decode(fs.readFileSync(shadingPath));
  if (nrm.width !== shd.width || nrm.height !== shd.height) {
    throw new Error(`size mismatch: normal ${nrm.width}x${nrm.height} vs shading ${shd.width}x${shd.height}`);
  }
  const W = nrm.width, H = nrm.height, N = W * H;

  // --- normal passthrough (optional green flip) ---
  const nout = Buffer.from(nrm.data); // copy
  if (flipG) for (let i = 0; i < N; i++) nout[i * 4 + 1] = 255 - nout[i * 4 + 1];
  fs.writeFileSync(outPrefix + "_normal.png", encode(W, H, nout));

  // --- albedo = cypress × shading-AO ---
  const L = new Float32Array(N);
  for (let i = 0; i < N; i++) L[i] = lum(shd.data, i * 4);
  const sorted = Float32Array.from(L).sort();
  const lo = percentile(sorted, P_LO), hi = percentile(sorted, P_HI);
  const span = Math.max(1e-6, hi - lo);
  const alb = Buffer.alloc(N * 4);
  for (let i = 0; i < N; i++) {
    let ao = (L[i] - lo) / span;
    ao = ao < 0 ? 0 : ao > 1 ? 1 : ao;
    const shade = FLOOR + (1 - FLOOR) * ao;
    alb[i * 4] = Math.round(CYPRESS[0] * shade);
    alb[i * 4 + 1] = Math.round(CYPRESS[1] * shade);
    alb[i * 4 + 2] = Math.round(CYPRESS[2] * shade);
    alb[i * 4 + 3] = 255;
  }
  fs.writeFileSync(outPrefix + "_albedo.png", encode(W, H, alb));
  console.log(`${path.basename(outPrefix)}: ${W}x${H} AO[lo=${lo.toFixed(0)} hi=${hi.toFixed(0)}] flipG=${flipG} → _normal.png _albedo.png`);
}
main();
