# Square Canopy Foliage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the square-viewshed canopy tree layer — hand-placed hero maples/pines + a deterministic conifer-mass scatter — from clean-sourced Creator Store assets.

**Architecture:** A pure Lune-tested placement module (`tools/builders/CanopyScatter.luau`) does all decidable math; two Studio tools (hero survey place/bake + mass-scatter shell) mirror/consume it and stamp place-only clones under `CanyonWorld.Foliage`. Species templates live place-only in `ServerStorage.FoliageKit`, curated interactively from the Creator Store with a mandatory backdoor scan.

**Tech Stack:** Luau (strict), Lune test harness (`roblox/tests/harness.luau`), Roblox Studio MCP (`execute_luau`, `search_asset`, `insert_asset`, `screen_capture`), stylua + selene.

**Spec:** `docs/superpowers/specs/2026-07-25-square-canopy-foliage-design.md`

## Global Constraints

- All Luau files `--!strict`; format+lint must pass CI scope: `stylua --check src tests tools && selene src tools` (selene fails on warnings).
- Pure modules: NO `math.random`, NO `os.clock`/dates — integer LCG only (arch-portable; see `tools/builders/FoliageScatter.luau`).
- Lune tests: `cd roblox && lune run tests/run` — all green before any commit.
- Studio tools do not `require` across files at runtime — they MIRROR the pure module inline with a `>>> MIRRORED from tools/builders/CanopyScatter.luau — KEEP IN SYNC <<<` banner (repo convention, cf. `buildIshidanStairs.luau`).
- MANDATORY flags on every stamped clone part: `RenderFidelity=Automatic`, `CastShadow=false`, `CanCollide=false`, `CanQuery=false`, `CanTouch=false`; strip all `BillboardGui`s.
- Foliage clones are PLACE-ONLY under `workspace.CanyonWorld.Foliage` (never RoshamboStage; never committed as models). Kit templates place-only in `ServerStorage.FoliageKit`.
- Every Creator Store import is backdoor-scanned BEFORE it may stay in the place (Task 2 Step 3 scan script); rejects deleted immediately.
- Studio MCP: `execute_luau` needs `return`; camera screenshots must reset `CameraType=Custom` after (see memories).
- Compass: −Z = North, +Z = South, X runs east–west. World origin = clearing centre. Falls pool is upstream at −X; river flows +X.
- One visual attempt then STOP and ask the user to look (standing rule). Never self-judge and iterate unprompted.
- Interactive gates (kit picks, hero walk, mass walk, phone bench) are USER gates — the plan pauses there; they cannot be subagent-approved.

---

### Task 1: `CanopyScatter` pure placement module (TDD)

**Files:**
- Create: `roblox/tools/builders/CanopyScatter.luau`
- Test: `roblox/tests/CanopyScatter.spec.luau`

