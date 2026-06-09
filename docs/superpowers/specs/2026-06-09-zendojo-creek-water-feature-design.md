# ZenDojo Creek Water-Feature Rework — Design

**Goal:** Replace the engineered kakehi flume with a natural creek that descends the amphitheater from the SW rim and physically motivates the whole machine — the current turns an Asakura-style waterwheel, which works the shu-moku striker against the bell, while a streamside sōzu meters the round and kicks the throw drum.

**Architecture:** Geometry stays code-driven — pure builders in `roblox/tools/builders/` → committed `assets/*.model.json` (genmodels) → `default.project.json`; `ArenaLayout.luau` remains the single coordinate authority; the creek bed/water is carved in the MCP-run terrain heightfield (`tools/studio/buildTerrain.luau`); client controllers animate the moving parts over the existing `EventBus` cues. This supersedes the M4b water feature (the T9 wheel keeps its role but moves; the T10 kakehi flume is deleted).

**Tech Stack:** Luau, Rojo, Lune test harness, Roblox Terrain (WriteVoxels), MCP Studio for graybox/gates.

---

## 1. Vibe & guiding principle

The arena is a **natural amphitheater with a creek running through it, made into a Japanese public garden** — not a millworks. Every piece of "machinery" must read as a tranquil garden object that *happens* to do work: a wheel sitting in a stream, a deer-scarer that tips. No elevated launders, no aqueducts, no exposed plumbing. If a member reads as "engineering," it's wrong.

## 2. Spatial layout

**The creek** enters at the **SW rim** and runs a fairly straight line down the slope to the central basin, chosen deliberately for sightlines: a player descending the **south** sandō sees the working water off to their left, converging on the shrine, instead of it hiding behind the monument. The creek line is the SW diagonal (the `x = z`, both-negative line); the sandō is the due-south line (`x ≈ 0`). They only meet at the basin, so **no path-crossing bridge is needed** — the creek simply runs parallel-left of the approach and spills into the pond.

**Drive-train rotation.** The wheel → log → strike chain rotates off the current N–S axis onto the **SW–NE diagonal** so the creek runs straight into the wheel:
- Waterwheel cluster sits where the creek meets the basin's SW edge.
- The shu-moku log runs from the wheel toward the bell along the SW–NE line; it draws toward the SW (toward the wheel) and swings NE into the **bell's SW face**.
- The **throw drum keeps its current orientation and happy/sad windows** (N/S facing) — only the wheel, log, gantry, and drive rope move.

**Target coordinates** (basin r16, apron r84, tiers 116/6·152/16·188/28; SW unit ≈ (−0.707,−0.707)). These are starting points; exact placement is tuned at the graybox USER GATE:
- Creek entry ≈ rim at 225° ~(−134, 28, −134); descends to the basin (y0).
- Driving wheel ≈ (−16, ~5, −16) (innermost, in the fast reach just outside the basin).
- Decorative wheels ≈ (−22, −22) and (−28, −28) up the creek.
- Shu-moku rest ≈ (−7, ~6, −7); strikes the bell SW boss at ~(−3.6, strikeY, −3.6).
- Sōzu ≈ (−20, ~3, −14), streamside beside the driving wheel.

## 3. The waterwheel — Asakura-style undershot cluster

Model the **三連水車** register (Horikawa canal, Fukuoka): big rustic wooden wheels sitting **in** the flowing creek, turned by the **current** against their lower paddles (undershot), grouped as a small **cluster of 2–3**. To get enough push, the creek eases from its steeper descent into a flatter, slightly **narrowed fast reach** at the wheels (the narrowing speeds the current), then carries the spent water the short way into the basin. We keep the Asakura *form* (current-driven, clustered) but drop the literal irrigation-scoop-to-field function — except for one small scoop feed to the sōzu (§5).

Only the **innermost wheel drives** the striker (drive rope to the log); the others turn purely for the look. All turn slowly and majestically — the tranquil register, not a mill race.

## 4. The throw-drum driver — streamside sōzu

A **sōzu (shishi-odoshi)** beside the driving wheel meters the round and kicks the drum:
- A small scoop on the wheel lifts a trickle into a **short bamboo spout** (a single rustic kakehi pipe — the one allowed "pipe," because a bamboo spout *is* a garden element) that feeds the sōzu.
- The sōzu **fills through the ACTIVE phase**, then **tips/dumps at lockout** — the water-clack *is* the lockout cue.
- The dump **kicks the throw drum into its spin**, transmitted by a **single taut cord** running from the sōzu's pivot up over the pavilion's SW beam to the drum (same visual vocabulary as the existing drive rope), or kept lightly stylized if the cord reads as clutter at the graybox gate.

**Timing maps cleanly onto the round:** fill (ACTIVE) → dump/clack (lockout) → drum spins → gong (reveal) → drum lands. This is why the sōzu beat the lineshaft: its intermittent fill-then-dump rhythm matches the drum's intermittent kick-then-land, where a continuously-turning shaft did not (and grayboxing the shaft showed it merely read as another pavilion post with an awkward belt to the high, centered drum axle).

