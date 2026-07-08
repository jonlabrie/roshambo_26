# Roblox Workspace Organization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate Rojo-managed and place-only content in the Roblox `Workspace` under a durable declarative convention, preserving arena streaming persistence and guarding against the `rojo build` data-loss trap.

**Architecture:** `RoshamboStage` becomes Rojo-owned-only (the 8 declared instances). All hand-built canyon geometry/VFX moves to `Workspace.CanyonWorld` (sub-foldered `Arena`/`Paths`/`Structures`/`Legacy`) and `Workspace.Sandbox` (prototypes/drafts). One pure Lune-tested helper generalizes streaming persistence to cover the relocated arena set; one pure Lune-tested checker backs a Studio pre-publish verifier; one CI step rejects committed place files.

**Tech Stack:** Luau (`--!strict`), Lune test harness (`tests/*.spec.luau`, `harness.describe/test/expect`, matchers `toBe`/`toEqual`/`toThrow`), stylua + selene (CI runs `stylua --check src tests tools` and `selene src tools`), Rojo, GitHub Actions (`.github/workflows/roblox-ci.yml`), Roblox Studio via MCP `execute_luau` for the re-parent.

## Global Constraints

- **`--!strict`** on every new `.luau` module.
- **CI gates all `src`/`tests`/`tools` Luau:** it must pass `lune run tests/run`, `stylua --check src tests tools`, and `selene src tools`. New Studio tools under `tools/` are linted/formatted too — they must be selene/stylua clean.
- **The 8 Rojo-declared `RoshamboStage` children never move or rename:** `BonshoRig`, `Shoro`, `Waterwheel`, `BellDrive`, `ThrowDrum`, `Overlook`, `SwitchbackDeck`, `ArenaSpawn`. Runtime code + `project.json` pin them to `RoshamboStage.<Name>`.
- **Never `rojo build` to produce the shippable place; publish/save the place.** `*.rbxl`/`*.rbxlx` stay gitignored and untracked (already true in both root and `roblox/.gitignore`).
- **Streaming behavior must be preserved exactly:** the set of Models that is `Persistent` before the reorg is `Persistent` after (the arena-visible set), and nothing that streamed normally becomes Persistent.
- Commits end with the two required trailers (Co-Authored-By + Claude-Session).
- Studio re-parenting (Tasks 4–5) is **controller-driven interactive work** (MCP `execute_luau` against the live place); it cannot be delegated to a headless subagent. Per the standing "one visual attempt then stop" rule, pause for user inspection after the skeleton + first move batch.

## File Structure

- Create `roblox/src/shared/StagePersistence.luau` — pure: which Models to mark Persistent, given root instances.
- Create `roblox/tests/StagePersistence.spec.luau`.
- Modify `roblox/src/server/main.server.luau:48-53` — resolve roots (`RoshamboStage` + `CanyonWorld/Arena`) and delegate to the helper.
- Create `roblox/src/shared/WorkspaceConvention.luau` — pure: the convention invariants + the 8 declared names.
- Create `roblox/tests/WorkspaceConvention.spec.luau`.
- Create `roblox/tools/studio/verifyWorkspaceConvention.luau` — Studio adapter (guard 2).
- Modify `.github/workflows/roblox-ci.yml` — add "No committed place files" step (guard 1).
- Modify `CLAUDE.md` and `README_DEPLOY.md` — document the convention + pre-publish checklist.
- (Memory) update `roblox-rojo-vs-place-state.md`.

---

## Task 1: Streaming-persistence helper + wire-in

**Files:**
- Create: `roblox/src/shared/StagePersistence.luau`
- Test: `roblox/tests/StagePersistence.spec.luau`
- Modify: `roblox/src/server/main.server.luau:48-53`

**Interfaces:**
- Produces: `StagePersistence.persistTargets(roots: { Instance }) -> { Instance }` — the flat list of every **direct-child** `Model` across the given roots (used by `main.server.luau` to set `ModelStreamingMode = Persistent`).
- Consumes: nothing.