**Interfaces:**
- Consumes: nothing (pure; self-contained LCG).
- Produces (used by Task 4's mirror and shell):

```lua
export type Sample = { x: number, z: number, y: number, steep: number } -- steep = 1 - surfaceNormal.Y
export type Placement = {
    x: number, z: number, y: number,
    species: string,
    yaw: number,   -- radians [0, 2π)
    scale: number, -- 1 ± cfg.scaleJitter
    tint: number,  -- 1 ± cfg.tintJitter (brightness multiplier)
}
export type Config = {
    yMin: number, yMax: number,       -- plantable altitude band
    maxSteep: number,                 -- reject samples steeper than this
    spacing: number,                  -- min distance between accepted placements
    spacingJitter: number,            -- extra [0, jitter) added per acceptance
    rects: { { number } },            -- keep-out {xMin, zMin, xMax, zMax}
    circles: { { number } },          -- keep-out {x, z, r}
    waterCells: { { number } },       -- {x, z} water cell centres
    waterMargin: number,              -- min distance from any water cell
    conifers: { { name: string, weight: number } },
    broadleaf: { name: string, weight: number }?,
    heroMix: { { number } },          -- {x, z} hero centres
    heroMixRadius: number,            -- broadleaf mixes in within this radius
    keepLowY: number?,                -- density ramp: keep fraction at yMin (default 1)
    scaleJitter: number,
    tintJitter: number,
}
CanopyScatter.plan(samples: { Sample }, cfg: Config, seed: number) -> { Placement }
```

Algorithm (all deterministic): sort samples by (x, z); for each sample run filters (y band → steepness → rects → circles → water margin → altitude density ramp via LCG keep-roll); greedy min-spacing acceptance against already-accepted placements (`spacing + jitterRoll`); species pick by LCG-weighted choice — within `heroMixRadius` of any `heroMix` centre the pool is conifers ∪ broadleaf, else conifers only; then yaw/scale/tint rolls.

- [ ] **Step 1: Write the failing test file**

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local CanopyScatter = require("../tools/builders/CanopyScatter")

local CONIFERS = { { name = "ConiferA", weight = 3 }, { name = "ConiferB", weight = 1 } }

local function baseCfg(): CanopyScatter.Config
    return {
        yMin = 10,
        yMax = 100,
        maxSteep = 0.5,
        spacing = 5,
        spacingJitter = 0,
        rects = {},
        circles = {},
        waterCells = {},
        waterMargin = 6,
        conifers = CONIFERS,
        broadleaf = nil,
        heroMix = {},
        heroMixRadius = 40,
        keepLowY = nil,
        scaleJitter = 0.2,
        tintJitter = 0.1,
    }
end

local function sample(x: number, z: number, y: number, steep: number?): CanopyScatter.Sample
    return { x = x, z = z, y = y, steep = steep or 0.2 }
end

describe("CanopyScatter.plan filters", function()
    test("rejects samples outside the altitude band", function()
        local out = CanopyScatter.plan({ sample(0, 0, 5), sample(20, 0, 105), sample(40, 0, 50) }, baseCfg(), 1)
        expect(#out).toBe(1)
        expect(out[1].x).toBe(40)
    end)
    test("rejects samples steeper than maxSteep", function()
        local out = CanopyScatter.plan({ sample(0, 0, 50, 0.9), sample(20, 0, 50, 0.3) }, baseCfg(), 1)
        expect(#out).toBe(1)
        expect(out[1].x).toBe(20)
    end)
    test("rejects samples inside a keep-out rect", function()
        local cfg = baseCfg()
        cfg.rects = { { -10, -10, 10, 10 } }
        local out = CanopyScatter.plan({ sample(0, 0, 50), sample(30, 0, 50) }, cfg, 1)
        expect(#out).toBe(1)
        expect(out[1].x).toBe(30)
    end)
    test("rejects samples inside a keep-out circle", function()
        local cfg = baseCfg()
        cfg.circles = { { 0, 0, 12 } }
        local out = CanopyScatter.plan({ sample(4, 4, 50), sample(30, 0, 50) }, cfg, 1)
        expect(#out).toBe(1)
        expect(out[1].x).toBe(30)
    end)
    test("rejects samples within waterMargin of a water cell", function()
        local cfg = baseCfg()
        cfg.waterCells = { { 0, 0 } }
        local out = CanopyScatter.plan({ sample(3, 0, 50), sample(30, 0, 50) }, cfg, 1)
        expect(#out).toBe(1)
        expect(out[1].x).toBe(30)
    end)
end)

describe("CanopyScatter.plan spacing", function()
    test("enforces min spacing between accepted placements", function()
        local out = CanopyScatter.plan({ sample(0, 0, 50), sample(3, 0, 50), sample(20, 0, 50) }, baseCfg(), 1)
        expect(#out).toBe(2) -- the 3-stud neighbour of the first accept is rejected
    end)
end)

describe("CanopyScatter.plan determinism", function()
    local FIELD = {}
    for i = 0, 9 do
        for j = 0, 9 do
            table.insert(FIELD, sample(i * 8, j * 8, 50))
        end
    end
    test("same seed reproduces the identical plan", function()
        local a = CanopyScatter.plan(FIELD, baseCfg(), 42)
        local b = CanopyScatter.plan(FIELD, baseCfg(), 42)
        expect(a).toEqual(b)
    end)
    test("different seeds differ", function()
        local a = CanopyScatter.plan(FIELD, baseCfg(), 42)
        local b = CanopyScatter.plan(FIELD, baseCfg(), 43)
        local differs = #a ~= #b
        if not differs then
            for i, p in a do
                if p.yaw ~= b[i].yaw or p.species ~= b[i].species then
                    differs = true
                    break
                end
            end
        end
        expect(differs).toBe(true)
    end)
    test("rolls stay in range", function()
        local out = CanopyScatter.plan(FIELD, baseCfg(), 7)
        expect(#out > 10).toBe(true)
        for _, p in out do
            expect(p.yaw >= 0 and p.yaw < 2 * math.pi).toBe(true)
            expect(p.scale >= 0.8 and p.scale <= 1.2).toBe(true)
            expect(p.tint >= 0.9 and p.tint <= 1.1).toBe(true)
            expect(p.y).toBe(50)
        end
    end)
end)

describe("CanopyScatter.plan species", function()
    test("mixes broadleaf only near hero centres", function()
        local cfg = baseCfg()
        cfg.broadleaf = { name = "BroadleafMid", weight = 1000 } -- overwhelm conifer weights
        cfg.heroMix = { { 0, 0 } }
        cfg.heroMixRadius = 15
        local nearOut = CanopyScatter.plan({ sample(6, 0, 50) }, cfg, 5)
        expect(nearOut[1].species).toBe("BroadleafMid")
        local farOut = CanopyScatter.plan({ sample(60, 0, 50) }, cfg, 5)
        expect(farOut[1].species == "ConiferA" or farOut[1].species == "ConiferB").toBe(true)
    end)
    test("respects conifer weights deterministically", function()
        local out = CanopyScatter.plan(
            (function()
                local f = {}
                for i = 0, 19 do
                    for j = 0, 19 do
                        table.insert(f, sample(i * 8, j * 8, 50))
                    end
                end
                return f
            end)(),
            baseCfg(),
            9
        )
        local counts = { ConiferA = 0, ConiferB = 0 }
        for _, p in out do
            counts[p.species] += 1
        end
        expect(counts.ConiferA > counts.ConiferB).toBe(true) -- weight 3 vs 1
    end)
end)

describe("CanopyScatter.plan density ramp", function()
    test("keepLowY=0 drops everything at yMin and keeps at yMax", function()
        local cfg = baseCfg()
        cfg.keepLowY = 0
        cfg.spacing = 0.5
        local lows, highs = {}, {}
        for i = 0, 19 do
            table.insert(lows, sample(i * 8, 0, 10))
            table.insert(highs, sample(i * 8, 40, 100))
        end
        local lowOut = CanopyScatter.plan(lows, cfg, 3)
        local highOut = CanopyScatter.plan(highs, cfg, 3)
        expect(#lowOut).toBe(0)
        expect(#highOut).toBe(20)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `CanopyScatter` module not found.

- [ ] **Step 3: Implement the module**

```lua
--!strict
-- Deterministic canopy placement for the square-viewshed foliage pass (spec
-- 2026-07-25-square-canopy-foliage-design). Pure: terrain samples + config +
-- seed → placement list. The Studio shell (tools/studio/scatterCanopy.luau)
-- MIRRORS this file — keep in sync. LCG (no math.random) so re-runs reproduce
-- the identical forest and gate iteration is parameter edits, not lost state.
local CanopyScatter = {}

export type Sample = { x: number, z: number, y: number, steep: number }
export type Placement = {
    x: number,
    z: number,
    y: number,
    species: string,
    yaw: number,
    scale: number,
    tint: number,
}
export type Config = {
    yMin: number,
    yMax: number,
    maxSteep: number,
    spacing: number,
    spacingJitter: number,
    rects: { { number } },
    circles: { { number } },
    waterCells: { { number } },
    waterMargin: number,
    conifers: { { name: string, weight: number } },
    broadleaf: { name: string, weight: number }?,
    heroMix: { { number } },
    heroMixRadius: number,
    keepLowY: number?,
    scaleJitter: number,
    tintJitter: number,
}

local function lcg(state: number): (number, number)
    state = (1103515245 * state + 12345) % 2147483648
    return state, state / 2147483648
end

local function inRect(x: number, z: number, r: { number }): boolean
    return x >= r[1] and z >= r[2] and x <= r[3] and z <= r[4]
end

local function nearPoint(x: number, z: number, px: number, pz: number, d: number): boolean
    local dx, dz = x - px, z - pz
    return dx * dx + dz * dz <= d * d
end

local function pickSpecies(
    pool: { { name: string, weight: number } },
    roll: number
): string
    local total = 0
    for _, s in pool do
        total += s.weight
    end
    local at = roll * total
    for _, s in pool do
        at -= s.weight
        if at <= 0 then
            return s.name
        end
    end
    return pool[#pool].name
end

function CanopyScatter.plan(samples: { Sample }, cfg: Config, seed: number): { Placement }
    local ordered = table.clone(samples)
    table.sort(ordered, function(a, b)
        if a.x ~= b.x then
            return a.x < b.x
        end
        return a.z < b.z
    end)

    local state = (seed * 2654435761) % 2147483648 + 1
    local out: { Placement } = {}

    for _, s in ordered do
        if s.y < cfg.yMin or s.y > cfg.yMax then
            continue
        end
        if s.steep > cfg.maxSteep then
            continue
        end
        local excluded = false
        for _, r in cfg.rects do
            if inRect(s.x, s.z, r) then
                excluded = true
                break
            end
        end
        if not excluded then
            for _, c in cfg.circles do
                if nearPoint(s.x, s.z, c[1], c[2], c[3]) then
                    excluded = true
                    break
                end
            end
        end
        if not excluded then
            for _, w in cfg.waterCells do
                if nearPoint(s.x, s.z, w[1], w[2], cfg.waterMargin) then
                    excluded = true
                    break
                end
            end
        end
        if excluded then
            continue
        end

        -- altitude density ramp: keep probability lerps keepLowY → 1 across the band
        if cfg.keepLowY ~= nil then
            local t = (s.y - cfg.yMin) / math.max(cfg.yMax - cfg.yMin, 1e-6)
            local keep = cfg.keepLowY + (1 - cfg.keepLowY) * t
            local roll
            state, roll = lcg(state)
            if roll > keep then
                continue
            end
        end

        -- greedy min-spacing against accepted placements
        local spacingRoll
        state, spacingRoll = lcg(state)
        local minD = cfg.spacing + spacingRoll * cfg.spacingJitter
        local tooClose = false
        for _, p in out do
            if nearPoint(s.x, s.z, p.x, p.z, minD) then
                tooClose = true
                break
            end
        end
        if tooClose then
            continue
        end

        -- species: broadleaf joins the pool near hero centres
        local pool = cfg.conifers
        if cfg.broadleaf ~= nil then
            for _, h in cfg.heroMix do
                if nearPoint(s.x, s.z, h[1], h[2], cfg.heroMixRadius) then
                    pool = table.clone(cfg.conifers)
                    table.insert(pool, cfg.broadleaf :: { name: string, weight: number })
                    break
                end
            end
        end
        local speciesRoll, yawRoll, scaleRoll, tintRoll
        state, speciesRoll = lcg(state)
        state, yawRoll = lcg(state)
        state, scaleRoll = lcg(state)
        state, tintRoll = lcg(state)
        table.insert(out, {
            x = s.x,
            z = s.z,
            y = s.y,
            species = pickSpecies(pool, speciesRoll),
            yaw = yawRoll * 2 * math.pi,
            scale = 1 + (scaleRoll * 2 - 1) * cfg.scaleJitter,
            tint = 1 + (tintRoll * 2 - 1) * cfg.tintJitter,
        })
    end
    return out
end

return CanopyScatter
```

- [ ] **Step 4: Run tests until green**

Run: `cd roblox && lune run tests/run`
Expected: all suites PASS (new CanopyScatter tests + no regressions).

- [ ] **Step 5: Lint + commit**

```bash
cd roblox && stylua --check src tests tools && selene src tools
git add roblox/tools/builders/CanopyScatter.luau roblox/tests/CanopyScatter.spec.luau
git commit -m "feat(roblox): CanopyScatter — deterministic canopy placement core (Lune-tested)"
```

---

### Task 2: Species kit curation (interactive; USER GATE)

**Files:** none committed (kit is place-only in `ServerStorage.FoliageKit`). Chosen asset IDs are recorded in Task 3/4 CONFIGs.

**Interfaces:**
- Produces: `ServerStorage.FoliageKit` containing templates named exactly:
  `ConiferA`, `ConiferB`, `ConiferC` (optional third), `MapleRed`, `MapleGold`,
  `PineNiwaki`, `BroadleafMid`, `BlushAccent`. Each template is a Model (or single
  MeshPart) whose pivot sits at its trunk base, pre-tinted, flags NOT yet needed
  (stamp time applies them).

- [ ] **Step 1: Create the staging area**

Via MCP `execute_luau` (Edit):

```lua
local ServerStorage = game:GetService("ServerStorage")
for _, n in { "FoliageKitStaging", "FoliageKit" } do
    if not ServerStorage:FindFirstChild(n) then
        local f = Instance.new("Folder")
        f.Name = n
        f.Parent = ServerStorage
    end
end
return "staging ready"
```

- [ ] **Step 2: Search + insert candidates per role**

Use MCP `search_asset` with queries per role (run several, curate best 3–6 candidates each): "pine tree low poly", "cedar tree", "japanese maple red", "maple tree autumn", "bonsai pine niwaki", "sakura cherry blossom tree", "stylized tree low poly". Prefer results from Roblox-official/endorsed packs. `insert_asset` each candidate, then immediately reparent into `ServerStorage.FoliageKitStaging` and pivot to a spaced line (offscreen, e.g. x = i*30, y = 300, z = 800).

- [ ] **Step 3: Backdoor-scan EVERY candidate (mandatory, before anything else)**

Via `execute_luau` (Edit):

```lua
local ServerStorage = game:GetService("ServerStorage")
local staging = ServerStorage.FoliageKitStaging
local findings = {}
for _, m in staging:GetChildren() do
    for _, d in m:GetDescendants() do
        if d:IsA("BaseScript") or d:IsA("ModuleScript") then
            table.insert(findings, m.Name .. " CONTAINS SCRIPT: " .. d:GetFullName())
        end
        -- attr-hidden asset ids (the VibrantNature trick)
        for name, v in d:GetAttributes() do
            if typeof(v) == "number" and v > 1e8 then
                table.insert(findings, m.Name .. " suspicious numeric attr " .. name .. "=" .. v .. " on " .. d:GetFullName())
            end
        end
    end
end
return #findings == 0 and "CLEAN — no scripts, no suspicious attrs" or table.concat(findings, "\n")
```

Any candidate with findings: `Destroy()` it immediately and note the asset ID as rejected. A tree mesh needs NO scripts — zero tolerance.

- [ ] **Step 4: Screenshot the line-up for the user**

Position the Edit camera on the staging line via `screen_capture` with camera args; **reset `workspace.CurrentCamera.CameraType = Enum.CameraType.Custom` afterwards** (memory: camera lock). Present one labeled line-up per role.

- [ ] **Step 5: USER GATE — user picks silhouettes**

STOP. The user picks one winner per role (2–3 for the conifer). Do not proceed on your own judgment.

- [ ] **Step 6: Assemble + tint the kit**

For each winner: rename to its role name, move to `ServerStorage.FoliageKit`, delete the rest of staging. Tint via `SurfaceAppearance.Color` (or `MeshPart.Color` where no SA) — night-first: set `workspace` DayNightLockT attr to 0.75, tune, then check at 0.19. Target palette: conifers deep desaturated green w/ slight blue shift; MapleRed momiji red; MapleGold warm gold; BroadleafMid soft unsaturated green; BlushAccent pale pink. If a baked `TextureID` fights the tint, clear it (texturing recipe). Verify each template's pivot is at trunk base (`model.WorldPivot`); fix with `model.WorldPivot = CFrame.new(basePos)` if not.

- [ ] **Step 7: Record + save**

Record the 6–8 winning asset IDs + tint values in the session notes (they go into Task 3/4 CONFIG comments). Ask the user to SAVE the place (kit is place-state).

---

### Task 3: Hero survey tool + draft composition (USER GATE)

**Files:**
- Create: `roblox/tools/studio/placeCanopyHeroes.luau`

**Interfaces:**
- Consumes: `ServerStorage.FoliageKit` templates (Task 2 names).
- Produces: `workspace.CanyonWorld.Foliage.Heroes` clones, each with attributes
  `Species: string`, `BaseScale: number`; bake mode prints the CONFIG literal.
  Task 4 reads hero pivots for `heroMix`/`circles`.

- [ ] **Step 1: Write the tool**

```lua
--!strict
-- placeCanopyHeroes.luau — survey place/bake for the square-viewshed HERO trees
-- (spec 2026-07-25-square-canopy-foliage-design §2). Run via MCP execute_luau
-- (Edit). MODE="place" stamps draggable kit clones from CONFIG (raycast-grounded,
-- engine flags on); drag/swap/delete/duplicate in Studio, then MODE="bake" prints
-- the CONFIG literal back from the live folder — paste it over CONFIG below so
-- the composition is reproducible. Clones are PLACE-ONLY (CanyonWorld.Foliage).
local ServerStorage = game:GetService("ServerStorage")

local MODE = "place" -- "place" | "bake"

-- Draft composition (world x/z; y raycast; yawDeg optional — nil = deterministic
-- jitter). INITIAL DRAFT from the reference image; expect the user to drag.
-- Landmarks: falls pool upstream −X; shopCorridor {-20,28,34,44} (merchant row,
-- south flank); eastCorridor {34,-10,54,38}; garden {-21,-12,34,18}; stair slope
-- climbs the south-west wall.
local CONFIG: { { species: string, x: number, z: number, scale: number, yawDeg: number? } } = {
    -- red maples: over the merchant-row upslope + falls shoulder
    { species = "MapleRed", x = -30, z = 52, scale = 1.1 },
    { species = "MapleRed", x = -2, z = 56, scale = 1.0 },
    { species = "MapleRed", x = 26, z = 54, scale = 1.2 },
    { species = "MapleRed", x = -66, z = -18, scale = 1.15 }, -- falls south shoulder
    { species = "MapleRed", x = -70, z = 16, scale = 1.0 },
    -- gold maples: water's edge by the falls pool + wheel stream
    { species = "MapleGold", x = -56, z = -2, scale = 1.1 },
    { species = "MapleGold", x = -48, z = 12, scale = 0.95 },
    { species = "MapleGold", x = -60, z = -30, scale = 1.0 },
    -- niwaki pines: corridor mouth + garden corners
    { species = "PineNiwaki", x = -20, z = 30, scale = 1.0 },
    { species = "PineNiwaki", x = 36, z = 20, scale = 0.9 },
    { species = "PineNiwaki", x = -24, z = -14, scale = 0.95 },
    -- blush accents: high on the SW stair slope (valley-palette seed)
    { species = "BlushAccent", x = -44, z = 66, scale = 1.0 },
    { species = "BlushAccent", x = -70, z = 48, scale = 0.9 },
}

local FLAG_PARTS = function(root: Instance)
    for _, d in root:GetDescendants() do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CastShadow = false
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
            if d:IsA("MeshPart") then
                d.RenderFidelity = Enum.RenderFidelity.Automatic
            end
        elseif d:IsA("BillboardGui") then
            d:Destroy()
        end
    end
    if root:IsA("BasePart") then
        root.Anchored = true
    end
end

local function lcg(state: number): (number, number)
    state = (1103515245 * state + 12345) % 2147483648
    return state, state / 2147483648
end

local function groundY(x: number, z: number): number?
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { workspace.Terrain }
    local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -600, 0), params)
    return hit and hit.Position.Y or nil
end

local function foliageFolder(): Folder
    local cw = workspace:WaitForChild("CanyonWorld")
    local fol = cw:FindFirstChild("Foliage") :: Folder?
    if not fol then
        fol = Instance.new("Folder")
        fol.Name = "Foliage"
        fol.Parent = cw
    end
    local heroes = (fol :: Folder):FindFirstChild("Heroes") :: Folder?
    if not heroes then
        heroes = Instance.new("Folder")
        heroes.Name = "Heroes"
        heroes.Parent = fol
    end
    return heroes :: Folder
end

local function place()
    local kit = ServerStorage:FindFirstChild("FoliageKit")
    assert(kit, "ServerStorage.FoliageKit missing — run Task 2 kit curation first")
    local heroes = foliageFolder()
    heroes:ClearAllChildren()
    local state = 77
    for i, h in CONFIG do
        local template = kit:FindFirstChild(h.species)
        if not template then
            warn(`no kit template {h.species} — skipped`)
            continue
        end
        local y = groundY(h.x, h.z)
        if not y then
            warn(`no ground at ({h.x}, {h.z}) — skipped {h.species}`)
            continue
        end
        local clone = template:Clone()
        clone.Name = `Hero_{i}_{h.species}`
        local yawRoll
        state, yawRoll = lcg(state)
        local yaw = if h.yawDeg then math.rad(h.yawDeg) else yawRoll * 2 * math.pi
        FLAG_PARTS(clone)
        clone.Parent = heroes
        clone:PivotTo(CFrame.new(h.x, y, h.z) * CFrame.Angles(0, yaw, 0))
        if clone:IsA("Model") then
            clone:ScaleTo(h.scale)
        end
        clone:SetAttribute("Species", h.species)
        clone:SetAttribute("BaseScale", h.scale)
    end
    print(`[heroes] placed {#heroes:GetChildren()} — drag/swap/delete, then MODE="bake"`)
end

local function bake()
    local heroes = foliageFolder()
    local lines = { "local CONFIG = {" }
    for _, clone in heroes:GetChildren() do
        local p = clone:GetPivot().Position
        local species = clone:GetAttribute("Species")
        local scale = clone:GetAttribute("BaseScale") or 1
        local _, yaw, _ = clone:GetPivot():ToEulerAnglesYXZ()
        table.insert(
            lines,
            `    \{ species = "{species}", x = {math.floor(p.X * 10 + 0.5) / 10}, z = {math.floor(p.Z * 10 + 0.5) / 10}, scale = {scale}, yawDeg = {math.floor(math.deg(yaw) + 0.5)} },`
        )
    end
    table.insert(lines, "}")
    print(table.concat(lines, "\n"))
end

if MODE == "place" then
    place()
else
    bake()
end
```

- [ ] **Step 2: Lint + commit the tool**

```bash
cd roblox && stylua --check src tests tools && selene src tools
git add roblox/tools/studio/placeCanopyHeroes.luau
git commit -m "feat(roblox): placeCanopyHeroes — hero-tree survey tool (place/bake)"
```

- [ ] **Step 3: Probe the draft coordinates**

Before stamping, `execute_luau` a probe that raycasts every CONFIG (x, z) and reports ground Y — sanity-check none land in water/on paths (adjust obviously-wrong draft coords once).

- [ ] **Step 4: Run place mode (ONE composed attempt)**

Run the tool via `execute_luau` (Edit). Screenshot from the square floor + one elevated angle (reset camera after).

- [ ] **Step 5: USER GATE — user walks the heroes**

STOP. The user walks it in Studio (square floor, deck, one western teahouse), drags/swaps/deletes. Do not iterate unprompted.

- [ ] **Step 6: Bake + commit the surveyed composition**

Run MODE="bake"; paste the printed CONFIG over the draft in the tool file.

```bash
cd roblox && stylua --check src tests tools && selene src tools
git add roblox/tools/studio/placeCanopyHeroes.luau
git commit -m "polish(roblox): hero canopy composition baked from Studio survey"
```

Ask the user to SAVE the place.

---

### Task 4: Mass-scatter Studio shell + run (USER GATE)

**Files:**
- Create: `roblox/tools/studio/scatterCanopy.luau`

**Interfaces:**
- Consumes: `CanopyScatter.plan` (MIRRORED inline — Task 1 signature verbatim);
  `ServerStorage.FoliageKit` (`ConiferA/B/C`, `BroadleafMid`);
  `workspace.Sandbox.WaterMap.WaterCellData` (StringValue JSON `{ {x,z,y}, ... }`) +
  its `CellSize` attribute; `CanyonWorld.Foliage.Heroes` pivots.
- Produces: `workspace.CanyonWorld.Foliage.CliffMass` clones.

- [ ] **Step 1: Probe the viewshed altitude band**

`execute_luau`: raycast a coarse grid (e.g. 16-stud pitch, x −140..140, z −140..140) and report min/max/histogram of ground Y outside the clearing floor, plus the clearing floor Y near the garden. Use the numbers to set `Y_FLOOR` (clearing floor) and CONFIG `yMin`/`yMax` (cliff band = floor + ~8 up to rim) in Step 2. Record them in the CONFIG comment.

- [ ] **Step 2: Write the shell**

```lua
--!strict
-- scatterCanopy.luau — square-viewshed conifer-mass scatter (spec
-- 2026-07-25-square-canopy-foliage-design §3). Run via MCP execute_luau (Edit).
-- Samples terrain on a grid, plans placements with the MIRRORED CanopyScatter
-- core, stamps kit clones under CanyonWorld.Foliage.CliffMass. IDEMPOTENT: the
-- CliffMass folder is destroyed + rebuilt each run (same SEED → same forest).
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local SEED = 20260725
local RES = 4 -- sampling grid pitch (studs)
local REGION = { xMin = -140, xMax = 140, zMin = -140, zMax = 140 }
-- Y band measured by the Task 4 Step 1 probe — REPLACE with probed values:
local CONFIG = {
    yMin = 108, -- clearing floor + ~8 (probe!)
    yMax = 230, -- rim (probe!)
    maxSteep = 0.55,
    spacing = 8,
    spacingJitter = 6,
    rects = {
        { -21, -12, 34, 18 }, -- karesansui garden (ArenaLayout)
        { -20, 28, 34, 44 }, -- shopCorridor reservation
        { 34, -10, 54, 38 }, -- eastCorridor reservation
        { -45, -45, 45, 45 }, -- square precinct core (tune at run)
        { -80, -14, -40, 14 }, -- falls visual corridor (tune at run)
    },
    circles = {}, -- filled from Heroes at runtime
    waterCells = {}, -- filled from WaterMap at runtime
    waterMargin = 8,
    conifers = {
        { name = "ConiferA", weight = 3 },
        { name = "ConiferB", weight = 2 },
        { name = "ConiferC", weight = 1 },
    },
    broadleaf = { name = "BroadleafMid", weight = 2 },
    heroMix = {}, -- filled from Heroes at runtime
    heroMixRadius = 40,
    keepLowY = 0.25, -- thin near the floor, dense on the walls
    scaleJitter = 0.2,
    tintJitter = 0.08,
}
local HERO_EXCLUDE_R = 14

-- >>> MIRRORED from tools/builders/CanopyScatter.luau — KEEP IN SYNC <<<
-- [paste the full CanopyScatter module body here: lcg, inRect, nearPoint,
--  pickSpecies, CanopyScatter.plan — verbatim from Task 1]
-- >>> END MIRROR <<<

local function samples(): { { x: number, z: number, y: number, steep: number } }
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { workspace.Terrain }
    local out = {}
    for x = REGION.xMin, REGION.xMax, RES do
        for z = REGION.zMin, REGION.zMax, RES do
            local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -600, 0), params)
            if hit and hit.Material ~= Enum.Material.Water then
                table.insert(out, { x = x, z = z, y = hit.Position.Y, steep = 1 - hit.Normal.Y })
            end
        end
    end
    return out
end

local function loadRuntimeExclusions()
    local wm = workspace.Sandbox:FindFirstChild("WaterMap")
    if wm then
        local data = wm:FindFirstChild("WaterCellData") :: StringValue?
        if data then
            for _, cell in HttpService:JSONDecode(data.Value) do
                table.insert(CONFIG.waterCells, { cell.x, cell.z })
            end
        end
    end
    local fol = workspace.CanyonWorld:FindFirstChild("Foliage")
    local heroes = fol and fol:FindFirstChild("Heroes")
    if heroes then
        for _, h in heroes:GetChildren() do
            local p = h:GetPivot().Position
            table.insert(CONFIG.circles, { p.X, p.Z, HERO_EXCLUDE_R })
            table.insert(CONFIG.heroMix, { p.X, p.Z })
        end
    end
end

local function stamp(placements)
    local kit = ServerStorage:FindFirstChild("FoliageKit")
    assert(kit, "ServerStorage.FoliageKit missing")
    local fol = workspace.CanyonWorld:FindFirstChild("Foliage") or Instance.new("Folder")
    fol.Name = "Foliage"
    fol.Parent = workspace.CanyonWorld
    local old = fol:FindFirstChild("CliffMass")
    if old then
        old:Destroy()
    end
    local mass = Instance.new("Folder")
    mass.Name = "CliffMass"
    mass.Parent = fol
    local count = 0
    for _, p in placements do
        local template = kit:FindFirstChild(p.species)
        if not template then
            continue
        end
        local clone = template:Clone()
        for _, d in clone:GetDescendants() do
            if d:IsA("BasePart") then
                d.Anchored = true
                d.CastShadow = false
                d.CanCollide = false
                d.CanQuery = false
                d.CanTouch = false
                if d:IsA("MeshPart") then
                    d.RenderFidelity = Enum.RenderFidelity.Automatic
                end
                -- tint: brightness multiply, SurfaceAppearance first
                local sa = d:FindFirstChildOfClass("SurfaceAppearance")
                if sa then
                    sa.Color = Color3.new(
                        math.clamp(sa.Color.R * p.tint, 0, 1),
                        math.clamp(sa.Color.G * p.tint, 0, 1),
                        math.clamp(sa.Color.B * p.tint, 0, 1)
                    )
                else
                    d.Color = Color3.new(
                        math.clamp(d.Color.R * p.tint, 0, 1),
                        math.clamp(d.Color.G * p.tint, 0, 1),
                        math.clamp(d.Color.B * p.tint, 0, 1)
                    )
                end
            elseif d:IsA("BillboardGui") then
                d:Destroy()
            end
        end
        clone.Parent = mass
        clone:PivotTo(CFrame.new(p.x, p.y, p.z) * CFrame.Angles(0, p.yaw, 0))
        if clone:IsA("Model") then
            clone:ScaleTo(p.scale)
        end
        count += 1
    end
    print(`[canopy] stamped {count} trees (seed {SEED})`)
end

loadRuntimeExclusions()
local placements = CanopyScatter.plan(samples(), CONFIG, SEED)
stamp(placements)
```

- [ ] **Step 3: Paste the mirror + lint + commit**

Copy the CanopyScatter body verbatim into the MIRROR block.

```bash
cd roblox && stylua --check src tests tools && selene src tools
git add roblox/tools/studio/scatterCanopy.luau
git commit -m "feat(roblox): scatterCanopy — conifer-mass Studio shell (mirrors CanopyScatter)"
```

- [ ] **Step 4: Run the scatter (ONE attempt)**

`execute_luau` the shell (Edit). Note the stamped count — if wildly off the 250–400 budget, adjust `spacing`/`keepLowY` ONCE before showing the user (count is a stated budget, not a visual judgment). Screenshot from the square + reset camera.

- [ ] **Step 5: USER GATE — user walks the mass**

STOP. User walks square floor → stair → a western teahouse. Iterate CONFIG only on their notes; every re-run is deterministic.

- [ ] **Step 6: Commit final CONFIG + place save**

```bash
git add roblox/tools/studio/scatterCanopy.luau
git commit -m "polish(roblox): canopy scatter CONFIG gate-tuned"
```

Ask the user to SAVE the place.

---

### Task 5: Night check, phone bench, wrap (USER GATE)

**Files:**
- Modify (if tuning changed values): `roblox/tools/studio/scatterCanopy.luau`, `roblox/tools/studio/placeCanopyHeroes.luau`

- [ ] **Step 1: Night pass**

Set `DayNightLockT = 0.75` (Workspace attribute), screenshot the square with lanterns; verify jewel maples read under warm light and conifers go dark-not-mud. Check day at 0.19. Tint fixes happen in the kit templates (Task 2 Step 6 method) — re-run the scatter to propagate (deterministic; same positions).

- [ ] **Step 2: USER GATE — publish + phone bench**

User publishes the place and checks on a phone: framerate standing in the square with full canopy in view; streaming arriving from a teahouse spawn. Record numbers. If below comfort: reduce mass count (raise `spacing`) → drop `ConiferC` → shrink canopy meshes; re-run + re-bench.

- [ ] **Step 3: Final place save + memory**

User saves/publishes (also carries the 2026-07-25 workspace-cruft deletion). Update `zendojo-arena-amplified` memory: foliage layer status, kit asset IDs, probed Y band, bench numbers; next layer = dock.

- [ ] **Step 4: Final verification + push**

```bash
cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools
git push
```

Expected: all green; CI green on the push.
