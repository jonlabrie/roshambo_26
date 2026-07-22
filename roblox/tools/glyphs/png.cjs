// Dependency-free PNG I/O (Node built-ins only): decode 8/16-bit RGB/RGBA/gray/palette
// (16-bit → high byte), encode 8-bit RGBA; non-interlaced, filter types 0-4. Sufficient for
// Marigold normal/shading maps and ambientCG PBR scans (some ship 16-bit normals).
const zlib = require("zlib");

function crc32(buf) {
  let c = ~0;
  for (let i = 0; i < buf.length; i++) {
    c ^= buf[i];
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1));
  }
  return ~c >>> 0;
}

function decode(buf) {
  if (buf.readUInt32BE(0) !== 0x89504e47) throw new Error("not a PNG");
  let off = 8;
  let width, height, bitDepth, colorType, interlace;
  const idat = [];
  let palette = null;
  while (off < buf.length) {
    const len = buf.readUInt32BE(off);
    const type = buf.toString("ascii", off + 4, off + 8);
    const data = buf.subarray(off + 8, off + 8 + len);
    if (type === "IHDR") {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bitDepth = data[8];
      colorType = data[9];
      interlace = data[12];
    } else if (type === "PLTE") {
      palette = data;
    } else if (type === "IDAT") {
      idat.push(data);
    } else if (type === "IEND") {
      break;
    }
    off += 12 + len;
  }
  if (bitDepth !== 8 && bitDepth !== 16) throw new Error("only 8/16-bit supported, got " + bitDepth);
  if (interlace !== 0) throw new Error("interlaced PNG not supported");
  const channels = colorType === 6 ? 4 : colorType === 2 ? 3 : colorType === 0 ? 1 : colorType === 3 ? 1 : null;
  if (channels === null) throw new Error("unsupported colorType " + colorType);
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const sb = bitDepth === 16 ? 2 : 1; // sample bytes
  const bpp = channels * sb; // bytes per pixel (used by the unfilter step)
  const stride = width * bpp;
  const out = Buffer.alloc(height * stride);
  let pos = 0;
  for (let y = 0; y < height; y++) {
    const filter = raw[pos++];
    const row = out.subarray(y * stride, (y + 1) * stride);
    const prev = y > 0 ? out.subarray((y - 1) * stride, y * stride) : null;
    for (let x = 0; x < stride; x++) {
      const rawB = raw[pos++];
      const a = x >= bpp ? row[x - bpp] : 0;
      const b = prev ? prev[x] : 0;
      const c = prev && x >= bpp ? prev[x - bpp] : 0;
      let v;
      switch (filter) {
        case 0: v = rawB; break;
        case 1: v = rawB + a; break;
        case 2: v = rawB + b; break;
        case 3: v = rawB + ((a + b) >> 1); break;
        case 4: {
          const p = a + b - c;
          const pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
          const pr = pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
          v = rawB + pr;
          break;
        }
        default: throw new Error("bad filter " + filter);
      }
      row[x] = v & 0xff;
    }
  }
  // Expand to 8-bit RGBA (for 16-bit, keep the high byte of each sample)
  const rgba = Buffer.alloc(width * height * 4);
  for (let i = 0; i < width * height; i++) {
    const base = i * bpp; // high byte of channel c is at base + c*sb
    let r, g, b, al;
    if (colorType === 6) { r = out[base]; g = out[base + sb]; b = out[base + 2 * sb]; al = out[base + 3 * sb]; }
    else if (colorType === 2) { r = out[base]; g = out[base + sb]; b = out[base + 2 * sb]; al = 255; }
    else if (colorType === 0) { r = g = b = out[base]; al = 255; }
    else { const p = out[base]; r = palette[p * 3]; g = palette[p * 3 + 1]; b = palette[p * 3 + 2]; al = 255; }
    rgba[i * 4] = r; rgba[i * 4 + 1] = g; rgba[i * 4 + 2] = b; rgba[i * 4 + 3] = al;
  }
  return { width, height, data: rgba };
}

function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
  const t = Buffer.from(type, "ascii");
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([t, data])), 0);
  return Buffer.concat([len, t, data, crc]);
}

// encode RGBA buffer (width*height*4) to a PNG (filter none)
function encode(width, height, rgba) {
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; ihdr[9] = 6; // 8-bit RGBA
  const raw = Buffer.alloc(height * (width * 4 + 1));
  for (let y = 0; y < height; y++) {
    raw[y * (width * 4 + 1)] = 0;
    rgba.copy(raw, y * (width * 4 + 1) + 1, y * width * 4, (y + 1) * width * 4);
  }
  const idat = zlib.deflateSync(raw, { level: 9 });
  return Buffer.concat([sig, chunk("IHDR", ihdr), chunk("IDAT", idat), chunk("IEND", Buffer.alloc(0))]);
}

module.exports = { decode, encode };

// self-test when run directly: node png.cjs <file.png>
if (require.main === module) {
  const fs = require("fs");
  const img = decode(fs.readFileSync(process.argv[2]));
  console.log("size", img.width + "x" + img.height, "aspect", (img.width / img.height).toFixed(3));
  const samp = (x, y) => { const i = (y * img.width + x) * 4; return [img.data[i], img.data[i + 1], img.data[i + 2], img.data[i + 3]]; };
  console.log("center px", samp(img.width >> 1, img.height >> 1));
  console.log("corner px (0,0)", samp(0, 0));
  // round-trip check
  const re = encode(img.width, img.height, img.data);
  const back = decode(re);
  const mid = ((img.height >> 1) * img.width + (img.width >> 1)) * 4;
  console.log("roundtrip center match:", img.data[mid] === back.data[mid] && img.data[mid + 1] === back.data[mid + 1]);
}