**Drum behavior is unchanged.** `DrumController` keeps hold-during-ACTIVE → spin at `latchClick` → glide-to-rest at `gongStrike`. The sōzu is synced to the *same* `latchClick`/round cues, so it supplies the visible *cause* of the existing motion without changing it.

## 5. The creek — terrain channel + dressing

**Terrain (heightfield):** carve a creek channel from the SW rim down to the basin, following the SW diagonal, descending y28→y0. Where the channel crosses each tier wall it **steps down a small cascade**; through the wheel reach it flattens and narrows. Fill the channel with `Water` material as one connected ribbon (same lesson as the tanada paddy strips — one continuous waterline, no pooled segments). The monument zone (r<40) is currently held exact/flat; the channel must extend a **notch into the SW apron/basin** so the creek and wheels sit in real water rather than on the flat gravel.

**Dressing (builder parts):** creek-bed river stones, mossy banks, the cascade rocks at each step, and a few placed boulders/stepping-stones along the bank as garden punctuation (no functional crossing). Materials per the ZenDojo palette (water, gravel, moss, timber, ink).

## 6. Components to change

**Delete:** `tools/builders/Kakehi.luau` (flume) — remove from `genmodels.luau` OUTPUTS, `default.project.json`, the committed `assets/Kakehi.model.json`, and any Kakehi test.

**Builders (`roblox/tools/builders/`):**
- `Waterwheel.luau` — rework from a single wheel into the SW **cluster** (e.g. `Wheel1`/`Wheel2`/`Wheel3`, axles perpendicular to the SW→NE flow). Keep the model name `Waterwheel` to minimize project.json/controller churn.
- `Sozu.luau` *(new)* — the lever (filled/empty pivot poses), pivot post, bamboo spout, and catch basin.
- `Creek.luau` *(new)* — bank/bed stones, cascade rocks, stepping-stone punctuation (the water itself is terrain).

**`ArenaLayout.luau`:** remove `flume`; add `creek` (entry, path samples, channel width, fast-reach bounds, basin spill), `waterwheel`/cluster positions, and `sozu` (pivot, spout, cord anchors); move `shuMoku` (rest, draw, gantry rails, chain tops/bottoms, drive-rope anchors) onto the SW–NE diagonal.

**Controllers (`roblox/src/client/`):**
- `WheelController.client.luau` — retarget to the cluster's new SW position; spin all wheels (driver + decorative); update inlined ArenaLayout constants (keep-in-sync comment).
- `HammerController.client.luau` — **re-aim the approved swing onto the SW–NE diagonal**: draw toward SW, swing NE into the bell's SW face; update the inlined chain/rope constants and the swing/recoil offset vectors. Preserve the motion *feel* the user already approved — only its heading changes.
- `SozuController.client.luau` *(new)* — fill the lever through ACTIVE (phase/clock driven), dump on `latchClick`, animate the cord; basin ripple where the creek enters the pond.
- `DrumController.client.luau` — **unchanged.**

**Terrain (`tools/studio/buildTerrain.luau`):** add the creek channel + water to the per-column heightfield function and the SW basin notch; keep the rest of the bowl intact.

## 7. What to preserve (risks)

- **The approved hammer motion** — it must survive the SW rotation. The controller swings *relative* offsets from the part's rest CFrame, so re-aiming is a matter of rest pose + offset directions, not a rebuild. Verify live.
- **The bell strike-boss** stays anchored to the log's strike height (already done); after rotation it sits on the bell's SW face.
- **Drum windows / happy-sad lore** — drum orientation does not change.
- **Controller/ArenaLayout sync** — the inlined client constants are build-time mirrors of `ArenaLayout` (not replicated); every coordinate move updates both.

## 8. Testing

- `ArenaLayout.spec` — creek entry on the rim and inside the bowl; wheels on the creek line and reachable; sōzu streamside; log rest→strike spans the bell SW face; nothing buried.
- Builder specs — `Waterwheel` cluster part count/positions; `Sozu` members; `Creek` dressing present.
- `genmodels` drift check stays green; `stylua`/`selene`/`rojo build` pass.
- Live (USER GATE): creek reads natural and fast; wheels turn in the current; sōzu fills/dumps on cue and the drum kicks; hammer still strikes true on the new axis; no flume remnants.

## 9. Build sequencing (for the plan)

1. ArenaLayout: delete `flume`, add `creek`/`sozu`, rotate `waterwheel`+`shuMoku` to SW.
2. Delete Kakehi (builder, asset, project.json, genmodels, test).
3. Rework `Waterwheel.luau` into the cluster; regen; **graybox gate**.
4. Terrain: carve creek channel + SW basin notch + water; **MCP gate**.
5. `Creek.luau` dressing (stones/cascades/banks).
6. `Sozu.luau` + `SozuController` + cord.
7. Retarget `WheelController` and **re-aim `HammerController`** to SW; verify the strike.
8. **USER GATE:** full water feature live (creek → wheel → striker → bell, sōzu → drum), then tune.
