# Arena "Water Striker" Centerpiece — Visual/Art Pass Design

**Date:** 2026-07-20
**Branch:** `m4b-zendojo-art-pass`
**Status:** Design approved (brainstorm), ready for implementation plan.

## Goal

Raise the Arena centerpiece — the bonshō bell, its supporting shōrō (bell
tower), the World-Throw drum, the waterwheel, and the visible drive-chain — from
placeholder geometry to hero-quality art that matches the surrounding
high-fidelity canyon (cobble paths, chōchin, arched bridge, falls). Today the
centerpiece is a monochrome-brown "sore thumb"; this pass makes it the visual
anchor it deserves to be.

**In scope:** visual/material/mesh treatment of every visible surface of the
centerpiece.
**Out of scope (deferred to a later technical pass):** the drive-chain
*mechanism kinematics* — cam profile math, gear ratios, the hammer/pin-wheel
timing. This pass may *reshape drive-chain geometry for looks* but does not
re-engineer how the mechanism works.

## Reference

User-supplied photo: a Japanese shōrō (temple bell tower) — weathered
silver-gray aged hinoki cypress posts/beams, stacked tokyō bracket complexes,
carved dragon corner brackets, exposed radiating rafters under deep upturned
eaves, a near-black slate hip roof, and a dark bronze-green patinated bonshō
bell (studded chi band, ribbed obi panels, ryūzu dragon crown, lotus tsuki-za
striking boss). File: `~/Desktop/Roshambo Reference/1280px-Bonsho_of_Kan-noji_TempleEdogawaTokyoJapan.webp`.

## Governing decisions (locked during brainstorm)

1. **Method — Hybrid:** generated/imported **meshes** for the organic hero
   pieces (cast bell, ryūzu, tsuki-za, hip roof, cam, gears, wheel);
   hand-built **primitives** for the structural timber that bolts to the working
   mechanism.
2. **Mesh source — Per-piece mix:** procedurally generate most hero meshes via
   the Studio AI mesh tools (MCP `generate_mesh` / `generate_procedural_model`);
   hunt the Marketplace only for the hardest carvings (optional now that dragons
   are demoted). **Every imported model is backdoor-scanned before publish**
   ([[roblox-toolbox-backdoor-scan]]), TextureID stripped, MaterialVariant
   applied.
3. **Coverage — Skin everything now:** bell, tower, drum, waterwheel, AND
   drive-chain all get a coherent pass in this project. Only mechanism
   kinematics are deferred. Accepted tradeoff: some drive-chain parts may need
   re-skinning if the later technical pass changes their geometry.
4. **Palette — Weathered gray (match the reference):** sun-bleached silver-gray
   cypress, dark bronze-green bell, near-black slate roof. Deliberately reads as
   ancient/sacred against the maintained warm paths.
5. **Dragons — nice-to-have, low-effort-only:** the tower's carved dragon
   *corner brackets* are optional; skip if not cheap. The bell's **ryūzu**
   crown stays (it is the structural hanger and needs a sculpted form, kept
   stylized).

## Architecture — the pipeline this runs through

The centerpiece geometry is **procedural and Rojo-managed**, not hand-placed:

```
builder .luau (Bonsho, Shoro, Waterwheel, BellDrive, ThrowDrum)
    → lune run tools/genmodels
    → roblox/assets/*.model.json  (committed)
    → Rojo
    → Workspace.RoshamboStage.<Model>
```

Therefore the art pass = **rewriting the builder modules** in
`roblox/tools/builders/`, extending the emit vocabulary (`Spec.luau`), and
adding palette entries (`src/shared/themes/ZenDojo.luau`), with uploaded mesh
assets baked in as `MeshId` literals. Everything flows through
genmodels → Rojo → CI (Lune tests + byte-determinism check).

**Do NOT hand-add meshes to `RoshamboStage` in Studio** — Rojo owns exactly what
`default.project.json` names, and the next build wipes place-side additions
([[roblox-rojo-vs-place-state]]). MCP-generated meshes must be captured back
into the pipeline: generate → upload → bake `MeshId` into the builder.

### Emit vocabulary extension (`Spec.luau`)

Add `Spec.meshPart(name, props)` emitting `className = "MeshPart"` with:
- `MeshId = "rbxassetid://…"` (required)
- `TextureID = ""` (cleared so the MaterialVariant shows — per texturing recipe)
- optional `MaterialVariant`, plus the usual `Size` / `CFrame` / `Color` /
  `Material`.