- [ ] **Step 1: Write the failing test**

`roblox/tests/StagePersistence.spec.luau`:
```lua
--!strict
local harness = require("./harness")
local StagePersistence = require("../src/shared/StagePersistence")
local describe, test, expect = harness.describe, harness.test, harness.expect

-- Minimal Instance mocks: only GetChildren + IsA are exercised by persistTargets.
local function model(name: string)
	return { Name = name, IsA = function(_self: any, c: string): boolean
		return c == "Model"
	end }
end
local function part(name: string)
	return { Name = name, IsA = function(_self: any, c: string): boolean
		return c == "BasePart" or c == "Part"
	end }
end
local function root(children: { any })
	return { GetChildren = function(_self: any): { any }
		return children
	end }
end
local function names(list: { any }): { string }
	local n = {}
	for _, m in list do
		table.insert(n, m.Name)
	end
	return n
end

describe("StagePersistence.persistTargets", function()
	test("collects direct-child Models and skips non-Models", function()
		local r = root({ model("A"), part("B"), model("C") })
		expect(names(StagePersistence.persistTargets({ r :: any }))).toEqual({ "A", "C" })
	end)
	test("flattens Models across multiple roots in order", function()
		local r1 = root({ model("A") })
		local r2 = root({ model("C"), model("D") })
		expect(names(StagePersistence.persistTargets({ r1 :: any, r2 :: any }))).toEqual({ "A", "C", "D" })
	end)
	test("empty roots list yields empty result", function()
		expect(StagePersistence.persistTargets({})).toEqual({})
	end)
	test("a root with no Models yields nothing", function()
		local r = root({ part("B") })
		expect(StagePersistence.persistTargets({ r :: any })).toEqual({})
	end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `StagePersistence` module not found (or `persistTargets` nil).

- [ ] **Step 3: Write minimal implementation**

`roblox/src/shared/StagePersistence.luau`:
```lua
--!strict
-- Pure helper for arena streaming persistence.
-- Given a list of root instances, returns every DIRECT-child Model across them.
-- main.server.luau marks each returned Model ModelStreamingMode = Persistent so the
-- arena is always replicated to spawn-watchers (~200 studs away). Kept pure so it is
-- Lune-testable; the workspace/WaitForChild resolution lives in main.server.luau.
local StagePersistence = {}

function StagePersistence.persistTargets(roots: { Instance }): { Instance }
	local out = {}
	for _, root in roots do
		for _, child in root:GetChildren() do
			if child:IsA("Model") then
				table.insert(out, child)
			end
		end
	end
	return out
end

return StagePersistence
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS (all 4 new tests green, suite still green).

- [ ] **Step 5: Wire into `main.server.luau`**

Replace the existing block at `roblox/src/server/main.server.luau:48-53`:
```lua
local stage = workspace:WaitForChild("RoshamboStage")
for _, child in stage:GetChildren() do
    if child:IsA("Model") then
        child.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    end
end
```
with:
```lua
-- Persist the arena-visible Models so distant spawn-watchers always have them.
-- RoshamboStage holds the Rojo hero props; CanyonWorld/Arena holds the relocated
-- place-only river/falls VFX + rocks (see the workspace-organization convention).
-- The far canyon (CanyonWorld/Paths|Structures|Legacy) is intentionally NOT persisted
-- and streams normally, matching pre-reorg behavior.
local StagePersistence = require(shared:WaitForChild("StagePersistence"))
local stage = workspace:WaitForChild("RoshamboStage")
local persistRoots = { stage }
local canyonWorld = workspace:FindFirstChild("CanyonWorld")
local arena = canyonWorld and canyonWorld:FindFirstChild("Arena")
if arena then
    table.insert(persistRoots, arena)
end
for _, model in StagePersistence.persistTargets(persistRoots) do
    (model :: Model).ModelStreamingMode = Enum.ModelStreamingMode.Persistent
end
```
(`shared` is already defined at `main.server.luau:11` as `ReplicatedStorage:WaitForChild("RoshamboShared")`. `CanyonWorld`/`Arena` use `FindFirstChild` — server-side the full DataModel is present at startup, no wait needed, and the guard makes it safe to deploy before the Studio reorg lands.)

