# Fireworks Vocabulary (Wave One) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give firework recipes five visibly different burst styles, staged multi-burst structure, a glow treatment, real textures, and an audio triage pipeline — all provable at the proving range, all inside the measured mobile budget.

**Architecture:** A pure shared `BurstStyles.luau` maps each style to a complete emitter configuration plus a point-placement rule; `style` rides burst phases as a field (budget math untouched — only a passthrough in the schedule compiler); `FireworkController.fireBurst` applies the full style set per emit with seeded randomness; textures and sounds are role-keyed tables so uploads are one-edit swaps.

**Tech Stack:** Luau (strict) + Lune test harness (`roblox/tests/harness.luau`); Python 3 + numpy (audio tools convention: self-contained, in `roblox/tools/audio/`), PIL for sprites.

**Spec:** `docs/superpowers/specs/2026-09-02-fireworks-vocabulary-design.md`

## Global Constraints

- Client-side VFX only; pooled emitters; NO per-shell PointLights; ONE global Bloom, never a second; no instance churn. The director cap and per-shell particle budget stay exactly as measured.
- **A style must never change a shell's particle cost** (budget invariance is test-enforced in Task 3).
- Styles are COMPLETE: every style declares every property in `BurstStyles.APPLIED` — pool emitters are shared, and an unwritten property inherits the previous shell's value (test-enforced in Task 1).
- Anything random that all clients must agree on (ring tilt, palm arm phase) derives from the shell's seeded RNG, passed as a plain `() -> number` function so the modules stay pure and Lune-testable.
- Shared modules: pure `--!strict` Luau, no Roblox types (NumberRange/NumberSequence/Vector3 are constructed only in the controller).
- Draft family names are romaji (`wa`, `yashi`, `hotaru`, `kamuro`, `dan`); kanji only in comments.
- The owner's reference dir `~/Desktop/Roshambo Reference/sound/fireworks/` is READ-ONLY; zip expansion goes to the sibling `~/Desktop/Roshambo Reference/sound/fireworks_expanded/`.
- Lint gate (from `roblox/`): `stylua --check src tests tools && selene src tools`. Tests: `lune run tests/run`. If stylua complains, run `stylua src tests tools` and re-check.
- `.client.luau` files are untested by design; decisions live in pure modules.
- Commit after each task, repo message style, with trailers:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` and
  `Claude-Session: https://claude.ai/code/session_01Vw3EoAN2H4ZcRXNtu2mFco`.

## File Structure

| File | Responsibility |
|---|---|
| `roblox/src/shared/BurstStyles.luau` (create) | Style table, APPLIED list, TEXTURES/SOUNDS roles, `pointFrames`, `MAX_POINTS`, `releaseTail` |
| `roblox/src/shared/FireworkRecipes.luau` (modify) | Schema: `style` membership + staged-field validation |
| `roblox/src/shared/FireworkSchedule.luau` (modify) | `style` passthrough only |
| `roblox/src/client/FireworkController.client.luau` (modify) | Glow stack, style application, style-aware slot release |
| `roblox/src/shared/FireworkDrafts.luau` (modify) | Five seed families |
| `roblox/tools/textures/make_firework_sprites.py` (create) | Generates the dot + streak PNGs |
| `roblox/tools/audio/survey_fireworks.py` (create) | Zip expansion + measurement + manifest + category proposal |
| Tests | `tests/BurstStyles.spec.luau` (create), `tests/FireworkRecipes.spec.luau` (extend), `tests/FireworkSchedule.spec.luau` (extend), `tests/FireworkDrafts.spec.luau` (unchanged — must stay green) |

All Luau commands run from `roblox/`.

---

### Task 1: BurstStyles — the style table and point rules