Verify Rojo emits a valid MeshPart node from this shape (MeshId + Size at
minimum).

### Palette (`ZenDojo.luau`) + MaterialVariants

New palette entries: `cypressWeathered` (silver-gray aged cypress),
`bronzePatina` (dark verdigris green-black), `slateTile` (near-black tile,
refines existing `ink`), `ironDark` (hardware/bands/chains/gears), and a
wet/mossy variant for the dipping paddles.

MaterialVariant **definitions** are created once in MaterialService (same
mechanism as the existing `CanyonMossySlate` / `ZenCement2`); builders reference
them by name via the `MaterialVariant` property. World-space projection, tune
`StudsPerTile` ([[roblox-texturing-pack-meshes]]). Clear any baked TextureID.

### The mechanism contract (MUST be preserved)

The client controllers `WaitForChild` these exact part names and animate them by
pivot; art edits must keep emitting them at the same positions, or the working
(signed-off) mechanism breaks:

- **BonshoRig:** `Bonsho` (invisible strike proxy, Transparency=1, CanCollide
  off), `ShuMoku`, `ShuMokuDrawDowel`, `ShuMokuDowel`, `Chain1`–`Chain4`.
- **Waterwheel:** `Wheel1` (WheelController locks its spin), `RatchetDrum`.
- **ThrowDrum:** `Drum` + the south-spoke pins (DrumController / pin-wheel
  drive contract).
- **BellDrive:** the cam/gear/shaft parts the drive references
  (`DriverGear`, `CamGear`, `Cam`, `CamShaft`, `DriveGearA`/`B`, paddles,
  yokes, bearings).

The *visible* bell (`BellSection1-5`/`BellDome`/`CrownLug`) is static dressing →
safe to replace with a mesh; the invisible `Bonsho` proxy stays.

## Components (per hero asset)

### 1. Bonshō bell — `tools/builders/Bonsho.luau`

Dimensions unchanged: center `(-2, 121, 0)`, height 13.5, radius 5.1.

| Reference feature | Change |
|---|---|
| Cast-bronze body (straight flank, rounded kasagata shoulder, flared mouth) | Replace `BellSection1-5` + `BellDome` with one generated cast-bell **MeshPart** `BellBody` (surface of revolution, mobile-cheap polys). |
| Ryūzu — twin-dragon crown loop | Replace box `CrownLug` with a **ryūzu mesh** (keep the name `CrownLug` for the hanger math), stylized. |
| Chi (stud rows), obi/tsuki bands, inscribed panels | Baked into the bell mesh + `bronzePatina` MaterialVariant (verdigris, patina streaks). |
| Tsuki-za lotus striking boss | Upgrade `LotusBoss` to a lotus-relief disc, kept exactly at the shu-moku strike point (survives resize). |
| Iron strap/chain from beam | Keep `BellHanger` + `Chain1-4`, reskinned `ironDark`. |

Preserved: `Bonsho` proxy, `ShuMoku`, both dowels, chains, gantry.

### 2. Shōrō tower + hip roof — `tools/builders/Shoro.luau`

Posts on an 18-stud square; roof top ~y134.

- **Posts → weathered cypress:** keep as primitives (structural), reskin to
  `cypressWeathered` with subtle taper/chamfer + grain. Slate plinths refined.
- **Beam frame:** ring beams + `BellBeam` reskinned `cypressWeathered`, with
  projecting carved nose-ends (`kibana`) as cheap primitive detail.
- **Tokyō bracket complexes:** NEW stepped **primitive block-stacks** atop each
  post (no mesh). **Dragon corner brackets = optional/low-effort** — skip if not
  cheap; if pursued, a small generated or vetted-marketplace dragon-head mesh.
- **Hip roof → generated mesh** `RoofMesh`: curved upturned eave corners,
  layered eave, `slateTile` texture. Plus a fan of **exposed rafter tails**
  (thin primitives) under the eaves. Upgraded finial.

**Drum/roof composition (resolved): raise the drum.** The hexagonal ThrowDrum
sits directly above the roof (drum center y148, r7 → bottom ~y141; roof top
~y134), leaving only ~5–7 studs — which is why the roof was flattened before.
Resolution: **nudge the drum up ~4–6 studs** (layout-only: `throwDrum.pos` + its
yokes) so a proper hipped roof fits beneath it.

