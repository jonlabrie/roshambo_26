# Pad Registry (Sub-Project B, Increment 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A pure, Lune-tested `PadRegistry` — a per-server occupancy model (register pads, find/claim the first vacant, release) that is the state behind "the server finds an empty pad on spawn."

**Architecture:** A stateful object (`.new()` + methods via a metatable), matching the repo's stateful modules. Pure Luau — no Roblox datatypes, no `math.random`. Deterministic first-vacant assignment via an insertion-ordered id list. See spec: `docs/superpowers/specs/2026-07-05-roshambo-pad-registry-design.md`.

**Tech Stack:** Luau; Lune harness (`roblox/tests/harness.luau`, `run.luau`); Rojo (`src/shared → ReplicatedStorage.RoshamboShared`).

## Global Constraints

- **Purity:** runs headless under Lune — plain tables only, **no Roblox datatypes, no `math.random`**.
- **Pad record:** `{ id: string, spec: any, occupant: string? }`; `occupant = nil` (vacant) or an opaque `ownerId` string. `spec` is opaque to the registry (a `PadSpec`).
- **Determinism:** `findVacant` / `claimVacant` return the first vacant pad in **registration order** (an insertion-ordered id array), not hash-map order.
- **Return contracts (exact):** `register -> boolean` (false on duplicate, no overwrite); `findVacant -> string?`; `claim(id, owner) -> boolean` (false on unknown id or already-claimed); `claimVacant(owner) -> {id, spec}?` (nil when full); `release(id) -> boolean` (false on unknown id; **true no-op** on already-vacant); `get(id) -> {id, spec, occupant}?` (nil on unknown id).
- **Module path:** `roblox/src/shared/PadRegistry.luau`; spec requires it as `../src/shared/PadRegistry`. Run tests with `lune run tests/run` from `roblox/` (baseline: 267 passing).

---

### Task 1: PadRegistry — occupancy lifecycle

**Files:**
- Create: `roblox/src/shared/PadRegistry.luau`
- Test: `roblox/tests/PadRegistry.spec.luau`

**Interfaces:**
- Produces: `PadRegistry.new() -> Registry` with methods `:register(id, spec) -> boolean`, `:findVacant() -> string?`, `:claim(id, owner) -> boolean`, `:claimVacant(owner) -> {id, spec}?`, `:release(id) -> boolean`, `:get(id) -> {id, spec, occupant}?`. `PadRecord = { id: string, spec: any, occupant: string? }`.

- [ ] **Step 1: Write the failing test**

