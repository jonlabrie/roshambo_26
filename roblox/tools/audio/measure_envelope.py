"""Measure a clip's loudness envelope, so `BirdSpecies.Clip.env` is derived and not drawn.

⚠ WHY A SECOND SHAPE AT ALL. `measure_caws.py` describes a PUNCTUATED caller: a karasu's clip is
two or three discrete events 0.18-0.24s long separated by 0.775s of silence, and a list of onsets
says everything about it. A mejiro warbles -- its 5.3s clip is voiced 46% of its own length in a
continuous stream broken only by breaths -- and there is no honest place to put an "onset". Asked
for onsets you would be picking arbitrary points in a run of sound.

⚠ NORMALISE BY A HIGH PERCENTILE, NOT BY THE PEAK. The peak of a warble is one transient; dividing
by it leaves the whole song in the bottom third of the range and the beak barely open through a
phrase the bird is plainly singing. Measured on mejiro-4: peak-normalised mean 0.25 with 12% of
frames above half, against p85-normalised mean 0.53 with 52% above half. The second is a bird
singing; the first is a bird mumbling.

⚠ SMOOTH BEFORE SAMPLING. A beak is a mechanism with mass and cannot track syllables; an
unsmoothed envelope makes it buzz. 150 ms is wide enough to be a jaw and narrow enough to keep the
shape of a phrase.

⚠ 12 Hz IS THE STORAGE RATE AND IT IS NOT ARBITRARY. It is above the rate a jaw can move and below
the rate at which the table stops being readable: all four mejiro clips cost 106 numbers together.

Usage:  python3 measure_envelope.py <dir-of-wavs> [glob]
        python3 measure_envelope.py --check <BirdSpecies.luau> <dir-of-wavs>
"""

import sys
import glob as globmod
import os
import re

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from measure_caws import read_wav          # noqa: E402  -- one WAV reader, not two

ENV_HZ = 12
SMOOTH_MS = 150
PERCENTILE = 85


def envelope(path, hz=ENV_HZ, smooth_ms=SMOOTH_MS, pct=PERCENTILE):
    a, sr = read_wav(path)
    dur = len(a) / sr
    hop = max(1, int(sr / hz))
    # ⚠ COVER THE WHOLE CLIP, INCLUDING THE TRAILING PARTIAL FRAME. `(len - hop) // hop` drops it,
    # and the envelope then ends BEFORE the audio does -- measured on mejiro-4, 62 samples spanned
    # 5.167s of a 5.30s clip and the beak shut 0.13s early. The contract test
    # (#env ~= seconds * ENV_HZ) is what caught it; a looser tolerance would have hidden it.
    n = max(1, -(-len(a) // hop))          # ceil
    rms = np.array([np.sqrt(np.mean(a[i * hop:min((i + 1) * hop, len(a))] ** 2) + 1e-12)
                    for i in range(n)])
    k = max(1, int(smooth_ms / 1000 * hz))
    if k > 1:
        pad = np.pad(rms, (k // 2, k // 2), mode="edge")
        rms = np.convolve(pad, np.ones(k) / k, mode="valid")[:n]
    ref = np.percentile(rms, pct)
    env = np.clip(rms / (ref + 1e-12), 0.0, 1.0)
    return {"seconds": round(dur, 3), "hz": hz,
            "env": [round(float(v), 3) for v in env],
            "mean": round(float(env.mean()), 3),
            "shut_pct": round(100.0 * float((env < 0.1).mean())),
            "open_pct": round(100.0 * float((env > 0.5).mean()))}


def check(species_luau, wav_dir, tol=0.04):
    """⚠ THE DEFECT THIS CATCHES IS AN EDITED `seconds`. The envelope is indexed by time, so a
    clip whose duration is changed without re-extracting slides the beak out of sync with its own
    audio -- silently, and worse the further into the clip you get."""
    src = open(species_luau).read()
    shipped = {}
    for m in re.finditer(r"\{\s*id\s*=\s*(\d+).*?\}", src, re.S):
        block = m.group(0)
        em = re.search(r"env\s*=\s*\{([^}]*)\}", block)
        sm = re.search(r"seconds\s*=\s*([0-9.]+)", block)
        if em and sm:
            vals = [float(x) for x in re.findall(r"[0-9.]+", em.group(1))]
            shipped[m.group(1)] = (vals, float(sm.group(1)))
    if not shipped:
        print("no clips with `env` found in", species_luau)
        return 0
    measured = [envelope(f) for f in sorted(globmod.glob(os.path.join(wav_dir, "*.wav")))]
    bad = 0
    for cid, (vals, secs) in shipped.items():
        want = round(secs * ENV_HZ)
        if abs(len(vals) - want) > 1:
            print(f"FAIL: clip {cid} ships {len(vals)} samples for {secs}s at {ENV_HZ}Hz "
                  f"(expected ~{want}) -- `seconds` and `env` disagree")
            bad += 1
            continue
        hit = [m for m in measured if abs(m["seconds"] - secs) < 0.05 and len(m["env"]) == len(vals)]
        if not hit:
            print(f"FAIL: clip {cid} has no WAV of {secs}s with {len(vals)} samples")
            bad += 1
            continue
        drift = max(abs(a - b) for a, b in zip(vals, hit[0]["env"]))
        if drift > tol:
            print(f"FAIL: clip {cid} envelope drifted {drift:.3f} from the WAV")
            bad += 1
    print("envelopes:", "DRIFTED" if bad else f"all {len(shipped)} agree with the WAVs")
    return 1 if bad else 0


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--check":
        sys.exit(check(sys.argv[2], sys.argv[3]))
    d = sys.argv[1] if len(sys.argv) > 1 else "."
    pat = sys.argv[2] if len(sys.argv) > 2 else "*.wav"
    for f in sorted(globmod.glob(os.path.join(d, pat))):
        r = envelope(f)
        print(f"\n-- {os.path.basename(f)}  {r['seconds']}s  {len(r['env'])} samples at {r['hz']}Hz"
              f"  (mean {r['mean']}, open {r['open_pct']}%, shut {r['shut_pct']}%)")
        print(f"seconds = {r['seconds']},")
        body = ", ".join(f"{v:.2f}" for v in r["env"])
        print("env = { " + body + " },")