**Coupling to respect:** the drum's pin-wheel drive (`DriveGearB` paddles flick
the drum's south-spoke pins at ~y136) must rise by the *same delta*, or it stops
engaging. Raising the drum = raise drum + yokes (`DrumYoke1-4`/`DrumBearing`) +
the top of the pin-wheel linkage (`vertTop`, `DriveGearA`/`B`) together — a
layout change verified at a live staging gate.

### 3. ThrowDrum — `tools/builders/ThrowDrum.luau`

Hexagonal result drum → weathered-wood staves with **iron hoop bands**, real
spokes/hub, and crisp **R/P/S result faces** on the six panels. Keep `Drum` +
south-spoke pins (drive contract). Reskin A-frame yokes to match tower timber.

### 4. Waterwheel — `tools/builders/Waterwheel.luau`

Solid disc → proper undershot **mill wheel**: twin rims, spokes, **paddle
buckets**, iron hub. `cypressWeathered` above the waterline; wet/darkened +
mossy on the dipping paddles. `Wheel1` stays the animated part (mesh or refined
primitive assembly); keep `RatchetDrum`.

### 5. Drive-chain — `tools/builders/BellDrive.luau`

- 80-part faceted snail cam (`CamEdge1-80`) → **single smooth cam mesh** `Cam`.
- Flat disc gears (`DriverGear`, `CamGear`, `DriveGearA`/`B`) → **toothed gear
  meshes** in `ironDark`/bronze.
- Shafts → weathered timber with iron collars at the bearings.
- Caveat (accepted): the later technical pass may reshape these; some re-skinning
  possible.

## Testing

- **Contract test (new, important):** assert each builder still emits every
  animated part name (`Bonsho`, `ShuMoku`, `ShuMokuDrawDowel`, `ShuMokuDowel`,
  `Chain1-4`, `Wheel1`, `Drum`, cam/gear names). An art edit must not silently
  break the mechanism.
- **Determinism/regen:** `lune run tools/genmodels` output stays byte-stable
  arm64 ≡ x86_64 ([[roblox-genmodels-arch-portability]]); MeshIds are static
  literals; any new bracket-stack math rounds in JsonEmit (no
  transcendental-into-hash).
- **Green bars:** `lune run tests/run`, `rojo build -o build.rbxl`,
  `stylua --check src tests tools`, `selene src` all clean.
- **Visual sign-off is manual:** live Studio staging gates via the MCP
  (`screen_capture`), **one attempt then stop-and-ask**
  ([[stop-and-ask-after-each-attempt]]). No automated "looks good."

## Build order (per-asset vertical slices, bell-first)

Each slice: edit builder → `genmodels` → Rojo sync → live screenshot gate →
adjust → commit. Each is independently reviewable (good for subagent-driven
development).

1. **Pipeline groundwork:** `Spec.meshPart`, palette entries + MaterialVariant
   setup, contract-test scaffold.
2. **Bell** (bonshō mesh + ryūzu + tsuki-za + patina) — validate the money shot
   first.
3. **Tower** posts/beams reskin + tokyō brackets + rafters.
4. **Hip roof** mesh + raise drum (coupled linkage) + finial.
5. **ThrowDrum** dressing.
6. **Waterwheel.**
7. **Drive-chain** (cam + gear meshes + shafts).
8. **Final composite staging gate** + branch finish.

This is a large but cohesive pass — likely several sessions, one asset-slice at
a time.

## Risks / open items

- **Mesh quality is iterative.** MCP-generated hero meshes (bell profile, hip
  roof) may need several passes; the ryūzu and lotus boss are small and
  forgiving. Fallback for any piece that won't generate cleanly: a refined
  primitive assembly or a vetted marketplace mesh.
- **Mobile poly budget.** Roshambo targets phones; keep hero meshes
  low-to-moderate tri-count, no per-part heavy CollisionFidelity.
- **MaterialVariant persistence.** Confirm how the existing MaterialVariant
  definitions are persisted (Rojo-managed vs. saved-with-place) and follow the
  same path for the new ones so they survive a `rojo build`.
- **Drum-raise is mechanism-adjacent.** Layout-only, but must be verified live
  that the pin-wheel still engages the raised spokes before commit.
