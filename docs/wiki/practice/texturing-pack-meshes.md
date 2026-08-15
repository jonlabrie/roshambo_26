---
shelf: practice
updated: 2026-08-15
---

# Texturing Pack Meshes

How to recolor/retexture imported low-poly MeshPart packs (proven on the Stylized Rock
Pack rocks in the ZenDojo channel, 2026-06-22) without smearing or washout — use a
world-space MaterialVariant, not SurfaceAppearance.

## The three traps, in the order they hit

1. **`SurfaceAppearance` smears ("Picasso effect").** SurfaceAppearance samples maps
   by the mesh's OWN UVs. Pack meshes have UVs authored only for their baked texture,
   and on flat low-poly facets a different map cracks into discontinuous shards. AVOID
   SurfaceAppearance for recoloring pack meshes.
2. **`MaterialVariant` is the right tool — it tiles in WORLD space (triplanar),
   ignoring UVs**, so no seams. Same reason terrain/canyon walls look clean. Set
   `part.Material = <BaseMaterial of variant>` and `part.MaterialVariant = "<name>"`.
   Tune coverage with the variant's **`StudsPerTile`** (bigger = texture zoomed out =
   base stone dominates, detail/moss recedes). NB StudsPerTile is a property of the
   *variant*, shared by every part using it.
3. **A pack mesh's baked `TextureID` OVERRIDES the MaterialVariant** and is usually a
   pale, slightly glossy stone that reflects the sky → washed-out white on lit faces
   (a Color tint barely moves it because the wash is reflection, not albedo). FIX:
   clear `part.TextureID = ""` (stash the old value in an attribute first if you might
   restore) so the matte world-space material shows.

MaterialVariant name resolution works even when the variant is nested in Folders under
`MaterialService` (generate_material drops them under
`MaterialService.AssistantMaterials`); the engine registers any MaterialVariant
descendant of MaterialService by Name+BaseMaterial.

Reference result, the ZenDojo channel rocks: `Material=Rock`,
`MaterialVariant="ZenMossRock1"`, `StudsPerTile=12`, `Color=white`, `Reflectance=0` →
grey granite boulders with moss in the crevices, "leaning grey." Greener = lower
StudsPerTile or ZenMossRock2; greyer = raise StudsPerTile.

## Tint vs map: what part.Color can and cannot do (2026-08-14)

`part.Color` **MULTIPLIES** the variant's ColorMap. Two consequences, got wrong in
opposite directions on the same afternoon:

- **Lightening works.** The bell's bronze was 0.157/0.196/0.176 over Metal058C — dark
  enough to crush the map to nothing, so the patina was in the texture all along,
  tinted out of sight. 0.36/0.45/0.39 brought it back.
- **Desaturating toward NEUTRAL does nothing.** Multiplication can darken a coloured
  source but never desaturate it: Metal058C is itself green, so a grey tint just
  yields its green, dimmer (five near-identical teals proved it). The only lever is to
  push AGAINST the map — green DOWN relative to red and blue. Landed at
  0.390/0.420/0.395.

Lightening scales all three channels together; desaturating requires them to diverge.

## And "same material" is not "looks the same" — check StudsPerTile against the PART

The sōrin already wore the bell's exact Metal + BronzePatina + colour and still looked
nothing like it. BronzePatina tiles at 4 studs:

    BellBody   smallest face 10.20 studs -> 2.55 tiles, the patina reads
    SorinMast  smallest face  0.45 studs -> 0.11 of ONE tile, a single flat sample

**Small parts need their own PITCH, not their own material.** `BronzePatinaFine` is
the same four maps at 0.6, exactly as `HempRopeFine` is to `HempRope` and `NorenCloth`
is to bare Fabric. Before concluding a material is wrong, divide the part's smallest
visible face by the variant's StudsPerTile.

**Judge a tint at EVERY scale that wears it** — a bell-sized slab AND a 0.45 mast,
side by side. And judge by looking: none of the above was predictable from the hex
values.

Related: [[material-and-mesh-traps]], [[rojo-meshpart-rbxm]] (the ambientCG →
MaterialVariant pipeline), [[arena-square]].
