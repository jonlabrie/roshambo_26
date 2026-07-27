# triage_tree.py — judge a tree asset BEFORE committing it to the export pipeline.
#
# The lesson from the sugi (2026-07-27): a canopy's CARD STRUCTURE, not its
# triangle count, decides whether budget reduction keeps it looking like a tree.
# The vendor sugi hangs its foliage on ~22,000 tiny needle sprays, so a 15k-tri
# budget keeps only ~8% of them and the tree goes bald. A canopy built from a few
# hundred LARGE leaf cards survives the same cut intact.
#
# So for each model this reports, per material:
#   tris, islands (connected components = individual cards/sprays),
#   median tris per island, and the SURVIVAL ESTIMATE: what fraction of cards a
#   given foliage budget can keep (cards are dropped whole by the exporter).
#
# Pure Python + Wavefront OBJ parsing — no Blender, no numpy. Fast enough to sweep
# a whole library.
#
# Usage:
#   python3 triage_tree.py <file.obj|dir> [more...] [--budget 15000] [--all-stages]
# By default only ADULT stages (…a.obj) are read when given a directory, since
# that is the model a species is judged on.

import os
import sys
import statistics


def parse_obj(path):
    """-> {material: [face_vertex_index_tuples]} (1-based indices resolved to 0-based)."""
    groups, current, nverts = {}, "default", 0
    with open(path, "r", errors="ignore") as fh:
        for line in fh:
            if line.startswith("v "):
                nverts += 1
            elif line.startswith("usemtl "):
                current = line.split(None, 1)[1].strip()
                groups.setdefault(current, [])
            elif line.startswith("f "):
                idx = []
                for tok in line.split()[1:]:
                    v = tok.split("/")[0]
                    if v:
                        i = int(v)
                        idx.append(i - 1 if i > 0 else nverts + i)
                if len(idx) >= 3:
                    groups.setdefault(current, []).append(tuple(idx))
    return groups, nverts


class DSU:
    def __init__(self):
        self.p = {}

    def find(self, x):
        p = self.p
        r = p.setdefault(x, x)
        while r != p[r]:
            p[r] = p[p[r]]
            r = p[r]
        return r

    def union(self, a, b):
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.p[ra] = rb


def islands(faces):
    """Connected components over shared vertices -> list of tri counts per island."""
    dsu = DSU()
    for f in faces:
        first = f[0]
        for v in f[1:]:
            dsu.union(first, v)
    tally = {}
    for f in faces:
        root = dsu.find(f[0])
        tally[root] = tally.get(root, 0) + (len(f) - 2)
    return sorted(tally.values(), reverse=True)


FOLIAGE_HINTS = ("leaf", "leaves", "needle", "frond", "blossom", "flower", "petal")


def triage(path, budget):
    groups, nverts = parse_obj(path)
    total = sum(len(f) - 2 for fs in groups.values() for f in fs)
    rows = []
    for mat, faces in sorted(groups.items()):
        tris = sum(len(f) - 2 for f in faces)
        is_foliage = any(h in mat.lower() for h in FOLIAGE_HINTS)
        row = {"material": mat, "tris": tris, "foliage": is_foliage}
        if is_foliage and faces:
            sizes = islands(faces)
            row["islands"] = len(sizes)
            row["median_tris_per_card"] = statistics.median(sizes)
            # exporter drops whole cards to fit: how many survive the budget?
            keep, used = 0, 0
            for s in sizes:
                if used + s > budget:
                    break
                used += s
                keep += 1
            row["cards_kept_at_budget"] = keep
            row["pct_cards_kept"] = round(100.0 * keep / len(sizes), 1)
        rows.append(row)
    return {"file": os.path.basename(path), "verts": nverts, "tris": total, "materials": rows}


def main():
    args = [a for a in sys.argv[1:]]
    budget = 15000
    all_stages = "--all-stages" in args
    if "--budget" in args:
        i = args.index("--budget")
        budget = int(args[i + 1])
        del args[i : i + 2]
    args = [a for a in args if not a.startswith("--")]

    targets = []
    for a in args:
        if os.path.isdir(a):
            for root, _dirs, files in os.walk(a):
                for f in sorted(files):
                    if f.lower().endswith(".obj") and (all_stages or f.lower().endswith("a.obj")):
                        targets.append(os.path.join(root, f))
        else:
            targets.append(a)

    print(f"budget={budget} tris of foliage; {len(targets)} model(s)\n")
    header = f"{'model':<34}{'tris':>9}{'foliage':>9}{'cards':>8}{'med/card':>10}{'kept@budget':>13}"
    print(header)
    print("-" * len(header))
    for t in sorted(targets):
        try:
            r = triage(t, budget)
        except Exception as exc:  # keep sweeping if one file is odd
            print(f"{os.path.basename(t):<34}  ERROR {exc}")
            continue
        fol = [m for m in r["materials"] if m.get("foliage")]
        name = os.path.relpath(t, args[0]) if os.path.isdir(args[0]) else r["file"]
        name = name.replace("/", "|")[-33:]
        if fol:
            f0 = max(fol, key=lambda m: m["tris"])
            print(
                f"{name:<34}{r['tris']:>9,}{f0['tris']:>9,}{f0['islands']:>8,}"
                f"{f0['median_tris_per_card']:>10.0f}{f0['pct_cards_kept']:>12.1f}%"
            )
        else:
            print(f"{name:<34}{r['tris']:>9,}{'-':>9}{'-':>8}{'-':>10}{'-':>13}")


if __name__ == "__main__":
    main()
