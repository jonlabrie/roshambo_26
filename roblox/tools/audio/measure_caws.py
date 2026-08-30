"""Measure caw onsets in a bird clip, so `BirdSpecies.Clip.caws` is derived and not guessed.

⚠ THIS EXISTS BECAUSE THE FIRST SET OF ONSETS WAS MODELLED. They were inferred from the clip
durations and the recorded room-tone padding, and every one was wrong -- karasu-2's second caw was
typed as 0.62s against a measured 0.865s. A quarter of a second late is plainly visible on a beak.
The source WAVs were on disk the whole time; nobody opened them.

⚠ A CAW IS AN EVENT WITH A DURATION, not a threshold crossing. karasu-3 contains a 25 ms blip at
16% of peak between its second and third caws; a plain envelope threshold counts it as a fourth caw
and the beak snaps at nothing. Real caws here run 0.18-0.24s, so events under 0.10s are rejected.

⚠ ONSETS ARE READ AT A LOW THRESHOLD. A higher one triggers later and reports the caw as starting
after it actually did -- measured, 12% vs 20% of peak moves karasu-3's third onset from 1.635 to
1.655. The mouth should open with the sound, so take the early edge.

Usage:  python3 measure_caws.py <dir-of-wavs> [glob]
"""

import struct
import sys
import glob as globmod
import os

import numpy as np

WINDOW = 0.005          # envelope window, seconds
ON_FRAC, OFF_FRAC = 0.12, 0.06      # hysteresis, as a fraction of the clip's own peak
MIN_CAW = 0.10          # an event shorter than this is an artefact, not a call


def read_wav(path):
    d = open(path, "rb").read()
    i, fmt, data = 12, None, None
    while i < len(d) - 8:
        cid = d[i:i + 4]
        sz = struct.unpack("<I", d[i + 4:i + 8])[0]
        body = d[i + 8:i + 8 + sz]
        if cid == b"fmt ":
            fmt = struct.unpack("<HHIIHH", body[:16])
        elif cid == b"data":
            data = body
        i += 8 + sz + (sz & 1)
    tag, ch, sr, _, _, bits = fmt
    if tag == 1 and bits == 16:
        a = np.frombuffer(data, dtype="<i2").astype(np.float64) / 32768.0
    elif tag == 1 and bits == 24:
        # 24-bit packed little-endian, three bytes per sample, sign-extended by hand -- numpy has
        # no 24-bit dtype. The vendor bird recordings are in this format.
        raw = np.frombuffer(data, dtype=np.uint8)
        raw = raw[:len(raw) // 3 * 3].reshape(-1, 3).astype(np.int32)
        v = raw[:, 0] | (raw[:, 1] << 8) | (raw[:, 2] << 16)
        a = np.where(v & 0x800000, v - 0x1000000, v).astype(np.float64) / 8388608.0
    elif tag == 1 and bits == 32:
        a = np.frombuffer(data, dtype="<i4").astype(np.float64) / 2147483648.0
    elif tag == 3 and bits == 32:
        a = np.frombuffer(data, dtype="<f4").astype(np.float64)
    else:
        raise SystemExit(f"{path}: unhandled WAV format tag={tag} bits={bits}")
    if ch > 1:
        a = a[:len(a) // ch * ch].reshape(-1, ch).mean(axis=1)
    return a, sr


def caws(path):
    a, sr = read_wav(path)
    n = int(WINDOW * sr)
    m = len(a) // n
    env = np.sqrt((a[:m * n].reshape(m, n) ** 2).mean(axis=1))
    t = np.arange(m) * WINDOW
    peak = env.max()
    on_th, off_th = peak * ON_FRAC, peak * OFF_FRAC
    events, live, s0 = [], False, 0
    for i, v in enumerate(env):
        if not live and v > on_th:
            live, s0 = True, i
        elif live and v < off_th:
            live = False
            events.append((t[s0], t[i], float(env[s0:i].max())))
    if live:
        events.append((t[s0], t[-1], float(env[s0:].max())))
    kept = [e for e in events if e[1] - e[0] >= MIN_CAW]
    return {
        "seconds": round(len(a) / sr, 3),
        "caws": [round(o, 3) for o, _, _ in kept],
        "caw_lengths": [round(e - o, 3) for o, e, _ in kept],
        "rejected": [(round(o, 3), round(e - o, 3), round(p / peak, 2))
                     for o, e, p in events if (e - o) < MIN_CAW],
    }


if __name__ == "__main__":
    d = sys.argv[1] if len(sys.argv) > 1 else "."
    pat = sys.argv[2] if len(sys.argv) > 2 else "*.wav"
    for f in sorted(globmod.glob(os.path.join(d, pat))):
        r = caws(f)
        print(f"{os.path.basename(f)}: seconds={r['seconds']} caws={r['caws']} "
              f"lengths={r['caw_lengths']}")
        for o, ln, frac in r["rejected"]:
            print(f"    rejected {o}s ({ln}s, {frac:.0%} of peak) -- too short to be a caw")
