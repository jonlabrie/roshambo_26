// Dependency-free glyph rasterizer: renders R/P/S core+outline layers as white RGBA PNGs.
// Each glyph is a stroked path (round caps/joins come free from the distance field).
const fs = require("fs");
const zlib = require("zlib");
const path = require("path");
const OUT = path.join(__dirname, "glyphs");
fs.mkdirSync(OUT, { recursive: true });

const N = 512; // output size
const SS = 3; // supersample for anti-aliasing
const box = N;
const OW = 0.028 * box; // outline weight
const CORE = 0.09 * box; // core line thickness
const outPS = CORE + 2 * OW; // paper/scissors outline
const outR = CORE + 2 * OW * 0.7; // rock outline (70%)
const R = 0.23 * box; // ring radius (RING_FRAME 0.46 / 2)
const C = box / 2;

// distance helpers
function distSeg(px, py, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay;
  const l2 = dx * dx + dy * dy;
  let t = l2 ? ((px - ax) * dx + (py - ay) * dy) / l2 : 0;
  t = Math.max(0, Math.min(1, t));
  const cx = ax + t * dx, cy = ay + t * dy;
  return Math.hypot(px - cx, py - cy);
}
// signed field: <=0 inside the stroke
function fieldRing(px, py, w) {
  return Math.abs(Math.hypot(px - C, py - C) - R) - w / 2;
}
function fieldPoly(pts, px, py, w) {
  let d = Infinity;
  for (let i = 0; i + 1 < pts.length; i++)
    d = Math.min(d, distSeg(px, py, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1]));
  return d - w / 2;
}

const PAPER = [[76.8, 256], [435.2, 256]];
const SCISS = [[102.4, 345.6], [256, 192], [409.6, 345.6]];

function render(fieldFn) {
  const buf = Buffer.alloc(N * N * 4);
  for (let y = 0; y < N; y++) {
    for (let x = 0; x < N; x++) {
      let cov = 0;
      for (let sy = 0; sy < SS; sy++)
        for (let sx = 0; sx < SS; sx++) {
          const fx = x + (sx + 0.5) / SS, fy = y + (sy + 0.5) / SS;
          if (fieldFn(fx, fy) <= 0) cov++;
        }
      const a = Math.round((cov / (SS * SS)) * 255);
      const i = (y * N + x) * 4;
      buf[i] = 255; buf[i + 1] = 255; buf[i + 2] = 255; buf[i + 3] = a; // white, coverage alpha
    }
  }
  return buf;
}

// minimal RGBA PNG encoder
function crc32(buf) {
  let c = ~0;
  for (let i = 0; i < buf.length; i++) {
    c ^= buf[i];
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1));
  }
  return ~c >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
  const t = Buffer.from(type, "ascii");
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([t, data])), 0);
  return Buffer.concat([len, t, data, crc]);
}
function png(rgba) {
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(N, 0); ihdr.writeUInt32BE(N, 4);
  ihdr[8] = 8; ihdr[9] = 6; // 8-bit RGBA
  const raw = Buffer.alloc(N * (N * 4 + 1));
  for (let y = 0; y < N; y++) {
    raw[y * (N * 4 + 1)] = 0; // filter none
    rgba.copy(raw, y * (N * 4 + 1) + 1, y * N * 4, (y + 1) * N * 4);
  }
  const idat = zlib.deflateSync(raw, { level: 9 });
  return Buffer.concat([sig, chunk("IHDR", ihdr), chunk("IDAT", idat), chunk("IEND", Buffer.alloc(0))]);
}

const jobs = {
  "R_core": (x, y) => fieldRing(x, y, CORE),
  "R_outline": (x, y) => fieldRing(x, y, outR),
  "P_core": (x, y) => fieldPoly(PAPER, x, y, CORE),
  "P_outline": (x, y) => fieldPoly(PAPER, x, y, outPS),
  "S_core": (x, y) => fieldPoly(SCISS, x, y, CORE),
  "S_outline": (x, y) => fieldPoly(SCISS, x, y, outPS),
};
for (const [name, fn] of Object.entries(jobs)) {
  fs.writeFileSync(path.join(OUT, name + ".png"), png(render(fn)));
  console.log("wrote", name + ".png");
}