- [ ] **Step 6: Verify lint/format/tests all green**

Run: `cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add roblox/src/shared/StagePersistence.luau roblox/tests/StagePersistence.spec.luau roblox/src/server/main.server.luau
git commit -m "feat(roblox): generalize arena streaming persistence to CanyonWorld/Arena"
```

---

## Task 2: Guard 1 — CI rejects committed place files

**Files:**
- Modify: `.github/workflows/roblox-ci.yml`

**Interfaces:** none (CI-only).

> Note: `*.rbxl`/`*.rbxlx` are already gitignored in both the repo root and `roblox/.gitignore`, and CI's existing "Rojo build" step writes `roshambo-skeleton.rbxl` (untracked, so this guard ignores it). This step is the belt-and-suspenders that fails the build if a place file is ever force-added.

- [ ] **Step 1: Add the guard step**

In `.github/workflows/roblox-ci.yml`, add this step to the `test` job immediately after `- uses: actions/checkout@v4`:
```yaml
      - name: No committed place files
        working-directory: ${{ github.workspace }}
        run: |
          matches=$(git ls-files '*.rbxl' '*.rbxlx')
          if [ -n "$matches" ]; then
            echo "::error::Committed Roblox place file(s) found. The place is place-only; never commit a built .rbxl(x):"
            echo "$matches"
            exit 1
          fi
          echo "OK — no tracked place files."
```
(The default `working-directory: roblox` for the job is overridden here so `git ls-files` scans the whole repo.)

- [ ] **Step 2: Verify the check passes on the current tree**

Run: `git ls-files '*.rbxl' '*.rbxlx'`
Expected: empty output (no tracked place files) → the step would print "OK".

- [ ] **Step 3: Verify the check would fail on a violation (local dry-run, do not commit)**

Run:
```bash
touch roblox/scratch.rbxl && git add -f roblox/scratch.rbxl
git ls-files '*.rbxl' '*.rbxlx'          # expect: roblox/scratch.rbxl
git rm --cached roblox/scratch.rbxl && rm roblox/scratch.rbxl
```
Expected: the middle command lists `roblox/scratch.rbxl` (proving the guard would catch it); cleanup leaves the tree clean.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/roblox-ci.yml
git commit -m "ci(roblox): fail build if a place file (.rbxl/.rbxlx) is committed"
```

---

## Task 3: Guard 2 — convention checker + Studio verifier

**Files:**
- Create: `roblox/src/shared/WorkspaceConvention.luau`
- Test: `roblox/tests/WorkspaceConvention.spec.luau`
- Create: `roblox/tools/studio/verifyWorkspaceConvention.luau`

**Interfaces:**
- Produces: `WorkspaceConvention.DECLARED_STAGE_CHILDREN: { string }` (the 8 names) and `WorkspaceConvention.check(snapshot) -> (boolean, { string })` where `snapshot = { stageChildren: { string }, hasCanyonWorld: boolean, hasArena: boolean, arenaCount: number }`.
- Consumes: nothing (pure). The Studio tool requires it via `ReplicatedStorage.RoshamboShared.WorkspaceConvention`.

- [ ] **Step 1: Write the failing test**

`roblox/tests/WorkspaceConvention.spec.luau`:
```lua
--!strict
local harness = require("./harness")
local WorkspaceConvention = require("../src/shared/WorkspaceConvention")
local describe, test, expect = harness.describe, harness.test, harness.expect

