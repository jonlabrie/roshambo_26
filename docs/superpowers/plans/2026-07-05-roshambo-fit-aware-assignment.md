# Fit-Aware Pad Assignment (Sub-Project B, Increment 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `PadRegistry` with footprint-fit — a pure `fits(padFP, structFP)` containment check and a `claimVacantFor(owner, structFP)` that claims the first vacant pad big enough for the structure.

**Architecture:** Pure Luau additions to the existing `PadRegistry` stateful object; deterministic registration-order scan. Lune-tested, no Studio. See spec: `docs/superpowers/specs/2026-07-05-roshambo-fit-aware-assignment-design.md`.

**Tech Stack:** Luau; Lune harness; Rojo (`src/shared → ReplicatedStorage.RoshamboShared`).

## Global Constraints

- **Purity:** runs under Lune — plain tables only, no Roblox datatypes, no `math.random`.
- **Footprint:** the mount-relative rectangle `{ minX, maxX, minZ, maxZ }` (pad = support capacity; structure = actual frame).
- **`fits(padFP, structFP)`** = containment: `structFP.minX >= padFP.minX and structFP.maxX <= padFP.maxX and structFP.minZ >= padFP.minZ and structFP.maxZ <= padFP.maxZ`.
- **`claimVacantFor(owner, structFP)`** scans in **registration order**, claims the first pad that is vacant AND whose `spec.footprint` `fits`; returns `{id, spec}`; `nil` if none. A pad whose `spec.footprint` is `nil` is **skipped**.
- **Existing API unchanged:** `register/findVacant/claim/claimVacant/release/get` are not modified.
- **Module path:** `roblox/src/shared/PadRegistry.luau`; tests in `roblox/tests/PadRegistry.spec.luau`. Run `lune run tests/run` from `roblox/` (baseline: 278 passing).

---

### Task 1: fits + claimVacantFor

**Files:**
- Modify: `roblox/src/shared/PadRegistry.luau`
- Modify: `roblox/tests/PadRegistry.spec.luau`

**Interfaces:**
- Consumes: the existing `PadRegistry` (`.new()`, `_order`, `_pads`, `:get`).
- Produces: `PadRegistry.fits(padFootprint, structFootprint) -> boolean` (module function) and `Registry:claimVacantFor(owner: string, structFootprint) -> { id: string, spec: any }?`.

- [ ] **Step 1: Write the failing tests** (append to `roblox/tests/PadRegistry.spec.luau`)

```lua
test("fits: contained/exact -> true; overhang -> false", function()
    local pad = { minX = -10, maxX = 15, minZ = -12, maxZ = 5 }
    expect(PadRegistry.fits(pad, { minX = -7, maxX = 12, minZ = -10, maxZ = 4 })).toBe(true)  -- contained
    expect(PadRegistry.fits(pad, pad)).toBe(true)                                              -- exact
    expect(PadRegistry.fits(pad, { minX = -7, maxX = 16, minZ = -10, maxZ = 4 })).toBe(false) -- wider +X
    expect(PadRegistry.fits(pad, { minX = -7, maxX = 12, minZ = -10, maxZ = 6 })).toBe(false) -- deeper +Z
    expect(PadRegistry.fits(pad, { minX = -11, maxX = 12, minZ = -10, maxZ = 4 })).toBe(false)-- under-min -X
end)

test("claimVacantFor: skips a too-small vacant pad, claims the first fitting one", function()
    local r = PadRegistry.new()
    local small = { minX = -3, maxX = 3, minZ = -3, maxZ = 3 }
    local big = { minX = -10, maxX = 15, minZ = -12, maxZ = 5 }
    r:register("small", { footprint = small })
    r:register("big", { footprint = big })
    local struct = { minX = -7, maxX = 12, minZ = -10, maxZ = 4 } -- fits big, not small
    local claimed = r:claimVacantFor("owner1", struct)
    expect(claimed.id).toBe("big")
    expect(claimed.spec.footprint).toEqual(big)
    expect(r:get("big").occupant).toBe("owner1")
    expect(r:get("small").occupant).toBeNil() -- untouched
end)

test("claimVacantFor: nil when none fit", function()
    local r = PadRegistry.new()
    r:register("small", { footprint = { minX = -3, maxX = 3, minZ = -3, maxZ = 3 } })
    expect(r:claimVacantFor("o", { minX = -7, maxX = 12, minZ = -10, maxZ = 4 })).toBeNil()
end)

test("claimVacantFor: skips a pad whose spec has no footprint", function()
    local r = PadRegistry.new()
    r:register("nofp", { other = true }) -- no footprint
    r:register("ok", { footprint = { minX = -10, maxX = 15, minZ = -12, maxZ = 5 } })
    local claimed = r:claimVacantFor("o", { minX = -7, maxX = 12, minZ = -10, maxZ = 4 })
    expect(claimed.id).toBe("ok")
    expect(r:get("nofp").occupant).toBeNil()
end)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `PadRegistry.fits` is nil / `claimVacantFor` is nil.

- [ ] **Step 3: Add the implementation**

In `roblox/src/shared/PadRegistry.luau`, add a footprint type near the top (below `export type PadRecord = ...`):

```lua
export type Footprint = { minX: number, maxX: number, minZ: number, maxZ: number }
```

Add the pure module function (a dot function, not a method — anywhere after `PadRegistry.__index = PadRegistry`, e.g. right after `PadRegistry.new`):

```lua
function PadRegistry.fits(padFootprint: Footprint, structFootprint: Footprint): boolean
	return structFootprint.minX >= padFootprint.minX
		and structFootprint.maxX <= padFootprint.maxX
		and structFootprint.minZ >= padFootprint.minZ
		and structFootprint.maxZ <= padFootprint.maxZ
end
```

Add the method (e.g. right after `:claimVacant`):

```lua
function PadRegistry:claimVacantFor(owner: string, structFootprint: Footprint): { id: string, spec: any }?
	for _, id in self._order do
		local pad = self._pads[id]
		if pad.occupant == nil then
			local fp = pad.spec and pad.spec.footprint
			if fp ~= nil and PadRegistry.fits(fp, structFootprint) then
				pad.occupant = owner
				return { id = id, spec = pad.spec }
			end
		end
	end
	return nil
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd roblox && lune run tests/run`
Expected: PASS (4 new tests; suite green).

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/PadRegistry.luau roblox/tests/PadRegistry.spec.luau
git commit -m "feat(roblox): PadRegistry — fit-aware assignment (fits + claimVacantFor)"
```

---

## Self-review

- **Spec coverage:** `fits` containment → Task 1 impl + the truth-table test; `claimVacantFor` (first vacant fitting, registration order, `{id,spec}`, nil-when-none, nil-footprint skip) → Task 1 impl + its three tests; existing API untouched (only additions) → the impl adds two functions and modifies nothing else.
- **Placeholder scan:** none — full code in every step.
- **Type consistency:** `Footprint {minX,maxX,minZ,maxZ}` used by both `fits` and `claimVacantFor`; `claimVacantFor` calls the dot function `PadRegistry.fits(fp, structFootprint)` (not `self:fits`), matching the module-function definition; return shape `{id, spec}` matches `claimVacant` and the tests' `claimed.id`/`claimed.spec`.
