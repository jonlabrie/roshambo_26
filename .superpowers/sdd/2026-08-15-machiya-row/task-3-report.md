# Task 3 Report — the archetype grows its variants

**Status: COMPLETE** — commit `c173cb1` on `m4b-zendojo-art-pass`.
Files: `roblox/tools/builders/Machiya.luau`, `roblox/tests/Machiya.spec.luau`.

## What each branch does

### Frontage
- The shared shopfront constants (`HEAD_Y`, `TRANSOM_TOP`, `DOOR_Z`, `FRAME_D2`, `FRAME_Z`, `LAT_D`, `LAT_Z`) were hoisted above the branch so both frontages build from the same planes. `FRONT_POSTS`/`postX`/`CLOSED` are declared before the branch; the open branch populates them, the kōshi branch leaves them empty (which is what makes the noren emitter a no-op there by construction).
- **`open`** — unchanged: five posts, HeadRail, closed outer bays, sliding shoji bays.
- **`koshi`** — closes the street wall: a rendered `FrontWall` (stucco, set back `STUCCO_SETBACK`, between the side walls like `WallBack`), `KoshiPostWest/East` corner posts standing where FrontPost1/5 stand, a `KoshiSill`/`KoshiHead` timber frame at `FRAME_Z` (front faces exactly on the frontage plane), and full-width `KoshiFront_<i>` lattice from sill to kamoi. Reuses `KOSHI_T`/`FRAME_VAR`; bar count is integer-derived at the upper storey's pitch (`KOSHI_N` = 18 bars / 12 studs = 1.5 bars per stud), so emitted floats stay arch-stable. Nothing reaches north of Z0; faces land exactly on it.

### Interior
- **`full`** — exactly 花火屋: four-piece upper floor around the stairwell, stair, attic ties, counter, inline identity (vermilion noren + kanban). Byte-identical, see the gate below.
- **`shallow`** — keeps slab/posts/walls/roof/upper lattice/eave/gables; the upper floor becomes ONE uncut board (no stair ⇒ no well); no stair, no attic ties, no counter, no inline identity.
- **`none`** — shallow, and additionally the identity kit's interior lighting hooks (`glow`) are suppressed.
- The two storey-dependent stair asserts in the preamble (`STAIR_RISE == 0.8`, stairwell headroom) are now gated on `interior == "full"` — a shallow shell with custom storeys owes nothing to a stair it doesn't have.

### Identity kit (`shop.identity`, all fields nil-safe)
- `noren` — the existing segment-chain emission generalized into `emitNoren(colour, nSegs)`; the inline 花火屋 call (`palette.vermilion`, 3) happens at the same emission site as before, gated `interior == "full"`. Kit noren emits per open bay; over a kōshi frontage it emits nothing.
- `chochin` — the eave-corner pair, 花火屋's pattern (from `tools/studio/buildHanabiyaChochin.luau`, owner scale LS 0.65/0.9), restated as static specs: `ChochinWest/East` models — Hook under the eave underside (the tilted-slab plane evaluated at the hang z, vertical half-thickness via `hisashiLen/EAVE_OVERHANG`, i.e. sqrt not trig), HangRod, 10-slice gradient paper barrel (Neon, Transparency 0.42) with a PointLight in the centre slice, 8 ribs, caps, and two invisible `GlyphPlateA/B` tagged `RoundLantern` facing along the street (via `Spec.yaw(±90)`, the CI-proven rotation path). The profile is `capR + (Rmax−capR)·sqrt(1−d⁶)` computed with multiplies + `math.sqrt` — **no trig, no pow** — per the arch-stability constraint. Hem-clearance assert at ≥ 5.0 (the owner's duck-under ruling, matching the Studio recipe).
- `board` — one blank `SignBoard` slab (no signage copy — the wager-language ruling), width `min(0.55·W, 10)`, back face on the frontage plane above the kamoi (aerial at 7.2+, clears an avatar).
- `glow` — `InteriorGlow_1/2` invisible anchored carriers each with a PointLight child (`Glow`), colour/brightness from the kit; skipped when `interior == "none"`.
- `dress(ctx)` — called last; `ctx = { env = {x0,x1,z0,z1,floorY,w,d,cx,cz}, palette, consts = {SLAB_T, COUNTER_H, POST_W, KOSHI_T} }`; returned specs land under a child model named exactly `Dressing`. No `Dressing` model is created when `dress` is absent.

