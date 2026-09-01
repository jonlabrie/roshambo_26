"""Survey the owner's fireworks recordings: expand, measure, propose categories.

THE FILENAMES ARE NOT TRUSTED (owner, 2026-09-02). Every file is classified from
measurement: duration, peak/RMS dBFS, spectral centroid, low-band (<250Hz) energy
ratio, and onset density. Categories proposed:
  report   -- short (<1.5s), low-heavy (low_ratio > 0.5), single onset
  whistle  -- tonal (centroid 800-4000Hz, low_ratio < 0.2), sustained
  burst    -- boom onset + broadband tail, 1-6s (also the fallback for anything
              broadband that doesn't land in another bucket)
  crackle  -- dense onsets (>8/s), broadband, low_ratio < 0.35
  ambience -- long (>15s) without dominant onsets
  reject   -- clipped (peak >= -0.1 dBFS for >1% of samples), or <0.2s, or unreadable
Non-wav inputs (mp3/ogg/flac/aiff) are decoded via ffmpeg when present, else rowed
as 'unreadable' rather than skipped silently -- same for a wav whose header this
reader can't parse, or a zip member ffmpeg still can't touch.

⚠ ANALYSIS IS CAPPED AT THE FIRST 30 SECONDS of a file's audio (ANALYSIS_CAP_S).
`village-fireworks-midnight.wav` and a few of the BBC library files run past ten
minutes; an FFT and an envelope pass over the full signal would make a triage
tool crawl for no benefit -- a firework's spectral character doesn't change five
minutes in. `seconds` in the manifest is still the TRUE full-file duration (cheap:
read once, don't refft it); every other column is measured on the capped chunk.

Usage (from roblox/):
  python3 tools/audio/survey_fireworks.py "~/Desktop/Roshambo Reference/sound/fireworks"
  python3 tools/audio/survey_fireworks.py --selftest
Writes: <parent>/fireworks_expanded/ (zip contents, idempotent -- skip a zip whose
        target dir already exists) and <parent>/fireworks_manifest.csv (file,
        seconds, peak_db, rms_db, centroid_hz, low_ratio, onsets_per_s, category, note)
The reference dir itself is never written to -- everything lands in the SIBLING
`fireworks_expanded/` and manifest, one level up, never inside `fireworks/`.
"""

import csv
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from measure_caws import read_wav          # noqa: E402  -- one WAV reader, not two (adapted: see below)

# ⚠ read_wav IS measure_caws.py's RIFF reader, reused rather than duplicated (same convention as
# measure_envelope.py). It handles PCM16/24/32 and float32 WAV, downmixes multi-channel to mono.

ANALYSIS_CAP_S = 30.0           # see docstring: cap the expensive passes, not the reported duration
ONSET_WINDOW = 0.005            # envelope window, seconds -- matches measure_caws.py
ON_FRAC, OFF_FRAC = 0.12, 0.06  # onset hysteresis, as a fraction of the chunk's own peak
MIN_ONSET_S = 0.02              # an event shorter than this is noise, not an onset
CLIP_DB = -0.1                  # a sample at/above this is "clipped" for the reject rule
LOW_BAND_HZ = 250.0

WAV_EXT = {".wav"}
FFMPEG_EXT = {".mp3", ".ogg", ".flac", ".aiff", ".aif"}
SKIP_ZIP_MEMBER_PREFIXES = ("__MACOSX/",)


# ---------------------------------------------------------------------------
# Pure classifier -- exercised directly by --selftest, no I/O involved.
# ---------------------------------------------------------------------------

