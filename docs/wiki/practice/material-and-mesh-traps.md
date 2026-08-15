---
shelf: practice
updated: 2026-08-15
---

# Material and Mesh Traps

Ways this project's Roblox assets fail **silently** — no error, just something that
looks wrong. Mostly from the 2026-07/08 art passes. See also [[texturing-pack-meshes]],
[[blender-pipeline]], and the terrain-PBR recipe on [[build-recipes]].

## 1. A mistyped MaterialVariant name renders as bare base material

`part.MaterialVariant = "SomeName"` that doesn't exist in `MaterialService` fails
**silently** — the part just shows the untextured base material. A 2026-07-28 audit
found FOUR in-use names that didn't resolve (`RopeHemp`, `ZenMossRock1`, `ZenGravel1`
on 356 path parts, `ZenCanyonRock2`). The tell: the owner said "virtually ALL the rocks
look shockingly bad, only the three garden stones are different" — and `ZenGardenStone`
was the only rock variant that resolved. **Audit script:** compare every in-use
`MaterialVariant` name against `MaterialService`'s descendants; anything not found is
broken. (Live place check 2026-08-15: all four names now resolve — the defect table is
history; the audit is the keeper.)

## 2. Slate and Basalt are globally overridden

`MaterialService` maps **Slate → CanyonMossySlate** place-wide (the terrain art pass).
Set `Material = Slate` on anything and it turns dark wet moss, regardless of the
part's own variant. Cost two "why is it black" rounds. `Granite` is a safe base for
stone props.

## 3. Built-in materials tile at TERRAIN scale

Roblox's procedural materials are scaled for terrain and buildings. On a 3-stud prop,
`Granite` reads as sandy tan with speckles the size of the object. Nothing in the
built-in set works at ornament scale.

**Use a `MaterialVariant` with `StudsPerTile`, NOT a `SurfaceAppearance`.**
SurfaceAppearance is bound to the mesh's UVs, so an AI-generated unwrap stretches one
1K texture over the whole object (coarse, smeary). The variant tiles in world space and
`StudsPerTile` is a numeric grain control. `ZenCanyonRock` = Rock028 @ 8;
`GraniteHero` = Granite005B @ 2. This also means no Blender UV re-do is needed — the
reason to unwrap would have been texel density, and StudsPerTile gives it directly.

## 4. AI `generate_mesh` output is an OPEN SHELL

The generated yukimi had **1,694 boundary edges** before any cutting. Consequences:

- It must be **capped** before it can be imported single-sided, or you see through it.
- Splitting it into parts adds more open boundaries at each cut.
- Fill only the loops **on the cut planes** — a blanket `holes_fill` also seals the
  window openings and creates non-manifold geometry (it did, on the firebox).

Capping all four parts cost 53 triangles. Verify with boundary/non-manifold counts.

## 5. Importer leftovers: rotation AND PivotOffset

Roblox's FBX importer added **`Orientation (-90, 0, 0)`** on top of an already-Y-up
mesh (lantern on its back), and — separately, one level deeper — a **`PivotOffset`
whose LookVector is (0,1,0)** on every MeshPart. The second is invisible until you try
to rotate: `GetPivot()` returns `PrimaryPart.CFrame * PrimaryPart.PivotOffset`, so a
yaw composes against a tilted frame and appears to do nothing. Clear both.

**And: `TranslateBy` / direct CFrame assignment move parts but LEAVE `WorldPivot`
BEHIND.** `PivotTo` moves both. This bit twice in one session — nine rig trees ended up
with handles 540–690 studs away, and the dock hero trees had pivots 71–134 studs
underground. Anything placed by translation needs `WorldPivot` set explicitly
afterwards.

## 6. DUPLICATE MaterialVariant names + the canonical rock look

MaterialService held **TWO variants named `ZenCanyonRock`** — one base Basalt (the
old, discarded look) and one base Rock (the live river-rock look, ColorMap
`rbxassetid://132831870698274`, StudsPerTile 8). A variant only applies when
`part.Material == variant.BaseMaterial`, so the Basalt one never resolved on the 112
Rock-material river rocks — the name was stale even where the look wasn't, and the
stale string got argued from. The Basalt duplicate was renamed `ZenCanyonRock_RETIRED`
(0 users; still present in the live place, verified 2026-08-15). **Canonical rock
recipe: Material=Rock, MaterialVariant="ZenCanyonRock" (the base-Rock one),
Color=WHITE** (non-white part Color multiplies the maps darker — bit the shore rocks).
Moss Kit trail stones instead carry their own SurfaceAppearance — never overwrite it.
Broader materials cleanup belongs to F&F item 8 ([[friends-family-baseline]]).

## 7. With SurfaceAppearance AlphaMode=Transparency, part.Color is INERT