### Yaw (the FINAL pass)
`shop.yaw ~= 0` triggers a recursive walk over the whole finished tree — **including parts nested in child models** (noren segments, chochin, Dressing). Position: `Spec.rotY(pos − centre, yaw) + centre` about the envelope centre `(CX, CZ)`; rotation: `Spec.matMul(Spec.rotYMat(yaw), rot)`. Nodes without a `properties.CFrame` (SurfaceGui/PointLight/model shells) are skipped but recursed through. `yaw == 0` skips the pass entirely, so an unyawed shop's floats are byte-for-byte untouched.

## RED / GREEN evidence

RED (brief's three tests verbatim + one hardening test, before implementation):
```
FAIL  machiya variants > shallow interior emits no stair, no attic, no well
      .../tools/builders/Machiya:19: only the hanabiya configuration is implemented until Task 3
FAIL  machiya variants > koshi frontage closes the street wall and opens nothing
FAIL  machiya variants > yaw rotates every part about the envelope centre
FAIL  machiya variants > yaw carries EVERY part, nested noren segments included
1113 passed, 4 failed, 1117 total
```
GREEN (after implementation + stylua):
```
1117 passed, 0 failed, 1117 total
```

**Fourth test rationale:** the brief's yaw test probes `allParts(m)[1]`, which is the FloorSlab — dead on the envelope centre, so a yaw pass that silently did nothing would still pass it. The added test builds an interior-`full` shell flat and spun 90°, confirms the nested `Noren*` models exist, then walks BOTH part lists in parallel asserting the mapped position (x/y/z) and the turned rotation matrix (`r00' = −r20`, `r02' = r22`) for **every** part — nested segments included. The brief's three tests are otherwise semantically verbatim (stylua line-formatting only).

## Byte gate

```
$ ~/.rokit/bin/lune run tools/genmodels   # wrote assets/Hanabiya.model.json (+16 others)
$ git diff --exit-code assets/Hanabiya.model.json
BYTE GATE: CLEAN                          # exit 0; git status shows only the two source files
```

## Suite / lint

- `~/.rokit/bin/lune run tests/run` → **1117 passed, 0 failed** (every pre-existing Machiya test passes; the `[QUEUE]` warnings in output are HandlerQueue.spec's own expected noise).
- `~/.rokit/bin/stylua --check src tests tools` → clean.
- `~/.rokit/bin/selene src tools` → 0 errors, 0 warnings (CI scope; selene fails on warnings).

## Self-review findings

1. **Did the yaw pass miss nested parts?** No — held by the added parallel-walk test over every part including noren segments, and rotation matrices are checked, not just positions.
2. **Does `identity = nil` emit exactly what it did before?** Yes — the Hanabiya byte gate is clean, which is the strongest possible form of that claim (same bytes, same order, same floats).
3. **Kit paths not covered by the brief's tests** (chochin/board/glow/dress) were smoke-tested under Lune (scratchpad script, not committed): SignBoard/ChochinWest/ChochinEast/InteriorGlow_1,2/Dressing all emit; glow is correctly suppressed for `interior == "none"`; kit noren emits over open bays and nothing over kōshi; the DressCtx env/palette/consts contract was asserted field-by-field; a yaw-33° kit build serializes deterministically through JsonEmit (two runs, identical strings).
4. **Name collisions:** inline identity emits `Kanban`/`KanbanFrame*`; the kit's `SignBoard` is distinct — no collision, and the byte gate confirms nothing moved.
5. **Discrepancy in the brief, resolved:** the brief says "chochin via the eave-corner recipe already in the file's sign/chochin region" — Machiya.luau has no chochin region; the recipe lives in `tools/studio/buildHanabiyaChochin.luau` (place-only Studio tool). I ported that recipe (hang geometry, scale, gradient, glyph plates) into trig-free static specs. The Studio pair remains place-only for 花火屋 itself; only kit shops get builder-emitted chochin.
6. **Arch-stability:** new float sources are multiplies, divides, `math.sqrt`, and `Spec.yaw(±90)`/`Spec.rotY`/`Spec.matMul` — no `math.sin/cos` outside the sanctioned helpers, no `^`. Tasks 4–6 assets built from these branches will hold under the arm64/x86_64 drift check.
7. **Not done here (correctly):** no new `default.project.json`/`WorkspaceConvention` entries (no new stage model ships in this task), no wiki update (no owner gate, no shipped shell), inline 花火屋 identity NOT migrated to the kit (per the brief).

## Concerns for downstream tasks

- The koshi lattice pitch (1.5 bars/stud) and the SignBoard/glow placements are reasonable defaults awaiting the Tasks 4–6 owner gates — expect owner tuning, none of it structural.
- `interior == "full"` + `frontage == "koshi"` is an unused combination: it would emit no counter/noren (they register to open bays) but would still build the stair. No current or planned shop uses it; flagged, not "fixed".

---

## Fix report — review round 1 (commit `33195e9`)

Two quality findings from the coordinator's review, both addressed.

### Finding 1: no committed coverage for 4 of 5 identity-kit fields
Added `test("the identity kit dresses a shell, field by field")` to the
`machiya variants` describe-block in `roblox/tests/Machiya.spec.luau`. It builds
the synthetic SHELL with a full kit (noren, chochin, board, glow, dress) and asserts:
- `ChochinWest`/`ChochinEast` models exist (the eave-corner pair);
- kit noren emits (`Noren2_1`);
- `SignBoard` exists AND has no children — blank means no SurfaceGui, no copy;
- at least one `InteriorGlow_` part exists;
- `find(m, "Dressing")` exists and contains the dress callback's `TestProp`
  (built via `Spec.part`/`Spec.cframe` from `ctx.env`);
- with `interior = "none"`: no `InteriorGlow_` part anywhere, while SignBoard and
  chochin stay — "none" suppresses exactly the lighting hooks.

Falsifiability (RED) evidence: with the board branch temporarily stubbed
(`SignBoard` → `SignBoardX` in Machiya.luau), the test fails:
```
FAIL  machiya variants > the identity kit dresses a shell, field by field
1117 passed, 2 failed, 1119 total
```
Branch restored immediately after; test green against the real implementation.

### Finding 2: `frontage="koshi", interior="full"` crashed as nil arithmetic
Added the assert at the top of `Machiya.build` exactly as prescribed:
```
assert(
    not (shop.frontage == "koshi" and shop.interior == "full"),
    "a koshi frontage cannot carry the full interior: the counter and stair register to the open bays"
)
```
with a comment naming the real cause (counter/noren register to the open bays'
`postX`, which a kōshi frontage never populates). Companion test
`"koshi + full interior refuses loudly, not with nil arithmetic"` pcalls the build
and asserts failure with that message. TDD RED captured before the assert existed —
the pcall failed on the old nil-arithmetic crash, so the message match failed:
```
FAIL  machiya variants > koshi + full interior refuses loudly, not with nil arithmetic
1118 passed, 1 failed, 1119 total
```

### Gates after the fixes
```
$ ~/.rokit/bin/lune run tests/run                       -> 1119 passed, 0 failed, 1119 total
$ ~/.rokit/bin/lune run tools/genmodels
$ git diff --exit-code assets/Hanabiya.model.json       -> exit 0 (BYTE GATE: CLEAN)
$ ~/.rokit/bin/stylua --check src tests tools           -> clean
$ ~/.rokit/bin/selene src tools                         -> 0 errors, 0 warnings
```
Commit: `33195e9` — `fix(roblox): commit identity-kit coverage; refuse koshi+full loudly`.