def classify(duration, peak_db, centroid, low_ratio, onsets_per_s, clipped_frac):
    """Propose a category for one measured clip. Pure: same inputs, same output, always."""
    if clipped_frac > 0.01:
        return "reject", f"clipped {clipped_frac:.1%} of samples at >= {CLIP_DB} dBFS"
    if duration < 0.2:
        return "reject", f"too short ({duration:.3f}s < 0.2s)"
    if duration < 1.5 and low_ratio > 0.5 and onsets_per_s <= 2.0:
        return "report", f"short, low-heavy ({low_ratio:.2f}), single onset ({duration:.2f}s)"
    if 800.0 <= centroid <= 4000.0 and low_ratio < 0.2 and onsets_per_s <= 2.0:
        return "whistle", f"tonal (centroid={centroid:.0f}Hz), sustained, low_ratio={low_ratio:.2f}"
    if onsets_per_s > 8.0 and low_ratio < 0.35:
        return "crackle", f"dense onsets ({onsets_per_s:.1f}/s), broadband (low_ratio={low_ratio:.2f})"
    if duration > 15.0 and onsets_per_s < 1.0:
        return "ambience", f"long ({duration:.1f}s), no dominant onsets ({onsets_per_s:.2f}/s)"
    if 1.0 <= duration <= 6.0:
        return "burst", f"boom + broadband tail ({duration:.2f}s)"
    return "burst", (f"broadband fallback, outside the 1-6s window "
                      f"({duration:.2f}s, low_ratio={low_ratio:.2f}, onsets={onsets_per_s:.2f}/s)")


SELFTEST_CASES = [
    # (name, args, expected_category)
    ("report",   dict(duration=0.8, peak_db=-6.0, centroid=150.0,
                       low_ratio=0.6, onsets_per_s=1.25, clipped_frac=0.0), "report"),
    ("whistle",  dict(duration=3.0, peak_db=-10.0, centroid=2000.0,
                       low_ratio=0.1, onsets_per_s=0.3, clipped_frac=0.0), "whistle"),
    ("ambience", dict(duration=25.0, peak_db=-20.0, centroid=100.0,
                       low_ratio=0.4, onsets_per_s=0.2, clipped_frac=0.0), "ambience"),
    ("reject",   dict(duration=2.0, peak_db=-0.05, centroid=1000.0,
                       low_ratio=0.3, onsets_per_s=2.0, clipped_frac=0.02), "reject"),
    ("crackle",  dict(duration=4.0, peak_db=-8.0, centroid=3000.0,
                       low_ratio=0.2, onsets_per_s=12.0, clipped_frac=0.0), "crackle"),
]


def selftest():
    bad = 0
    for name, args, want in SELFTEST_CASES:
        got, note = classify(**args)
        ok = got == want
        print(f"{'ok  ' if ok else 'FAIL'} {name}: classify(**{args}) -> {got!r} ({note}) "
              f"[expected {want!r}]")
        if not ok:
            bad += 1
    print(f"selftest: {len(SELFTEST_CASES) - bad}/{len(SELFTEST_CASES)} pass")
    return 1 if bad else 0


# ---------------------------------------------------------------------------
# Measurement -- turns a mono float array into the six classify() inputs.
# ---------------------------------------------------------------------------

def _onset_count(chunk, sr):
    n = max(1, int(ONSET_WINDOW * sr))
    m = len(chunk) // n
    if m < 1:
        return 0
    env = np.sqrt((chunk[:m * n].reshape(m, n) ** 2).mean(axis=1))
    peak = float(env.max())
    if peak <= 0.0:
        return 0
    on_th, off_th = peak * ON_FRAC, peak * OFF_FRAC
    events, live, s0 = [], False, 0
    for i, v in enumerate(env):
        if not live and v > on_th:
            live, s0 = True, i
        elif live and v < off_th:
            live = False
            events.append((s0, i))
    if live:
        events.append((s0, m - 1))
    kept = [e for e in events if (e[1] - e[0]) * ONSET_WINDOW >= MIN_ONSET_S]
    return len(kept)