**Files:**
- Create: `roblox/src/shared/BurstStyles.luau`
- Test: `roblox/tests/BurstStyles.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces (later tasks rely on these exact names):
  - `BurstStyles.MAX_POINTS = 8`
  - `BurstStyles.STYLES: { [string]: Style }` with keys `peony, ring, palm, strobe, kamuro`
  - `BurstStyles.APPLIED: { string }` — the property names every style must declare
  - `BurstStyles.TEXTURES: { dot: string, streak: string }`, `BurstStyles.SOUNDS: { [string]: string }`
  - `BurstStyles.styleOf(name: string?): Style` (nil/unknown → `peony`)
  - `BurstStyles.pointFrames(name: string?, points: number, scatter: number, rand: () -> number): { Frame }` where `Frame = { pos: { number }, rot: { number } }` (pos = studs relative to anchor; rot = XYZ Euler degrees for the point part, identity = emit straight up)
  - `BurstStyles.releaseTail(name: string?): number` — the style's max particle lifetime, for slot release.

A `Style` is plain data:

```lua
export type Style = {
    speed: { number }, -- {min, max}
    drag: number,
    lifetime: { number }, -- {min, max}
    acceleration: { number }, -- {x, y, z}
    brightness: number,
    spreadAngle: { number }, -- {x, y} degrees
    transparency: { { number } }, -- keypoints {time, value}
    textureRole: string, -- "dot" | "streak"
    soundRole: string, -- key into SOUNDS
    pointRule: string, -- "scatter" | "circle" | "tilted" | "single"
}
```

The five styles (exact wave-one values — the range's ladders tune from here):

```lua
BurstStyles.STYLES = {
    -- Today's radial break: the adaa1fe recipe (SpreadAngle 360/drag/fade) becomes
    -- peony's row, so the pool can stop hardcoding it.
    peony = {
        speed = { 20, 60 },
        drag = 2.2,
        lifetime = { 1.2, 2.4 },
        acceleration = { 0, -6, 0 },
        brightness = 3,
        spreadAngle = { 360, 360 },
        transparency = { { 0, 0 }, { 0.8, 0.15 }, { 1, 1 } },
        textureRole = "dot",
        soundRole = "burst_peony",
        pointRule = "scatter",
    },
    -- Planar circle of stars, tilted per shell ("tilted" point rule).
    ring = {
        speed = { 34, 42 }, -- tight band: a ring wants even radius
        drag = 2.6,
        lifetime = { 1.4, 1.8 },
        acceleration = { 0, -4, 0 },
        brightness = 3.5,
        spreadAngle = { 360, 4 }, -- fan in the part's plane
        transparency = { { 0, 0 }, { 0.8, 0.15 }, { 1, 1 } },
        textureRole = "dot",
        soundRole = "burst_peony",
        pointRule = "tilted",
    },
    -- Few thick arms, aimed outward-up by the "circle" point rule, falling hard.
    palm = {
        speed = { 26, 34 },
        drag = 1.4,
        lifetime = { 1.8, 2.6 },
        acceleration = { 0, -22, 0 },
        brightness = 3,
        spreadAngle = { 12, 12 }, -- narrow cone per arm
        transparency = { { 0, 0 }, { 0.85, 0.1 }, { 1, 1 } },
        textureRole = "streak",
        soundRole = "burst_peony",
        pointRule = "circle",
    },
    -- A hanging cloud that flickers: the 16-keypoint square-wave transparency.
    strobe = {
        speed = { 8, 16 },
        drag = 3.5,
        lifetime = { 2.2, 3.0 },
        acceleration = { 0, -3, 0 },
        brightness = 4,
        spreadAngle = { 360, 360 },
        transparency = {
            { 0, 0 },
            { 0.1, 0 },
            { 0.12, 1 },
            { 0.2, 1 },
            { 0.22, 0 },
            { 0.32, 0 },
            { 0.34, 1 },
            { 0.44, 1 },
            { 0.46, 0 },
            { 0.58, 0 },
            { 0.6, 1 },
            { 0.72, 1 },
            { 0.74, 0 },
            { 0.88, 0 },
            { 0.9, 1 },
            { 1, 1 },
        },
        textureRole = "dot",
        soundRole = "burst_strobe",
        pointRule = "scatter",
    },
    -- The golden crown: long, heavy, drooping to the water.
    kamuro = {
        speed = { 24, 32 },
        drag = 1.8,
        lifetime = { 3.2, 4.2 },
        acceleration = { 0, -14, 0 },
        brightness = 3,
        spreadAngle = { 360, 360 },
        transparency = { { 0, 0 }, { 0.9, 0.2 }, { 1, 1 } },
        textureRole = "streak",
        soundRole = "burst_kamuro",
        pointRule = "single",
    },
} :: { [string]: Style }
```

Role tables (built-in stand-ins until the owner's uploads clear, per spec §4/§8):

```lua
BurstStyles.TEXTURES = {
    dot = "rbxasset://textures/particles/sparkles_main.dds",
    streak = "rbxasset://textures/particles/sparkles_main.dds",
}
BurstStyles.SOUNDS = {
    burst_peony = "rbxasset://sounds/impact_explosion_03.mp3",
    burst_strobe = "rbxasset://sounds/impact_explosion_03.mp3",
    burst_kamuro = "rbxasset://sounds/impact_explosion_03.mp3",
    report = "rbxasset://sounds/collide.wav",
    ascent = "rbxasset://sounds/swoosh.wav",
}
```

`APPLIED` lists exactly the Style field names above (`speed`, `drag`, `lifetime`, `acceleration`, `brightness`, `spreadAngle`, `transparency`, `textureRole`, `soundRole`, `pointRule`) — the completeness contract the controller applies and the test enforces.

Point rules (`pointFrames`), all pure, all consuming `rand` only:

- `"scatter"`: n frames, `pos = {(rand()*2-1)*scatter, (rand()*2-1)*scatter*0.6, (rand()*2-1)*scatter}`, `rot = {0,0,0}` (today's behavior, orientation reset — the completeness rule extends to the part frame).
- `"tilted"` (ring): ONE frame at `pos = {0,0,0}`, `rot = {rand()*60 - 30, rand()*360, rand()*60 - 30}` — a random plane, never fully edge-on to vertical.
- `"circle"` (palm): n frames evenly on a horizontal circle of radius `math.max(scatter, 2)`: for arm i, `angle = (i-1)/n * 360 + rand()*20`, `pos = {radius*cos, 0, radius*sin}`, `rot` pitches the part's +Y outward-and-up: `{55*sin(angle), 0, -55*cos(angle)}` — wait, express simply: `rot = { math.deg? ... }` — implementer: compute the Euler XYZ that tips the up-axis 35° from vertical toward the arm's outward direction; the spec test below pins the observable property (outwardness), not the exact Euler encoding.
- `"single"` (kamuro): ONE frame, `pos = {0,0,0}`, `rot = {0,0,0}`.

`releaseTail(name)` returns `styleOf(name).lifetime[2]`.

- [ ] **Step 1: Write the failing spec**

`roblox/tests/BurstStyles.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local BurstStyles = require("../src/shared/BurstStyles")

