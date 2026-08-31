# `art/` — hand-authored source that no script can reproduce

Everything under `art/` was made by a person in a tool this repo does not drive. Nothing here can
be regenerated. That is the entire admission rule, and it cuts both ways:

**A file belongs here if and only if no script in this repository can reproduce it.**

- **In:** working `.blend` files with hand modelling in them, hand-graded textures, anything that
  came out of Photoshop or a Blender edit session and exists nowhere else.
- **Out:** everything derived. FBX exports, baked atlases, `run()`'s scratch blend, `.rbxm`
  meshes, LOD cards. Those live in the untracked working directory and are rebuilt on demand.
  CI fails if they appear here.

## Why the rule is strict

A tool that regenerates its own input eventually destroys work nobody can get back, silently, on a
run that was about something else entirely. See `docs/wiki/practice/blender-working-rules.md` rule
8. `art/` is the storage half of that rule; `karasu_retarget.OWNER_AUTHORED` is the guard half, and
the two are kept in agreement by CI.

## Save discipline — this is load-bearing, not etiquette

Git keeps every version of every file forever, and it cannot diff a `.blend`: **each save is a
whole new copy, kept permanently, downloaded by everyone who clones.** For scale, the entire
repository's history was 57 MB across 1652 commits when this directory was created, and
`karasu_authored.blend` alone is 7.2 MB — one file, 13% of the repo.

So: **save here at approved milestones, not on every tweak.** Work in the scratch directory;
promote to `art/` when the owner has looked at it and said yes.

Git LFS is the standard fix for binary churn and was deliberately *not* adopted (2026-08-30): it
adds a tool every contributor and CI job must install plus a metered quota, and this repo had no
churn problem to solve. The layout does not block a retrofit. If `.git` starts outgrowing the
working tree, that is the evidence, and LFS is the answer.

## Layout

```
art/birds/karasu/
  karasu_authored.blend            the rigged bird; the bill is hand-finished
  karasu_colormap_graded_2.png     hand-graded in Photoshop over a bake
art/birds/uguisu/
  uguisu_authored.blend            the retarget itself — see below
```

⚠ **The uguisu's blend is here because the RETARGET is the irreproducible thing.** There is no
`uguisu_retarget.py`; the whole recipe existed only as a .blend on one machine, which is why the
karasu's had to be written as a script (`practice/blender-pipeline.md`). This file is also the
proof that the uguisu is the vendor sparrow: it still carries `Sparrow_orig` (1338 verts) beside
`UguisuBody` (1350), twelve apart. Every small bird planned is built on that base, so losing it
would cost four birds, not one.

⚠ **Its ColorMap is PACKED, not stored beside it, and that is deliberate.** `uguisu_colormap.png`
is DERIVED — `bake_bird_texture.py` generates it from a palette — so it must not be committed as a
file here. But an authored blend has to open standalone, so the texture is packed inside it. The
rule is about what is stored as a FILE, not about what a blend may carry.

One directory per subject. Keep the filenames the pipeline already knows — `OWNER_AUTHORED`
matches on basename, so a rename here silently unguards the file.