def _spectral_features(chunk, sr):
    n = len(chunk)
    if n < 2:
        return 0.0, 0.0
    windowed = chunk * np.hanning(n)
    power = np.abs(np.fft.rfft(windowed)) ** 2
    freqs = np.fft.rfftfreq(n, d=1.0 / sr)
    total = float(power.sum())
    if total <= 0.0:
        return 0.0, 0.0
    centroid = float((freqs * power).sum() / total)
    low = float(power[freqs < LOW_BAND_HZ].sum() / total)
    return centroid, low


def measure(path):
    """Read a WAV and return the classify() inputs plus duration, from `path`."""
    a, sr = read_wav(path)
    duration = len(a) / sr if sr else 0.0
    cap_n = int(ANALYSIS_CAP_S * sr) if sr else len(a)
    chunk = a[:cap_n] if cap_n > 0 else a

    if len(chunk) == 0:
        return dict(seconds=round(duration, 3), peak_db=-120.0, rms_db=-120.0,
                     centroid_hz=0.0, low_ratio=0.0, onsets_per_s=0.0, clipped_frac=0.0)

    peak = float(np.max(np.abs(chunk)))
    rms = float(np.sqrt(np.mean(chunk ** 2)))
    peak_db = 20.0 * np.log10(peak + 1e-12)
    rms_db = 20.0 * np.log10(rms + 1e-12)
    clip_amp = 10 ** (CLIP_DB / 20.0)
    clipped_frac = float(np.mean(np.abs(chunk) >= clip_amp))
    centroid, low_ratio = _spectral_features(chunk, sr)
    onsets = _onset_count(chunk, sr)
    chunk_s = len(chunk) / sr if sr else 0.0
    onsets_per_s = onsets / chunk_s if chunk_s > 0 else 0.0

    return dict(seconds=round(duration, 3), peak_db=round(peak_db, 2), rms_db=round(rms_db, 2),
                centroid_hz=round(centroid, 1), low_ratio=round(low_ratio, 4),
                onsets_per_s=round(onsets_per_s, 3), clipped_frac=round(clipped_frac, 4))


def ffmpeg_decode(src_path):
    """Decode a non-wav file to a temp mono-preserving WAV via ffmpeg. Returns the temp path or
    raises if ffmpeg is unavailable/fails -- callers turn that into an 'unreadable' row."""
    if shutil.which("ffmpeg") is None:
        raise RuntimeError("ffmpeg not on PATH")
    fd, tmp_path = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-v", "error", "-i", src_path, tmp_path],
            check=True, capture_output=True,
        )
    except subprocess.CalledProcessError as e:
        os.unlink(tmp_path)
        raise RuntimeError(f"ffmpeg failed: {e.stderr.decode('utf-8', 'replace')[:200]}") from e
    return tmp_path


def survey_one(label, real_path, ext):
    """Measure and classify one file, returning a manifest row dict. Never raises -- a read
    failure or missing ffmpeg becomes an 'unreadable' row, per the brief (never silently skipped)."""
    tmp_path = None
    try:
        if ext in WAV_EXT:
            wav_path = real_path
        elif ext in FFMPEG_EXT:
            tmp_path = ffmpeg_decode(real_path)
            wav_path = tmp_path
        else:
            return dict(file=label, seconds="", peak_db="", rms_db="", centroid_hz="",
                        low_ratio="", onsets_per_s="", category="unreadable",
                        note=f"unrecognized extension {ext!r}")
        m = measure(wav_path)
        category, note = classify(m["seconds"], m["peak_db"], m["centroid_hz"],
                                   m["low_ratio"], m["onsets_per_s"], m["clipped_frac"])
        return dict(file=label, seconds=m["seconds"], peak_db=m["peak_db"], rms_db=m["rms_db"],
                    centroid_hz=m["centroid_hz"], low_ratio=m["low_ratio"],
                    onsets_per_s=m["onsets_per_s"], category=category, note=note)
    except (Exception, SystemExit) as e:   # noqa: BLE001 -- read_wav raises SystemExit on bad WAVs
        return dict(file=label, seconds="", peak_db="", rms_db="", centroid_hz="",
                    low_ratio="", onsets_per_s="", category="unreadable", note=str(e)[:200])
    finally:
        if tmp_path is not None and os.path.exists(tmp_path):
            os.unlink(tmp_path)