-- A deterministic rand: a fixed sequence, cycling.
local function seqRand(values: { number }): () -> number
    local i = 0
    return function()
        i += 1
        return values[((i - 1) % #values) + 1]
    end
end

describe("BurstStyles — the vocabulary's one source of truth", function()
    test("EVERY STYLE DECLARES EVERY APPLIED PROPERTY", function()
        -- Pool emitters are shared; an unwritten property inherits the previous
        -- shell's value. Completeness is the contract, not a courtesy.
        for name, style in BurstStyles.STYLES do
            for _, prop in BurstStyles.APPLIED do
                if (style :: any)[prop] == nil then
                    error(`style '{name}' is missing '{prop}'`)
                end
            end
        end
        expect(#BurstStyles.APPLIED >= 10).toBe(true)
    end)

    test("the five wave-one styles exist and unknown falls back to peony", function()
        for _, name in { "peony", "ring", "palm", "strobe", "kamuro" } do
            expect(BurstStyles.STYLES[name] ~= nil).toBe(true)
        end
        expect(BurstStyles.styleOf("nosuch") == BurstStyles.STYLES.peony).toBe(true)
        expect(BurstStyles.styleOf(nil) == BurstStyles.STYLES.peony).toBe(true)
    end)

    test("texture and sound roles resolve in the role tables", function()
        for name, style in BurstStyles.STYLES do
            if BurstStyles.TEXTURES[style.textureRole] == nil then
                error(`style '{name}' names unknown textureRole '{style.textureRole}'`)
            end
            if BurstStyles.SOUNDS[style.soundRole] == nil then
                error(`style '{name}' names unknown soundRole '{style.soundRole}'`)
            end
        end
        expect(BurstStyles.TEXTURES.dot ~= "").toBe(true)
        expect(BurstStyles.TEXTURES.streak ~= "").toBe(true)
    end)

    test("pointFrames is deterministic under a fixed rand", function()
        local a = BurstStyles.pointFrames("ring", 1, 0, seqRand({ 0.3, 0.7, 0.1 }))
        local b = BurstStyles.pointFrames("ring", 1, 0, seqRand({ 0.3, 0.7, 0.1 }))
        expect(#a).toBe(#b)
        for i, fa in a do
            for k = 1, 3 do
                expect(fa.pos[k] == b[i].pos[k]).toBe(true)
                expect(fa.rot[k] == b[i].rot[k]).toBe(true)
            end
        end
    end)

    test("scatter rule: n frames inside the scatter box, identity rotation", function()
        local frames = BurstStyles.pointFrames("peony", 6, 8, seqRand({ 0.1, 0.9, 0.5, 0.2, 0.8 }))
        expect(#frames).toBe(6)
        for _, f in frames do
            expect(math.abs(f.pos[1]) <= 8 and math.abs(f.pos[3]) <= 8).toBe(true)
            expect(math.abs(f.pos[2]) <= 8 * 0.6).toBe(true)
            expect(f.rot[1] == 0 and f.rot[2] == 0 and f.rot[3] == 0).toBe(true)
        end
    end)

    test("tilted rule: one frame, tilted but never past 30 degrees off-plane", function()
        local frames = BurstStyles.pointFrames("ring", 5, 10, seqRand({ 0.99, 0.01, 0.5 }))
        expect(#frames).toBe(1) -- a ring is one point regardless of asked points
        local f = frames[1]
        expect(math.abs(f.rot[1]) <= 30 and math.abs(f.rot[3]) <= 30).toBe(true)
    end)

    test("circle rule: arms sit on the circle and rotations differ per arm", function()
        local frames = BurstStyles.pointFrames("palm", 5, 6, seqRand({ 0.5 }))
        expect(#frames).toBe(5)
        local firstRot = frames[1].rot
        local anyDifferent = false
        for _, f in frames do
            local r = math.sqrt(f.pos[1] ^ 2 + f.pos[3] ^ 2)
            expect(math.abs(r - 6) < 0.01).toBe(true)
            expect(f.pos[2] == 0).toBe(true)
            if f.rot[1] ~= firstRot[1] or f.rot[3] ~= firstRot[3] then
                anyDifferent = true
            end
        end
        expect(anyDifferent).toBe(true) -- outward aim varies around the circle
    end)

    test("single rule: one identity frame; releaseTail is the style's max lifetime", function()
        local frames = BurstStyles.pointFrames("kamuro", 4, 12, seqRand({ 0.5 }))
        expect(#frames).toBe(1)
        expect(frames[1].pos[1] == 0 and frames[1].pos[2] == 0 and frames[1].pos[3] == 0).toBe(true)
        expect(BurstStyles.releaseTail("kamuro")).toBe(BurstStyles.STYLES.kamuro.lifetime[2])
        expect(BurstStyles.releaseTail(nil)).toBe(BurstStyles.STYLES.peony.lifetime[2])
    end)

    test("strobe's transparency is a flicker, not a fade", function()
        -- At least 4 falling AND 4 rising edges — a square wave, which is the strobe.
        local t = BurstStyles.STYLES.strobe.transparency
        local rises, falls = 0, 0
        for i = 2, #t do
            if t[i][2] > t[i - 1][2] then
                rises += 1
            elseif t[i][2] < t[i - 1][2] then
                falls += 1
            end
        end
        expect(rises >= 4 and falls >= 4).toBe(true)
    end)

    test("MAX_POINTS is 8 — the pool's per-slot break-part count", function()
        expect(BurstStyles.MAX_POINTS).toBe(8)
    end)
end)
```

- [ ] **Step 2: Run to verify failure** — `lune run tests/run`, FAIL: module not found.
- [ ] **Step 3: Implement** `BurstStyles.luau` per the Interfaces block (all values above verbatim; `pointFrames` clamps n to `MAX_POINTS`; `circle`'s outward pitch is 35° off vertical toward each arm's outward XZ direction — any Euler encoding passing the spec is acceptable).
- [ ] **Step 4: Verify green** — `lune run tests/run`.
- [ ] **Step 5: Lint + commit**

```bash
stylua --check src tests tools && selene src tools
git add src/shared/BurstStyles.luau tests/BurstStyles.spec.luau
git commit -m "feat(fireworks): BurstStyles -- five complete styles, point rules, role tables"
```

---

### Task 2: Schema — style membership and staged-field validation

**Files:**
- Modify: `roblox/src/shared/FireworkRecipes.luau`
- Test: `roblox/tests/FireworkRecipes.spec.luau` (extend)

**Interfaces:**
- Consumes: `BurstStyles.STYLES`, `BurstStyles.MAX_POINTS` (Task 1).
- Produces: `validate` additionally rejects: unknown `style`; `style`/`points`/`scatter`/`share` on non-burst phases; non-integer or out-of-range `points` (1..MAX_POINTS); negative `scatter`; non-positive `share`.

- [ ] **Step 1: Extend the spec** — append to the existing `describe` block in `tests/FireworkRecipes.spec.luau` (reuse its `goodRecipe()` helper):

```lua
    test("a burst may carry a known style; an unknown one fails", function()
        local r = goodRecipe()
        r.phases[3].style = "ring"
        expect(FireworkRecipes.validate(r)).toBe(true)
        r.phases[3].style = "chrysanthemum" -- not a wave-one word
        expect(FireworkRecipes.validate(r)).toBe(false)
    end)

    test("staged fields belong to bursts alone", function()
        for _, field in { "style", "points", "scatter", "share" } do
            local r = goodRecipe()
            ;(r.phases[2] :: any)[field] = if field == "style" then "peony" else 2
            expect(FireworkRecipes.validate(r)).toBe(false)
        end
    end)

    test("points is an integer 1..MAX_POINTS; scatter >= 0; share > 0", function()
        local BurstStyles = require("../src/shared/BurstStyles")
        local cases: { { field: string, value: any, ok: boolean } } = {
            { field = "points", value = 1, ok = true },
            { field = "points", value = BurstStyles.MAX_POINTS, ok = true },
            { field = "points", value = 0, ok = false },
            { field = "points", value = BurstStyles.MAX_POINTS + 1, ok = false },
            { field = "points", value = 2.5, ok = false },
            { field = "scatter", value = 0, ok = true },
            { field = "scatter", value = -1, ok = false },
            { field = "share", value = 0.5, ok = true },
            { field = "share", value = 0, ok = false },
        }
        for _, c in cases do
            local r = goodRecipe()
            ;(r.phases[3] :: any)[c.field] = c.value
            expect(FireworkRecipes.validate(r)).toBe(c.ok)
        end
    end)
```

- [ ] **Step 2: Run to verify failure** — the style test fails (unknown style currently passes).
- [ ] **Step 3: Implement** — in `FireworkRecipes.luau`: `local BurstStyles = require("./BurstStyles")` (string require, sibling path, matches the nine existing relative requires in src/shared). In the phase loop add:

```lua
        local staged = { style = ph.style, points = ph.points, scatter = ph.scatter, share = ph.share }
        if ph.kind ~= "burst" then
            for field, v in staged do
                if v ~= nil then
                    return false, `phase {i}: '{field}' is a burst field`
                end
            end
        else
            if ph.style ~= nil and BurstStyles.STYLES[ph.style] == nil then
                return false, `phase {i}: unknown style '{tostring(ph.style)}'`
            end
            if ph.points ~= nil then
                if typeof(ph.points) ~= "number" or ph.points % 1 ~= 0 or ph.points < 1 or ph.points > BurstStyles.MAX_POINTS then
                    return false, `phase {i}: points must be an integer 1..{BurstStyles.MAX_POINTS}`
                end
            end
            if ph.scatter ~= nil and (typeof(ph.scatter) ~= "number" or ph.scatter < 0) then
                return false, `phase {i}: scatter must be a non-negative number`
            end
            if ph.share ~= nil and (typeof(ph.share) ~= "number" or ph.share <= 0) then
                return false, `phase {i}: share must be a positive number`
            end
        end
```

- [ ] **Step 4: Verify green** — full suite (drafts and catalog must still validate).
- [ ] **Step 5: Lint + commit**

```bash
stylua --check src tests tools && selene src tools
git add src/shared/FireworkRecipes.luau tests/FireworkRecipes.spec.luau
git commit -m "feat(fireworks): schema learns style membership and validates the staged fields"
```

---

### Task 3: Schedule passthrough + budget invariance

**Files:**
- Modify: `roblox/src/shared/FireworkSchedule.luau` (types + one copy line)
- Test: `roblox/tests/FireworkSchedule.spec.luau` (extend)

**Interfaces:**
- Consumes: nothing new.
- Produces: `Event.style: string?` — copied verbatim from the phase. **No budget logic changes of any kind.**

- [ ] **Step 1: Extend the spec** — append to `tests/FireworkSchedule.spec.luau`'s describe block:

```lua
    test("style passes through compile untouched", function()
        local recipe = {
            phases = {
                { at = 0, kind = "burst", anchor = "apex", style = "ring", texture = "t" },
            },
        }
        local events = FireworkSchedule.compile(recipe :: any, 300)
        expect(events[1].style).toBe("ring")
    end)

    test("A STYLE NEVER TOUCHES COST: particle totals identical with styles stripped", function()
        local styled = {
            phases = {
                { at = 0, kind = "report", anchor = "origin" },
                { at = 0.02, kind = "ascent", anchor = "origin" },
                { at = 1.0, kind = "burst", anchor = "apex", style = "ring", share = 2, texture = "t" },
                { at = 1.5, kind = "burst", anchor = "apex", style = "strobe", points = 5, scatter = 8, share = 1, texture = "t" },
                { at = 2.0, kind = "burst", anchor = "apex", style = "kamuro", share = 1, texture = "t" },
            },
        }
        local stripped = { phases = {} }
        for _, ph in styled.phases do
            local copy = table.clone(ph)
            copy.style = nil
            table.insert(stripped.phases, copy)
        end
        for _, budget in { 60, 300, 700 } do
            local a = FireworkSchedule.compile(styled :: any, budget)
            local b = FireworkSchedule.compile(stripped :: any, budget)
            local ta, tb = 0, 0
            for _, ev in a do
                ta += ev.particles * ev.points
            end
            for _, ev in b do
                tb += ev.particles * ev.points
            end
            expect(ta).toBe(tb)
        end
    end)
```

- [ ] **Step 2: Run to verify failure** — passthrough test fails (`style` is nil on the event).
- [ ] **Step 3: Implement** — add `style: string?` to both the `Phase` and `Event` export types and `style = ph.style,` to the event constructor table. Nothing else.
- [ ] **Step 4: Verify green.**
- [ ] **Step 5: Lint + commit**

```bash
stylua --check src tests tools && selene src tools
git add src/shared/FireworkSchedule.luau tests/FireworkSchedule.spec.luau
git commit -m "feat(fireworks): schedule passes style through -- budget logic untouched, invariance test-pinned"
```

---

### Task 4: Controller — glow stack, style application, style-aware release

**Files:**
- Modify: `roblox/src/client/FireworkController.client.luau`

**Interfaces:**
- Consumes: `BurstStyles.styleOf/pointFrames/releaseTail/TEXTURES/SOUNDS/MAX_POINTS`, `Event.style` (Tasks 1, 3).
- Produces: the rendered vocabulary. No unit tests (client file, by design); every decision consumed here is already spec'd in Task 1.

Behavior contract (the implementer writes the code; the file is ~250 lines and familiar patterns):

1. **Require** `BurstStyles` beside the other shared requires. Replace the local `MAX_POINTS = 8` with `local MAX_POINTS = BurstStyles.MAX_POINTS`.
2. **Pool creation — the glow stack + de-hardcoding**: every pooled emitter gains `em.LightInfluence = 0` (spec §7: default 1 lets scene light DIM the stars, worst at night). REMOVE the pool-level `SpreadAngle`, `Drag` and `Transparency` writes added in `adaa1fe` (and their comment block): those values are now peony's row in BurstStyles and are applied per emit — a comment at the pool notes that per-style application supersedes them and why the pool sets only invariants (`LightEmission = 1`, `LightInfluence = 0`, `Rate = 0`, `Enabled = false`).
3. **`fireBurst` becomes style-driven**: resolve `local style = BurstStyles.styleOf(ev.style)`. Build frames once per burst: `local frames = BurstStyles.pointFrames(ev.style, math.min(ev.points, MAX_POINTS), ev.scatter, function() return rng:NextNumber() end)` — the shell's seeded `rng` is the rand source, so every client computes identical frames. For each frame i (iterate `#frames`, NOT `ev.points` — ring/kamuro collapse to one frame): position AND orient the point part (`p.CFrame = CFrame.new(anchorPos + Vector3.new(f.pos[1], f.pos[2], f.pos[3])) * CFrame.Angles(math.rad(f.rot[1]), math.rad(f.rot[2]), math.rad(f.rot[3]))`), then write the FULL applied set on its emitter:
   - `Texture` = `ev.texture or BurstStyles.TEXTURES[style.textureRole]` (recipe texture still wins, so existing catalog shells render unchanged),
   - `Color` from `ev.color`/`ev.edgeColor` as today, `Size` from `ev.spread` as today,
   - `Speed = NumberRange.new(style.speed[1], style.speed[2])`, `Drag = style.drag`,
   - `Lifetime = NumberRange.new(style.lifetime[1], style.lifetime[2])`,
   - `Brightness = style.brightness`,
   - `SpreadAngle = Vector2.new(style.spreadAngle[1], style.spreadAngle[2])`,
   - `Acceleration`: `Vector3.new(unpack style.acceleration)`, except `ev.droop == true` keeps overriding to `(0, -28, 0)` (existing recipe field stays meaningful),
   - `Transparency = NumberSequence.new(keypoints from style.transparency)` (build the `NumberSequenceKeypoint` list in a small helper, cached per style table identity so it isn't rebuilt every emit),
   - then `em:Emit(ev.particles)` — **budget untouched**: particles-per-point comes from the schedule exactly as before. When `#frames < ev.points` (ring/kamuro), emit `ev.particles * ev.points` from the single frame so the shell's total cost is IDENTICAL to its scheduled cost, never more.
4. **Style-aware slot release**: replace `task.delay(last + 2.6, …)` — compute `local tail = 0` while walking the schedule: for each burst event `tail = math.max(tail, BurstStyles.releaseTail(ev.style))`; release at `last + tail + 0.2`. (Kamuro's 4.2s crown must not have its slot's parts re-positioned under it mid-hang.)
5. **Sounds unchanged this task** — `playSound` still uses the recipe's per-phase `sound` field; role-based sound defaults land with the audio wiring (Task 8), keeping this diff reviewable.

- [ ] **Step 1: Implement** per the contract.
- [ ] **Step 2: Verify** — `stylua --check src tests tools && selene src tools && lune run tests/run` (suite guards the shared modules; the controller is judged at the range).
- [ ] **Step 3: Commit**

```bash
git add src/client/FireworkController.client.luau
git commit -m "feat(fireworks): controller renders styles -- glow stack, point frames, style-aware slot release"
```

---

### Task 5: Sprite textures — the dot and the streak

**Files:**
- Create: `roblox/tools/textures/make_firework_sprites.py`
- Create (generated, committed): `roblox/tools/textures/firework_dot.png`, `roblox/tools/textures/firework_streak.png`

**Interfaces:**
- Consumes: nothing. Produces: two 256×256 RGBA PNGs the owner uploads; ids then replace `BurstStyles.TEXTURES` stand-ins (owner-in-loop, Task 8).

- [ ] **Step 1: Write the generator** — `make_firework_sprites.py`, numpy + PIL, deterministic (no RNG), docstring stating both outputs are committed and regenerating must be byte-stable:

```python
"""Generate the two firework particle sprites (256x256 RGBA, premult-friendly).

dot:    a crisp round core -- solid white center, tight radial falloff
        (alpha = clamp01(1.6 - 1.6*r)^2.2 inside r<1, 0 outside; r normalized
        to 0..1 at 40% of the half-width so the core is small and HARD, the
        opposite of the engine's fuzzy sparkle).
streak: a vertical streak -- alpha = (1 - |x|)^3 * (1 - |y|)^1.2 on a tall
        gaussian-ish lobe occupying the middle 20% horizontally, full height,
        brightest 25% from the top so the motion reads downward.

Both pure white; ALL color comes from the emitter's Color/Brightness, so one
sprite serves every shell. Deterministic: same bytes every run (PIL, no
timestamps -- save with optimize=False).
Run from roblox/:  python3 tools/textures/make_firework_sprites.py
"""
```

The implementation is ~40 lines of numpy grid math per the formulas in the docstring, `Image.fromarray(..., "RGBA").save(path, optimize=False)`.

- [ ] **Step 2: Run it** — `python3 tools/textures/make_firework_sprites.py`; confirm both PNGs exist, each under 100 KB; run it TWICE and `shasum` both runs' outputs to prove byte-stability.
- [ ] **Step 3: Commit**

```bash
git add tools/textures/make_firework_sprites.py tools/textures/firework_dot.png tools/textures/firework_streak.png
git commit -m "feat(fireworks): sprite generator -- crisp dot and streak, owner uploads pending"
```

---

### Task 6: Seed draft families

**Files:**
- Modify: `roblox/src/shared/FireworkDrafts.luau`
- Test: `roblox/tests/FireworkDrafts.spec.luau` must stay green UNCHANGED (its schema test now runs the stricter Task-2 validation over every new draft — that's the point).

**Interfaces:**
- Consumes: recipe format + `style`/`points`/`scatter`/`share` fields (Tasks 2, 3).
- Produces: families `wa`, `yashi`, `hotaru`, `kamuro`, `dan` (plus existing `kiku` retained). Range-provable immediately.

Author with the existing `SPARKLE`/sound constants in the file (per-style texture/sound defaults come from BurstStyles at render, so drafts may omit `texture`… **no**: the schema REQUIRES a burst texture (blank-sky rule). Drafts keep naming `SPARKLE` explicitly; the role-table default is the controller's fallback only.)

Exact families (each `at` chain report → ascent → burst(s), following the file's `kiku` idiom; colors saturated per spec §7):

- `wa` (輪 ring): burst `style="ring"`, core `{255, 60, 40}` edge `{255, 240, 220}`; v1/v2/v3 ladder `spread` 30/42/56.
- `yashi` (椰子 palm): burst `style="palm"`, `points` 4/5/6 across v1/v2/v3, `scatter=6`, gold core `{255, 180, 60}` edge `{255, 230, 160}`.
- `hotaru` (蛍 strobe): burst `style="strobe"`, silver-white `{235, 245, 255}` edge `{180, 220, 255}`; v1/v2/v3 ladder `spread` 24/36/48.
- `kamuro`: burst `style="kamuro"`, deep gold `{255, 170, 40}` edge `{255, 220, 140}`; v1/v2/v3 ladder burst `at` 1.1/1.25/1.4 (hang height read).
- `dan` (段 staged demo): ONE variant `v1`, three burst phases — `at=1.1` peony (implicit style) `share=2`; `at=1.7` `style="strobe"`, `points=5`, `scatter=9`, `share=1`; `at=2.6` `style="kamuro"`, `share=1`. Exists to exercise `points/scatter/share` and prove styles compose.

- [ ] **Step 1: Author the families** (kiku stays; comment each family with its kanji + one line on what its ladder varies).
- [ ] **Step 2: Verify** — `lune run tests/run`: the drafts spec's "EVERY DRAFT PASSES THE SCHEMA" test now covers all six families under the stricter schema; all green.
- [ ] **Step 3: Lint + commit**

```bash
stylua --check src tests tools && selene src tools
git add src/shared/FireworkDrafts.luau
git commit -m "feat(fireworks): seed families for every style plus dan, the staged demo"
```

---

### Task 7: Audio survey tool

**Files:**
- Create: `roblox/tools/audio/survey_fireworks.py`

**Interfaces:**
- Consumes: `~/Desktop/Roshambo Reference/sound/fireworks/` (READ-ONLY — 65 wav, 18 zip, 4 stragglers; names untrusted).
- Produces: `fireworks_expanded/` sibling dir (zip contents) and `fireworks_manifest.csv` beside it; a `--selftest` mode proving the classifier on synthetic signals.

Follow `measure_caws.py`'s conventions: self-contained, numpy only for wav; a top docstring carrying the WHY (names untrusted → measurement-driven). Structure:

```python
"""Survey the owner's fireworks recordings: expand, measure, propose categories.

THE FILENAMES ARE NOT TRUSTED (owner, 2026-09-02). Every file is classified from
measurement: duration, peak/RMS dBFS, spectral centroid, low-band (<250Hz) energy
ratio, and onset density. Categories proposed:
  report   -- short (<1.5s), low-heavy (low_ratio > 0.5), single onset
  whistle  -- tonal (centroid 800-4000Hz, low_ratio < 0.2), sustained
  burst    -- boom onset + broadband tail, 1-6s
  crackle  -- dense onsets (>8/s), broadband, low_ratio < 0.35
  ambience -- long (>15s) without dominant onsets
  reject   -- clipped (peak >= -0.1 dBFS for >1% of samples), or <0.2s, or unreadable
Non-wav inputs (mp3/ogg/flac/aiff) are decoded via ffmpeg when present, else rowed
as 'unreadable' rather than skipped silently.

Usage (from roblox/):
  python3 tools/audio/survey_fireworks.py "~/Desktop/Roshambo Reference/sound/fireworks"
  python3 tools/audio/survey_fireworks.py --selftest
Writes: <parent>/fireworks_expanded/ (zips, idempotent -- skip if present) and
        <parent>/fireworks_manifest.csv (file, seconds, peak_db, rms_db,
        centroid_hz, low_ratio, onsets_per_s, category, note)
The reference dir itself is never written to.
"""
```

Classifier is one pure function `classify(duration, peak_db, centroid, low_ratio, onsets_per_s, clipped_frac) -> (category, note)` so `--selftest` can drive it with synthetic values: a 0.8s low-heavy single-onset row → `report`; a 3s tonal row → `whistle`; a 25s low-onset row → `ambience`; a clipped row → `reject`; a dense-onset broadband row → `crackle`. Selftest exits nonzero on any mismatch.

- [ ] **Step 1: Write the tool** per the docstring (wav reader may be adapted from `measure_caws.py`'s — note the adaptation in a comment).
- [ ] **Step 2: `python3 tools/audio/survey_fireworks.py --selftest`** — passes.
- [ ] **Step 3: Run the real survey** — expands 18 zips, writes the manifest; spot-check: row count ≥ 69 (65 wav + 4 stragglers) plus zip contents; no writes inside `fireworks/` itself (`ls -la` timestamps unchanged).
- [ ] **Step 4: Commit the tool** (never the expanded audio or the manifest — they live outside the repo):

```bash
git add tools/audio/survey_fireworks.py
git commit -m "feat(fireworks): audio survey -- measurement-driven triage of the untrusted recordings"
```

---

### Task 8: Uploads, wiring, range gate — MAIN SESSION ONLY (owner-in-loop)

**Do not dispatch this task to a subagent.** It needs the owner (uploads, ears, eyes) and the connected Studio session.

**Files:**
- Modify: `roblox/src/shared/BurstStyles.luau` (TEXTURES/SOUNDS ids), `docs/wiki/world/fireworks.md`, `docs/wiki/log.md`

- [ ] **Step 1: Textures up.** Owner uploads `firework_dot.png` / `firework_streak.png` (Studio → Asset Manager); ids land in `BurstStyles.TEXTURES`; suite + lint; commit.
- [ ] **Step 2: Audio shortlist.** From the manifest, build per-category shortlists (best ~5 each of report/whistle/burst/crackle by measurement quality: unclipped, clean RMS, sensible duration). Owner auditions locally (files, not Roblox). Chosen takes get cut/normalized (bandpass + ONE COMMON GAIN across the whole set, birdcall-cutter discipline) into composite burst clips per style — peony boom, strobe boom→crackle, kamuro boom→sizzle — plus one report and one ascent whistle.
- [ ] **Step 3: Audio up.** Owner uploads the cuts; ids into `BurstStyles.SOUNDS`; drafts' phase `sound` fields switch to the role defaults where the controller applies them (this is where Task 4's deferred sound-role wiring lands: `playSound` falls back to `BurstStyles.SOUNDS[style.soundRole]` when the phase names no sound); suite + lint; commit.
- [ ] **Step 4: Range gate.** Rojo synced, owner in Play at FallsLanding, night on: ladder every family (`wa`, `yashi`, `hotaru`, `kamuro`), fire `dan` solo, fire `kiku` (regression: peony pathway with new glow), one shipped shell (catalog untouched check). Judging: style distinctness at 190 studs, glow ("vibrant, sparkly, colorful"), stage timing on `dan`, audio in the canyon. Fix rounds as the owner calls them; ladder constants in BurstStyles/drafts are the tuning knobs.
- [ ] **Step 5: Record + commit.** `fireworks.md` As-built gains the vocabulary paragraph; `log.md` gets the gate entry; commit docs.

---

## Self-Review (performed at write time)

- **Spec coverage:** §1 BurstStyles → T1; §2 schema → T2; §3 controller (incl. style-aware release) → T4; §4 textures → T5 + T8; §5 seed drafts → T6; §6 tests → T1/T2/T3 (+drafts re-validation in T6); §7 glow stack → T4 (LightInfluence, Brightness via T1 values, saturated colors in T6); §8 audio → T7 + T8. Staged machinery exercised → T6 (`dan`) + T2 validation + T3 invariance.
- **Placeholder scan:** T1's `circle` rot formula deliberately pins the observable (outward aim varies, radius exact) over the Euler encoding, with the spec test as the contract — not a TBD. T4 is a behavior contract like the proving plan's panel task (precedent: worked, reviewed clean). T5's formulas are in the docstring.
- **Type consistency:** `styleOf/pointFrames/releaseTail/TEXTURES/SOUNDS/MAX_POINTS/STYLES/APPLIED` names match across T1 (defines), T2 (STYLES, MAX_POINTS), T3 (`Event.style`), T4 (all), T8 (TEXTURES/SOUNDS). `Frame.pos/rot` arrays used identically in T1 tests and T4 contract.
- **Known interaction:** T4 removes the `adaa1fe` pool hardcode — peony's T1 row carries those exact values, so shipped shells render identically-or-better; T6's `kiku` regression fire at the gate confirms it.