local DECLARED = WorkspaceConvention.DECLARED_STAGE_CHILDREN

local function copy(list: { string }): { string }
	local out = {}
	for _, v in list do
		table.insert(out, v)
	end
	return out
end

describe("WorkspaceConvention.check", function()
	test("a compliant snapshot passes with no failures", function()
		local ok, failures = WorkspaceConvention.check({
			stageChildren = copy(DECLARED),
			hasCanyonWorld = true,
			hasArena = true,
			arenaCount = 24,
		})
		expect(ok).toBe(true)
		expect(#failures).toBe(0)
	end)
	test("an undeclared child in RoshamboStage fails", function()
		local children = copy(DECLARED)
		table.insert(children, "Reach2VFX")
		local ok, failures = WorkspaceConvention.check({
			stageChildren = children,
			hasCanyonWorld = true,
			hasArena = true,
			arenaCount = 24,
		})
		expect(ok).toBe(false)
		expect(#failures).toBe(1)
	end)
	test("a missing declared child fails", function()
		local children = copy(DECLARED)
		table.remove(children, 1) -- drop BonshoRig
		local ok = WorkspaceConvention.check({
			stageChildren = children,
			hasCanyonWorld = true,
			hasArena = true,
			arenaCount = 24,
		})
		expect(ok).toBe(false)
	end)
	test("missing CanyonWorld and Arena both fail", function()
		local ok, failures = WorkspaceConvention.check({
			stageChildren = copy(DECLARED),
			hasCanyonWorld = false,
			hasArena = false,
			arenaCount = 0,
		})
		expect(ok).toBe(false)
		expect(#failures).toBe(2)
	end)
	test("an empty Arena fails", function()
		local ok = WorkspaceConvention.check({
			stageChildren = copy(DECLARED),
			hasCanyonWorld = true,
			hasArena = true,
			arenaCount = 0,
		})
		expect(ok).toBe(false)
	end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `WorkspaceConvention` module not found.

- [ ] **Step 3: Write minimal implementation**

`roblox/src/shared/WorkspaceConvention.luau`:
```lua
--!strict
-- Pure invariants for the workspace Rojo/place-only convention
-- (spec 2026-07-08-roblox-workspace-organization). Backs the Studio pre-publish
-- verifier tools/studio/verifyWorkspaceConvention.luau.
local WorkspaceConvention = {}

-- The instances Rojo declares under Workspace.RoshamboStage in default.project.json.
-- RoshamboStage must contain EXACTLY these (no hand-built place-only content).
WorkspaceConvention.DECLARED_STAGE_CHILDREN = {
	"BonshoRig",
	"Shoro",
	"Waterwheel",
	"BellDrive",
	"ThrowDrum",
	"Overlook",
	"SwitchbackDeck",
	"ArenaSpawn",
}

export type Snapshot = {
	stageChildren: { string },
	hasCanyonWorld: boolean,
	hasArena: boolean,
	arenaCount: number,
}

function WorkspaceConvention.check(snapshot: Snapshot): (boolean, { string })
	local failures = {}
	local declared = {}
	for _, name in WorkspaceConvention.DECLARED_STAGE_CHILDREN do
		declared[name] = true
	end
	local seen = {}
	for _, name in snapshot.stageChildren do
		seen[name] = true
		if not declared[name] then
			table.insert(
				failures,
				`RoshamboStage has undeclared child '{name}' — place-only content belongs in CanyonWorld/Sandbox`
			)
		end
	end
	for _, name in WorkspaceConvention.DECLARED_STAGE_CHILDREN do
		if not seen[name] then
			table.insert(failures, `RoshamboStage is missing declared child '{name}'`)
		end
	end
	if not snapshot.hasCanyonWorld then
		table.insert(failures, "Workspace.CanyonWorld is missing")
	end
	if not snapshot.hasArena then
		table.insert(failures, "Workspace.CanyonWorld.Arena is missing")
	end
	if snapshot.hasArena and snapshot.arenaCount <= 0 then
		table.insert(failures, "CanyonWorld.Arena is empty — arena VFX/rocks not relocated?")
	end
	return #failures == 0, failures
end

return WorkspaceConvention
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Write the Studio adapter (guard 2 runner)**

`roblox/tools/studio/verifyWorkspaceConvention.luau`:
```lua
--!strict
-- PRE-PUBLISH GATE. Run in Studio (Edit) via MCP execute_luau BEFORE publishing the
-- place. Verifies the workspace matches the Rojo/place-only convention
-- (spec 2026-07-08-roblox-workspace-organization). Requires RoshamboShared synced
-- (rojo serve connected, or the last sync applied). Returns true on PASS.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorkspaceConvention = require(ReplicatedStorage.RoshamboShared.WorkspaceConvention)

local stage = workspace:FindFirstChild("RoshamboStage")
local stageChildren = {}
if stage then
	for _, child in stage:GetChildren() do
		table.insert(stageChildren, child.Name)
	end
end
local canyonWorld = workspace:FindFirstChild("CanyonWorld")
local arena = canyonWorld and canyonWorld:FindFirstChild("Arena")

local ok, failures = WorkspaceConvention.check({
	stageChildren = stageChildren,
	hasCanyonWorld = canyonWorld ~= nil,
	hasArena = arena ~= nil,
	arenaCount = if arena then #arena:GetChildren() else 0,
})

if ok then
	print("[convention] PASS — workspace matches the Rojo/place-only convention.")
else
	warn("[convention] FAIL:")
	for _, f in failures do
		warn("  - " .. f)
	end
end
return ok
```

- [ ] **Step 6: Verify lint/format/tests all green**

Run: `cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools`
Expected: all PASS (the new Studio tool is under `tools/`, so it is linted/formatted — confirm it is clean).

- [ ] **Step 7: Commit**

```bash
git add roblox/src/shared/WorkspaceConvention.luau roblox/tests/WorkspaceConvention.spec.luau roblox/tools/studio/verifyWorkspaceConvention.luau
git commit -m "feat(roblox): workspace-convention checker + Studio pre-publish verifier"
```

---

## Task 4: Studio re-parent (INTERACTIVE — controller-driven)

**This task is not a headless subagent task.** The controller runs it against the live place via MCP `execute_luau`, saving/publishing the place afterward. Per the standing "one visual attempt then stop" rule, **stop for user inspection after Step 2 (skeleton) and Step 3 (first batch)** before continuing.

**Files:** none in git (place-only mutation). Depends on Task 1 (persistence loop already tolerates `CanyonWorld/Arena` being absent, so it is safe that this task lands after the code).

- [ ] **Step 1: Snapshot the pre-reorg tree (for rollback reference)**

Via MCP `execute_luau`, print the names + classNames of `workspace:GetChildren()` and `workspace.RoshamboStage:GetChildren()`. Save the output to the ledger/scratch so any mis-move can be reversed.

- [ ] **Step 2: Build the folder skeleton, then STOP for user inspection**

Via MCP `execute_luau`:
```lua
local function folder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local cw = folder(workspace, "CanyonWorld")
folder(cw, "Arena")
folder(cw, "Paths")
folder(cw, "Structures")
folder(cw, "Legacy")
folder(workspace, "Sandbox")
return "skeleton built"
```
**STOP.** Ask the user to confirm the empty folder skeleton looks right in the Explorer before moving anything.

- [ ] **Step 3: Move batch A (RoshamboStage → CanyonWorld/Arena, 24), then STOP**

Via MCP `execute_luau`, using this reusable mover (source is a child of RoshamboStage; dest is a dotted path under workspace):
```lua
local function moveChildren(sourceParent: Instance, destPath: { string }, names: { string })
	local dest: Instance = workspace
	for _, seg in destPath do
		dest = dest:FindFirstChild(seg) :: Instance
		assert(dest, "missing dest folder: " .. seg)
	end
	local moved, missing = {}, {}
	for _, name in names do
		local inst = sourceParent:FindFirstChild(name)
		if inst then
			inst.Parent = dest
			table.insert(moved, name)
		else
			table.insert(missing, name)
		end
	end
	return ("moved %d, missing %d: %s"):format(#moved, #missing, table.concat(missing, ", "))
end

local stage = workspace.RoshamboStage
return moveChildren(stage, { "CanyonWorld", "Arena" }, {
	"Reach2VFX", "Reach3VFX", "Reach4VFX", "LowerStepVFX", "ClearingInfallVFX",
	"HeroInfallVFX", "ClearingFallVFX", "TopToOutfallVFX", "MicroToLargestVFX", "LargestInfallVFX",
	"Reach2Rocks", "Reach3Rocks", "Reach4Rocks", "LowerStepRocks", "ClearingInfallRocks",
	"HeroInfallRocks", "ClearingFallRocks", "TopToOutfallRocks", "MicroToLargestRocks", "LargestInfallRocks",
	"FallsLanding", "LandingDeck", "DowncanyonVFX", "UpcanyonVFX",
})
```
Expected: "moved 24, missing 0". **STOP.** Ask the user to confirm the arena VFX/rocks now live under `CanyonWorld/Arena` and the scene still looks correct.

- [ ] **Step 4: Move batch B (RoshamboStage → Sandbox, 5)**

```lua
return moveChildren(workspace.RoshamboStage, { "Sandbox" }, {
	"Reach159POC", "Reach2POC", "Reach3POC", "OutfallChannelPOC", "DevChannelSpawn",
})
```
Expected: "moved 5, missing 0". After this, `RoshamboStage` should contain exactly the 8 declared children.

- [ ] **Step 5: Move top-level batches C/D/E/F (source parent = `workspace`)**

For top-level items the source parent is `workspace` itself:
```lua
-- Batch C -> CanyonWorld/Paths (12)
moveChildren(workspace, { "CanyonWorld", "Paths" }, {
	"NW80FallsStair", "NW40Descent", "NW2040Path", "NW1012West", "NW1012South",
	"NW1211Path", "DescentPath", "PathExtension", "PathSteps", "PathRailings",
	"PathLanterns", "Stairs_40_50",
})
-- Batch D -> CanyonWorld/Structures (5)
moveChildren(workspace, { "CanyonWorld", "Structures" }, {
	"Bridges", "RetainingWalls", "NWFallsWall", "BenchLanding", "EngawaSafetyRail",
})
-- Batch E -> CanyonWorld/Legacy (1)
moveChildren(workspace, { "CanyonWorld", "Legacy" }, { "CanyonTeahouses" })
-- Batch F -> Sandbox (3 drafts)
return moveChildren(workspace, { "Sandbox" }, {
	"PathDraft", "ReachDraft", "TempBridgeAbutments",
})
```
Expected each: "moved N, missing 0".

- [ ] **Step 6: Flag the `Decal` anomaly (do NOT move blindly)**

Via MCP `inspect_instance` on `Workspace.Decal`, report its properties to the user and **ask** whether it is orphaned (delete/Sandbox) or intentional (leave). Do not move or delete it without an answer.

- [ ] **Step 7: Save/publish the place**

Save the place in Studio (File → Save, or publish). **Do not `rojo build`.** Confirm to the user the reorg is persisted.

---

## Task 5: Verify the reorg (INTERACTIVE)

**Files:** none. Depends on Tasks 3 and 4.

- [ ] **Step 1: Run the pre-publish verifier**

Ensure `rojo serve` has synced `RoshamboShared` (so `WorkspaceConvention` is present), then via MCP `execute_luau` run the body of `tools/studio/verifyWorkspaceConvention.luau`.
Expected: `[convention] PASS`.

- [ ] **Step 2: Negative check**

Temporarily re-parent one Sandbox item into `RoshamboStage`, re-run the verifier.
Expected: `[convention] FAIL` naming the undeclared child. Move it back; re-run → PASS.

- [ ] **Step 3: Play-test streaming persistence**

Enter Play (against the dev server). From the spawn vantage, confirm the arena river/falls VFX + rocks render (persistence preserved) and `WheelController`/`HammerController`/`DrumController` bind their rigs without warnings.
Expected: arena renders; no `WaitForChild` timeouts in the console.

- [ ] **Step 4: Record the As-built in the ledger**

Append the final `RoshamboStage` child list (should be the 8 declared) and `CanyonWorld/Arena` count to `.superpowers/sdd/progress.md`.

---

## Task 6: Document the convention

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README_DEPLOY.md`

**Interfaces:** none.

- [ ] **Step 1: Add the convention to `CLAUDE.md`**

Under the Roblox client architecture section, add a short subsection stating the declarative rule and the folder map:
```markdown
### Workspace organization (Rojo vs place-only)

Rojo manages **exactly what `default.project.json` names** — all of it lives under
`Workspace.RoshamboStage` (7 hero-prop models from `assets/*.model.json` + `ArenaSpawn`).
`RoshamboStage` holds nothing else; never hand-add children to it in Studio.

Everything else in Workspace is **place-only** (saved in the place, not in git) and
organized by lifecycle:
- `Workspace.CanyonWorld` — shipped hand-built geometry/VFX: `Arena` (river/falls VFX +
  rocks near the arena, kept `Persistent` for distant spawn-watchers via
  `StagePersistence`), `Paths`, `Structures`, `Legacy` (the frozen 14 `CanyonTeahouses`).
- `Workspace.Sandbox` — throwaway prototypes/drafts.

Ship by **publishing/saving the place, never `rojo build`** (that emits only the declared
RoshamboStage children and drops all place-only content). CI fails if a `.rbxl(x)` is
committed; before publishing, run `tools/studio/verifyWorkspaceConvention.luau` in Studio.
```

- [ ] **Step 2: Add a pre-publish checklist to `README_DEPLOY.md`**

Add a short "Before publishing the Roblox place" section pointing at `verifyWorkspaceConvention.luau` and the never-`rojo build` rule.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md README_DEPLOY.md
git commit -m "docs(roblox): document the workspace Rojo/place-only convention"
```

- [ ] **Step 4: Update memory (controller, outside the commit)**

Rewrite `roblox-rojo-vs-place-state.md` to the declarative framing: "Rojo owns exactly what project.json names (all under RoshamboStage); everything else is place-only, foldered CanyonWorld/Sandbox." Note the resolved RoshamboStage-cohabitation caveat and the two guards. Update the `MEMORY.md` hook line.

## Self-Review

- **Spec coverage:** convention (Tasks 4/6) ✓; classification table (Task 4) ✓; persistence dependency (Task 1) ✓; guard 1 CI (Task 2) ✓; guard 2 checker + Studio verifier (Task 3) ✓; docs + memory (Task 6) ✓; Decal flag (Task 4 Step 6) ✓; verify/Play-test (Task 5) ✓.
- **Type consistency:** `persistTargets(roots)` name/signature matches between Task 1 module, test, and `main.server.luau` wire-in. `WorkspaceConvention.check(snapshot)` and `DECLARED_STAGE_CHILDREN` match between Task 3 module, test, and the Studio tool. Snapshot fields (`stageChildren`/`hasCanyonWorld`/`hasArena`/`arenaCount`) are identical in all three.
- **Placeholders:** none — all code and commands are literal.
- **Ordering safety:** Task 1's wire-in uses `FindFirstChild` + guard, so it deploys safely before the Task 4 reorg exists; Task 3's checker exists before Task 5 runs it.