```lua
-- roblox/tests/PadRegistry.spec.luau
--!strict
local harness = require("./harness")
local test, expect = harness.test, harness.expect
local PadRegistry = require("../src/shared/PadRegistry")

test("register adds vacant pads; duplicate id returns false and does not overwrite", function()
    local r = PadRegistry.new()
    expect(r:register("a", { tag = "specA" })).toBe(true)
    expect(r:register("a", { tag = "OTHER" })).toBe(false)
    expect(r:get("a").spec.tag).toBe("specA")
    expect(r:get("a").occupant).toBeNil()
end)

test("findVacant returns first-registered vacant id; nil when full", function()
    local r = PadRegistry.new()
    r:register("a", 1); r:register("b", 2)
    expect(r:findVacant()).toBe("a")
    r:claim("a", "owner1")
    expect(r:findVacant()).toBe("b")
    r:claim("b", "owner2")
    expect(r:findVacant()).toBeNil()
end)

test("claim: false on unknown id and on already-claimed", function()
    local r = PadRegistry.new()
    r:register("a", 1)
    expect(r:claim("nope", "o")).toBe(false)
    expect(r:claim("a", "o1")).toBe(true)
    expect(r:claim("a", "o2")).toBe(false)
    expect(r:get("a").occupant).toBe("o1")
end)

test("claimVacant returns {id,spec}, marks claimed, hands out in registration order", function()
    local r = PadRegistry.new()
    r:register("a", "sa"); r:register("b", "sb")
    local first = r:claimVacant("o1")
    expect(first.id).toBe("a")
    expect(first.spec).toBe("sa")
    local second = r:claimVacant("o2")
    expect(second.id).toBe("b")
    expect(r:claimVacant("o3")).toBeNil()
    expect(r:get("a").occupant).toBe("o1")
end)

test("release frees a claimed pad; false on unknown; no-op true on already vacant", function()
    local r = PadRegistry.new()
    r:register("a", 1)
    r:claim("a", "o1")
    expect(r:release("a")).toBe(true)
    expect(r:findVacant()).toBe("a")
    expect(r:release("a")).toBe(true) -- no-op on already-vacant
    expect(r:release("nope")).toBe(false)
end)

test("get returns nil for unknown id", function()
    local r = PadRegistry.new()
    expect(r:get("nope")).toBeNil()
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `PadRegistry` not found.

- [ ] **Step 3: Write minimal implementation**

```lua
-- roblox/src/shared/PadRegistry.luau
--!strict
-- Per-server pad occupancy model. Stateful object; sub-project D creates one per Roblox
-- server, registers that server's pads at startup, then claimVacant() on spawn / release()
-- on leave. Pure Luau (Lune-tested): no Roblox datatypes, no math.random. `spec` is an
-- opaque PadSpec. First-vacant assignment is deterministic (insertion-ordered id list).
local PadRegistry = {}
PadRegistry.__index = PadRegistry

export type PadRecord = { id: string, spec: any, occupant: string? }

function PadRegistry.new()
    return setmetatable({ _order = {} :: { string }, _pads = {} :: { [string]: PadRecord } }, PadRegistry)
end

function PadRegistry:register(id: string, spec: any): boolean
    if self._pads[id] then
        return false
    end
    self._pads[id] = { id = id, spec = spec, occupant = nil }
    table.insert(self._order, id)
    return true
end

function PadRegistry:findVacant(): string?
    for _, id in self._order do
        if self._pads[id].occupant == nil then
            return id
        end
    end
    return nil
end

function PadRegistry:claim(id: string, owner: string): boolean
    local pad = self._pads[id]
    if not pad or pad.occupant ~= nil then
        return false
    end
    pad.occupant = owner
    return true
end

function PadRegistry:claimVacant(owner: string): { id: string, spec: any }?
    local id = self:findVacant()
    if not id then
        return nil
    end
    self._pads[id].occupant = owner
    return { id = id, spec = self._pads[id].spec }
end

function PadRegistry:release(id: string): boolean
    local pad = self._pads[id]
    if not pad then
        return false
    end
    pad.occupant = nil
    return true
end

function PadRegistry:get(id: string): PadRecord?
    local pad = self._pads[id]
    if not pad then
        return nil
    end
    return { id = pad.id, spec = pad.spec, occupant = pad.occupant }
end

return PadRegistry
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS (6 new tests; suite green).

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/PadRegistry.luau roblox/tests/PadRegistry.spec.luau
git commit -m "feat(roblox): PadRegistry — per-server pad occupancy (register/claim/release)"
```

---

## Self-review

- **Spec coverage:** the pad record + every API method (register/findVacant/claim/claimVacant/release/get) → Task 1 implementation; every tested edge case in the spec's Testing section (duplicate register, unknown/already-claimed claim, first-vacant order, claimVacant full/order, release unknown/no-op, get unknown) → the 6 tests in Step 1. Non-goals (persistence, policies, visuals) are correctly absent.
- **Placeholder scan:** none — full code in every step.
- **Type consistency:** `PadRecord {id,spec,occupant}` used in `register`/`get`; `claimVacant` returns the `{id, spec}` subset (per spec) — intentional and matched by its test (`first.id`/`first.spec`); method names identical between the implementation and the tests.
