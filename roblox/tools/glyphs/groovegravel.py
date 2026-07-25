#!/usr/bin/env python3
"""Composite raked-garden groove ridges into an external (ambientCG) gravel normal map.

The karesansui field uses a real gravel PBR set for stone detail; the raking grooves
are OURS, blended into the set's NormalGL as analytic cosine slopes (UDN blend: add
tangent slopes, renormalize). Emits NS and EW variants (grooves along image V / U).

Usage: python3 groovegravel.py <path-to-NormalGL.png> <outdir>
Deps: macOS `sips` (PNG->BMP decode) + Python stdlib only (zlib PNG encode).

FINAL GATE-TUNED RECIPE (2026-07-24, user-approved in Studio):
  source set: ambientCG Gravel041 1K (CC0), in the user's Roshambo Reference dir
  profile: symmetric sinusoid, peak slope 1.5*BANK = 0.75; SAT 0.30, GAIN 1.03
  Studio MaterialVariants (place-state, MaterialService): RakedSandNS / RakedSandEW,
    BaseMaterial Sand, MaterialPattern Organic, StudsPerTile 5.2 (0.52-stud rows),
    ColorMap rbxassetid://84735195211963 (desaturated Gravel041_Color),
    RoughnessMap rbxassetid://120842997538838 (Gravel041_Roughness as-is),
    NormalMap NS rbxassetid://107566330130099 / EW rbxassetid://74548615699366
"""
import os, struct, subprocess, sys, tempfile, zlib

GROOVES_PER_TILE = 10  # matches rakedtex/the field pitch: at StudsPerTile 5 -> 0.5-stud combing
BANK = 0.5 # tangent slope of each furrow bank (gate-tuned deeper cut; was 0.35)
SAT = 0.30  # color map desaturation survivor fraction (gate: "too much color")
GAIN = 1.03  # slight pale lift after desaturation

def read_bmp_via_sips(png_path):
    with tempfile.TemporaryDirectory() as td:
        bmp = os.path.join(td, "x.bmp")
        subprocess.run(["sips", "-s", "format", "bmp", png_path, "--out", bmp],
                       check=True, capture_output=True)
        data = open(bmp, "rb").read()
    off = struct.unpack_from("<I", data, 10)[0]
    w, h = struct.unpack_from("<ii", data, 18)
    bpp = struct.unpack_from("<H", data, 28)[0]
    assert bpp in (24, 32), f"unexpected bpp {bpp}"
    step = bpp // 8
    row = (w * step + 3) & ~3
    px = bytearray(w * abs(h) * 3)
    flip = h > 0  # positive height = bottom-up rows
    H = abs(h)
    for y in range(H):
        src = off + (H - 1 - y if flip else y) * row
        for x in range(w):
            b, g, r = data[src + x * step], data[src + x * step + 1], data[src + x * step + 2]
            i = (y * w + x) * 3
            px[i], px[i + 1], px[i + 2] = r, g, b
    return w, H, px

def png_encode(w, h, rgb):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        raw += rgb[y * w * 3:(y + 1) * w * 3]
    def chunk(t, d):
        c = t + d
        return struct.pack(">I", len(d)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)  # 8-bit RGB
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))

def composite(w, h, base, along_v):
    import math
    pitch = w / GROOVES_PER_TILE  # divides exactly for power-of-two ambientCG tiles / 10? 1024/10=102.4: cos period fits tile 10x -> seamless
    out = bytearray(len(base))
    for y in range(h):
        for x in range(w):
            i = (y * w + x) * 3
            nx = base[i] / 127.5 - 1
            ny = base[i + 1] / 127.5 - 1
            nz = max(base[i + 2] / 127.5 - 1, 0.2)
            # SYMMETRIC furrows (gate history: cosine@0.12 too soft -> triangle
            # banded -> scallop read as sawtooth because SHADING ramps then snaps).
            # The eye reads shading: a symmetric rise/fall needs sinusoidal slope —
            # the original cosine profile, at ~6x the original strength.
            frac = ((x if along_v else y) / pitch) % 1.0
            slope = 1.5 * BANK * math.sin(2 * math.pi * frac)
            if along_v:
                nx += slope
            else:
                ny += slope
            l = math.sqrt(nx * nx + ny * ny + nz * nz)
            out[i] = max(0, min(255, round((nx / l * 0.5 + 0.5) * 255)))
            out[i + 1] = max(0, min(255, round((ny / l * 0.5 + 0.5) * 255)))
            out[i + 2] = max(0, min(255, round((nz / l * 0.5 + 0.5) * 255)))
    return out

def desaturate(w, h, rgb):
    out = bytearray(len(rgb))
    for i in range(0, len(rgb), 3):
        r, g, b = rgb[i], rgb[i + 1], rgb[i + 2]
        lum = 0.299 * r + 0.587 * g + 0.114 * b
        for k, v in enumerate((r, g, b)):
            out[i + k] = max(0, min(255, round((lum + SAT * (v - lum)) * GAIN)))
    return out

def main():
    src, outdir = sys.argv[1], sys.argv[2]
    os.makedirs(outdir, exist_ok=True)
    w, h, base = read_bmp_via_sips(src)
    for name, along_v in (("gravel041_normal_ns.png", True), ("gravel041_normal_ew.png", False)):
        rgb = composite(w, h, base, along_v)
        open(os.path.join(outdir, name), "wb").write(png_encode(w, h, rgb))
        print(f"{name}: {w}x{h} grooves {'along V (NS)' if along_v else 'along U (EW)'}")
    color_src = src.replace("NormalGL", "Color")
    if os.path.exists(color_src):
        cw, ch, crgb = read_bmp_via_sips(color_src)
        open(os.path.join(outdir, "gravel041_color.png"), "wb").write(
            png_encode(cw, ch, desaturate(cw, ch, crgb)))
        print(f"gravel041_color.png: {cw}x{ch} desaturated (SAT {SAT}, gain {GAIN})")

if __name__ == "__main__":
    main()
