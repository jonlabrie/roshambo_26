// Dependency-free raked-sand texture gen: tileable albedo + normal maps at 10 grooves/tile.
// Deterministic: integer LCG only (genmodels/glyphgen portability discipline; no Math.random).
const fs = require("fs");
const zlib = require("zlib");
const path = require("path");
const OUT = path.join(__dirname, "raked");
fs.mkdirSync(OUT, { recursive: true });

const N = 512; // output size; StudsPerTile = 8 at the Studio step
const PITCH = N / 10; // 10 cosine grooves per tile; period must divide N exactly to tile
let seed = 20260724;
function lcg() {
  seed = (1103515245 * seed + 12345) % 2147483648;
  return seed / 2147483648;
}

// height(x,y): cosine groove profile, PERIODIC in x by construction (period = PITCH, and N
// is an exact multiple of PITCH -> seams tile losslessly). NS = grooves parallel to the
// image Y axis (profile varies with x only, constant along y); EW = the same profile
// rotated 90 degrees (x/y swapped -> profile varies with y only).
function heightNS(x, y) {
  const phase = (2 * Math.PI * x) / PITCH;
  return 0.5 + 0.5 * Math.cos(phase); // crest at groove lines, trough between
}
function heightEW(x, y) {
  return heightNS(y, x);
}

function wrap(i) {
  return ((i % N) + N) % N;
}

// normal map: central differences of height with WRAPPED sampling (tileable seams),
// Y-up tangent convention: R<-nx, G<-ny (up), B<-nz; encode (n*0.5+0.5)*255 into RGB.
const S = 2.0; // groove strength
function normalAt(hFn, x, y) {
  const hxm = hFn(wrap(x - 1), y);
  const hxp = hFn(wrap(x + 1), y);
  const hym = hFn(x, wrap(y - 1));
  const hyp = hFn(x, wrap(y + 1));
  let nx = (hxm - hxp) * S;
  let nz = (hym - hyp) * S;
  let ny = 1;
  const len = Math.hypot(nx, ny, nz) || 1;
  nx /= len; ny /= len; nz /= len;
  return [nx, ny, nz];
}

// speckle grain: one LCG pass in raster scan order, reused (transposed) for EW so the whole
// image -- grooves and grain alike -- is literally "the same content rotated 90".
const speckle = new Float64Array(N * N);
for (let y = 0; y < N; y++) {
  for (let x = 0; x < N; x++) {
    speckle[y * N + x] = 0.9 + 0.2 * lcg();
  }
}
const speckleNS = (x, y) => speckle[y * N + x];
const speckleEW = (x, y) => speckle[x * N + y];

const BASE = [222, 217, 202]; // pale zen-sand base
function clampByte(v) {
  return Math.max(0, Math.min(255, Math.round(v)));
}

function renderAlbedo(hFn, speckleAt) {
  const buf = Buffer.alloc(N * N * 4);
  for (let y = 0; y < N; y++) {
    for (let x = 0; x < N; x++) {
      const h = hFn(x, y); // 0..1, crest = 1
      const mod = 1 + 0.08 * (2 * h - 1); // crests +8%, troughs -8%
      const grain = speckleAt(x, y);
      const i = (y * N + x) * 4;
      buf[i] = clampByte(BASE[0] * mod * grain);
      buf[i + 1] = clampByte(BASE[1] * mod * grain);
      buf[i + 2] = clampByte(BASE[2] * mod * grain);
      buf[i + 3] = 255; // opaque
    }
  }
  return buf;
}

function renderNormal(hFn) {
  const buf = Buffer.alloc(N * N * 4);
  for (let y = 0; y < N; y++) {
    for (let x = 0; x < N; x++) {
      const [nx, ny, nz] = normalAt(hFn, x, y);
      const i = (y * N + x) * 4;
      buf[i] = clampByte((nx * 0.5 + 0.5) * 255);
      buf[i + 1] = clampByte((ny * 0.5 + 0.5) * 255);
      buf[i + 2] = clampByte((nz * 0.5 + 0.5) * 255);
      buf[i + 3] = 255; // opaque
    }
  }
  return buf;
}

// minimal RGBA PNG encoder (copied verbatim from glyphgen.cjs)
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

// read a PNG back off disk and sanity-check its signature + declared IHDR dimensions
function verifyPng(filePath) {
  const buf = fs.readFileSync(filePath);
  const expectedSig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  if (!buf.subarray(0, 8).equals(expectedSig)) throw new Error(`${filePath}: bad PNG signature`);
  if (buf.subarray(12, 16).toString("ascii") !== "IHDR") throw new Error(`${filePath}: missing IHDR`);
  return {
    width: buf.readUInt32BE(16),
    height: buf.readUInt32BE(20),
    bitDepth: buf[24],
    colorType: buf[25],
  };
}

const jobs = [
  ["rakedsand_albedo_ns", () => renderAlbedo(heightNS, speckleNS)],
  ["rakedsand_albedo_ew", () => renderAlbedo(heightEW, speckleEW)],
  ["rakedsand_normal_ns", () => renderNormal(heightNS)],
  ["rakedsand_normal_ew", () => renderNormal(heightEW)],
];

for (const [name, render] of jobs) {
  const filePath = path.join(OUT, name + ".png");
  fs.writeFileSync(filePath, png(render()));
  const info = verifyPng(filePath);
  console.log(
    `${name}.png: ${info.width}x${info.height} bitDepth=${info.bitDepth} colorType=${info.colorType} signature OK`
  );
}

// tileability assertion: the height function must be exactly periodic across the tile edge
// in both axes (wrapped row/col continuity) or the texture will show a seam when repeated.
function assertTileable(name, hFn) {
  for (let k = 0; k < N; k++) {
    if (Math.abs(hFn(0, k) - hFn(N, k)) > 1e-9) {
      throw new Error(`${name}: not tileable across x-seam at row ${k}`);
    }
    if (Math.abs(hFn(k, 0) - hFn(k, N)) > 1e-9) {
      throw new Error(`${name}: not tileable across y-seam at col ${k}`);
    }
  }
}
assertTileable("heightNS", heightNS);
assertTileable("heightEW", heightEW);
console.log("tileability OK: height(edge)===height(edge+N) across both axes for NS and EW");