# ---------------------------------------------------------------------------
# Zip expansion (idempotent) and top-level walk.
# ---------------------------------------------------------------------------

def expand_zip(zip_path, target_dir):
    """Extract `zip_path` into `target_dir`, skipping macOS resource-fork junk. Idempotent: if
    `target_dir` already exists, this is a no-op (the caller still walks it for the manifest)."""
    if os.path.isdir(target_dir):
        return False
    tmp_target = target_dir + ".partial"
    if os.path.isdir(tmp_target):
        shutil.rmtree(tmp_target)
    os.makedirs(tmp_target, exist_ok=True)
    with zipfile.ZipFile(zip_path) as zf:
        for name in zf.namelist():
            if name.endswith("/"):
                continue
            base = os.path.basename(name)
            if name.startswith(SKIP_ZIP_MEMBER_PREFIXES) or base.startswith("._") or base == ".DS_Store":
                continue
            zf.extract(name, tmp_target)
    os.rename(tmp_target, target_dir)
    return True


def walk_zip_members(target_dir, zip_stem):
    rows = []
    for root, _dirs, files in os.walk(target_dir):
        for fname in sorted(files):
            if fname.startswith("._") or fname == ".DS_Store":
                continue
            full = os.path.join(root, fname)
            rel = os.path.relpath(full, target_dir)
            label = f"{zip_stem}/{rel}"
            ext = os.path.splitext(fname)[1].lower()
            rows.append((label, full, ext))
    return rows


def survey(reference_dir, expanded_dir, manifest_path):
    os.makedirs(expanded_dir, exist_ok=True)
    entries = sorted(os.listdir(reference_dir))

    jobs = []   # (label, real_path, ext)
    zips_expanded = 0
    for name in entries:
        if name.startswith("."):
            continue
        full = os.path.join(reference_dir, name)
        if os.path.isdir(full):
            continue
        ext = os.path.splitext(name)[1].lower()
        if ext == ".zip":
            stem = os.path.splitext(name)[0]
            target_dir = os.path.join(expanded_dir, stem)
            did_extract = expand_zip(full, target_dir)
            if did_extract:
                zips_expanded += 1
            jobs.extend(walk_zip_members(target_dir, stem))
        else:
            jobs.append((name, full, ext))

    rows = [survey_one(label, path, ext) for label, path, ext in jobs]

    with open(manifest_path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["file", "seconds", "peak_db", "rms_db", "centroid_hz",
                                           "low_ratio", "onsets_per_s", "category", "note"])
        w.writeheader()
        w.writerows(rows)

    return rows, zips_expanded


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--selftest":
        sys.exit(selftest())

    ref_arg = sys.argv[1] if len(sys.argv) > 1 else "~/Desktop/Roshambo Reference/sound/fireworks"
    reference_dir = os.path.expanduser(ref_arg).rstrip("/")
    parent = os.path.dirname(reference_dir)
    expanded_dir = os.path.join(parent, "fireworks_expanded")
    manifest_path = os.path.join(parent, "fireworks_manifest.csv")

    all_rows, n_zips = survey(reference_dir, expanded_dir, manifest_path)

    from collections import Counter
    counts = Counter(r["category"] for r in all_rows)
    print(f"zips expanded this run: {n_zips}")
    print(f"manifest rows: {len(all_rows)}  -> {manifest_path}")
    for cat, n in sorted(counts.items(), key=lambda kv: -kv[1]):
        print(f"  {cat:10s} {n}")
    unreadable = [r["file"] for r in all_rows if r["category"] == "unreadable"]
    if unreadable:
        print("unreadable files:")
        for name in unreadable:
            print(f"  {name}")