Recoloring a MeshPart whose SA uses AlphaMode=Transparency does **nothing visible** —
the moss clumps got "darkened" twice with zero effect before the owner caught it. The
working tint knob is **`SurfaceAppearance.Color`** (multiplies the ColorMap). Used
for: moss clumps RGB(150,152,128), bamboo RGB(195,200,180). Also nearby:
**`Model:ScaleTo()` is ABSOLUTE** — RealisticBamboo's template base scale is 4.93, so
`ScaleTo(0.88)` produced a 4-stud dwarf; relative scaling must multiply `GetScale()`.

## 8. A ColorMap-ONLY SurfaceAppearance is WORSE than no SurfaceAppearance

On **opaque** geometry (bark, wood, stone), a `SurfaceAppearance` carrying a `ColorMap`
and **no** NormalMap / RoughnessMap / MetalnessMap makes Roblox substitute its own
defaults for the missing channels instead of deferring to the part's `Material`. It
renders **warm and shiny** ("chestnut brown") — on every tree we exported ourselves,
while bought assets looked right.

**The split was perfectly diagnostic:** 21 templates with a full PBR set = assets
bought whole, all correct. 49 templates ColorMap-only = everything
`roblox/tools/blender/export_tree.py` produced, all wrong. 1,657 wood parts were
converted to `TextureID`; the 589 with real PBR maps were left alone.

**The rule for tree imports:**

- **foliage** → SurfaceAppearance, ColorMap, `AlphaMode = Transparency`,
  `DoubleSided = true`
- **wood** → **`TextureID`, NOT a SurfaceAppearance**, `DoubleSided = false`, keep
  `part.Color`
- wood that genuinely has Normal/Roughness/Metalness → keep the SurfaceAppearance

Neither `AlphaMode` nor `part.Color` nor swapping the image fixes it — only removing
the SurfaceAppearance does. Proven on a 6-variant rig; a first attempt compared trees
scattered across the canyon and the owner rightly called it "a terrible test". **Put
the variants on one platform, same light, side by side.**

**The trigger is ColorMap-and-nothing-else, not "a channel is missing."** A second rig
on XfSpruceM compared TextureID against ColorMap+Normal, ColorMap+Normal+Rough+Metal,
and ColorMap+Rough+Metal — the owner could not tell any of the four apart. Adding ANY
second map is enough; only ColorMap alone misbehaves. (And bark normal-map relief made
no visible difference at any real viewing distance — decision: keep TextureID, don't
upload the other 17 height maps. Question closed, not deferred.)

## 9. Roblox filters foliage RGB STRAIGHT, not premultiplied

Measure a foliage atlas's mip colour **both ways before believing either** — the
unweighted texel mean and the alpha-weighted mean bracket the two renderers a texture
could meet, and for these atlases they disagree wildly (sugi mip4: [15,16,5] unweighted
vs [111,115,38] weighted). Shipping decided it: dilating leaf colour into the
transparent texels (`roblox/tools/textures/dilate_alpha.py`) visibly changed the trees,
which a premultiplied chain could not do. **So Roblox filters RGB independently of
alpha** — black hiding under transparent texels darkens leaf EDGES at full resolution
too, not just distant mips. The effect scales with each atlas's share of partial-alpha
texels (sugi 28.7% … maple 2.2%), which ranked exactly with the owner's report. All
nine canyon atlases were **reverted** to their pre-dilation uploads — cheap, because
superseded Roblox image assets stay live, so an A/B rig can sit both versions side by
side with zero uploads. If revisited: `--fill-val` 0.5–0.6, not 0.9.

## 10. A SurfaceAppearance whose maps fail to FETCH renders as flat part.Color

The hero sugis' leaf cards turned into white opaque quads — that is a
SurfaceAppearance being dropped whole: the fallback is the MeshPart's own `Material` +
`Color` (these carry `Color = (163,162,165)`, exactly that grey).

**RESTART STUDIO BEFORE DIAGNOSING THIS.** The cause was a transient asset-fetch
failure; saving and rebooting brought them straight back. Three checks all said the
data was fine (`GetProductInfo`, `PreloadAsync`, the same images rendering in an
ImageLabel) — only the SurfaceAppearance path was failing. A neighbour asset loading
fine is NOT evidence the failure isn't transient.

**AN ASSET'S NAME IS NOT ITS CONTENT.** Four distinct sugi asset IDs are all *named*
`leaves_F` because the hero sugis deliberately share one texture set and Roblox names
every upload from that material after it. The `.fbm` folders ship real normal/rough
maps; the SurfaceAppearances are correctly authored. Check the source folder or render
the asset before calling a map wrong.

## Bonus: a PointLight inside a mesh tints the whole mesh

A warm `PointLight` in the lantern's firebox (range 16) made neutral grey granite read
as sandstone — day AND night. **Switch the light off to test the material.** The fix
is an emissive Neon core part inside the shell plus a short-range light (range ~5) for
spill: the glow becomes a surface seen through the windows, and the stone stays grey.
