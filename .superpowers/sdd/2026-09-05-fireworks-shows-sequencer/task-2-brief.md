### Task 2: The Luau twin — `ShowPlan.luau`

**Files:**
- Create: `roblox/tests/fixtures/shows.luau`
- Create: `roblox/src/shared/ShowPlan.luau`
- Test: `roblox/tests/ShowPlan.spec.luau`

**Interfaces:**
- Consumes: `roblox/tests/fixtures/fireworkShells.luau` (`shells`, `mortars = { { shell, mortar } }`), `MortarPlacement.SHELL_MORTAR` (`{ [shellId]: "mortar:S" }`).
- Produces (module `ShowPlan`):
  - `ShowPlan.LIMITS = { maxCues = 120, maxDurationS = 300 }` (transcribed; the spec asserts it equals the fixture)
  - `ShowPlan.DECK_SLOTS: { [string]: string }`, `ShowPlan.PROVING_SLOTS: { [string]: string }` (transcribed; asserted against the fixture)
  - `type Cue = { t_ms: number, slot: string, shellId: string }`
  - `ShowPlan.validate(cues: any, stage: { [string]: string }, shellMortar: { [string]: string }, knownShells: { [string]: boolean }) : { ok: boolean, error: string?, cue: number? }` — `cue` is **zero-based** to match the fixture and the TS twin
  - `ShowPlan.tally(cues: { Cue }): { [string]: number }`
  - `ShowPlan.knownShellSet(ids: { string }): { [string]: boolean }`

- [ ] **Step 1: Write the fixture reader**

```lua
--!strict
-- shared-fixtures/shows.json, read under Lune the same way fireworkShells.luau reads its fixture:
-- never transcribed, so a case added on the server side is a case here the next time tests run.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local PATH = "../shared-fixtures/shows.json"

local decoded = serde.decode("json", fs.readFile(PATH))
assert(type(decoded) == "table", `{PATH} is not a table`)
assert(type(decoded.limits) == "table", `{PATH} has no limits`)
assert(type(decoded.stages) == "table", `{PATH} has no stages`)
assert(type(decoded.cases) == "table" and #decoded.cases > 0, `{PATH} lists no cases`)

export type Case = { name: string, stage: string, cues: { any }, expect: string, cue: number? }

return {
    limits = decoded.limits :: { maxCues: number, maxDurationS: number },
    stages = decoded.stages :: { [string]: { [string]: string } },
    cases = decoded.cases :: { Case },
}
```

- [ ] **Step 2: Write the failing test**

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ShowPlan = require("../src/shared/ShowPlan")
local MortarPlacement = require("../src/shared/MortarPlacement")
local fixture = require("./fixtures/shows")
local shellFixture = require("./fixtures/fireworkShells")

local known = ShowPlan.knownShellSet(shellFixture.shells)

describe("ShowPlan -- the fixture is the contract", function()
    test("LIMITS equal the fixture", function()
        expect(ShowPlan.LIMITS).toEqual(fixture.limits)
    end)
    test("DECK_SLOTS and PROVING_SLOTS equal the fixture stages", function()
        expect(ShowPlan.DECK_SLOTS).toEqual(fixture.stages.deck)
        expect(ShowPlan.PROVING_SLOTS).toEqual(fixture.stages.proving)
    end)
end)

describe("ShowPlan.validate -- every fixture case", function()
    for _, c in fixture.cases do
        test(c.name, function()
            local r = ShowPlan.validate(c.cues, fixture.stages[c.stage], MortarPlacement.SHELL_MORTAR, known)
            if c.expect == "ok" then
                expect(r.ok).toBe(true)
                expect(r.error).toBeNil()
            else
                expect(r.ok).toBe(false)
                expect(r.error).toBe(c.expect)
                if c.cue ~= nil then
                    expect(r.cue).toBe(c.cue)
                end
            end
        end)
    end
    test("TOO_MANY_CUES at maxCues + 1, and exactly maxCues is fine", function()
        local cues = {}
        for i = 1, ShowPlan.LIMITS.maxCues + 1 do
            table.insert(cues, { t_ms = (i - 1) * 10, slot = "hand", shellId = "firecracker" })
        end
        expect(ShowPlan.validate(cues, ShowPlan.DECK_SLOTS, MortarPlacement.SHELL_MORTAR, known).error).toBe("TOO_MANY_CUES")
        table.remove(cues)
        expect(ShowPlan.validate(cues, ShowPlan.DECK_SLOTS, MortarPlacement.SHELL_MORTAR, known).ok).toBe(true)
    end)
    test("non-table input is EMPTY", function()
        expect(ShowPlan.validate(nil, ShowPlan.DECK_SLOTS, MortarPlacement.SHELL_MORTAR, known).error).toBe("EMPTY")
        expect(ShowPlan.validate("nope", ShowPlan.DECK_SLOTS, MortarPlacement.SHELL_MORTAR, known).error).toBe("EMPTY")
    end)
end)

describe("ShowPlan.tally", function()
    test("counts per shell id", function()
        expect(ShowPlan.tally({
            { t_ms = 0, slot = "hand", shellId = "firecracker" },
            { t_ms = 0, slot = "mortar:S", shellId = "peony" },
            { t_ms = 500, slot = "hand", shellId = "firecracker" },
        })).toEqual({ firecracker = 2, peony = 1 })
    end)
end)
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd roblox && lune run tests/run 2>&1 | tail -5`
Expected: the run errors on `require("../src/shared/ShowPlan")` (module missing). If the harness aborts the whole run on a missing module, that is the expected red.

- [ ] **Step 4: Write minimal implementation**

```lua
--!strict
-- A SHOW IS DATA. The Luau twin of server/src/shows.ts, held to shared-fixtures/shows.json by
-- tests/ShowPlan.spec.luau: every case the server validator runs, this one runs too, so the
-- console can refuse a show for exactly the reason the backend would and never sends one the
-- backend will bounce. Pure: no Roblox globals, runs under Lune.
--
-- Slot tables are transcribed here (the runtime cannot read the fixture); the spec asserts they
-- equal it. Add a slot in the fixture first, then here, or CI says so.
local ShowPlan = {}

export type Cue = { t_ms: number, slot: string, shellId: string }
export type Check = { ok: boolean, error: string?, cue: number? }

ShowPlan.LIMITS = { maxCues = 120, maxDurationS = 300 }

-- slot -> what may fire from it: "none" (no-gear shells only), "mortar:X" (that tier only), "any".
ShowPlan.DECK_SLOTS = { hand = "none", ["mortar:S"] = "mortar:S", ["mortar:M"] = "mortar:M", ["mortar:L"] = "mortar:L" }
ShowPlan.PROVING_SLOTS = {
    ["north arena"] = "any",
    ["bridge"] = "any",
    ["upper north"] = "any",
    ["mid pool"] = "any",
    ["hi west"] = "any",
    ["hanabiya roof"] = "any",
}

function ShowPlan.knownShellSet(ids: { string }): { [string]: boolean }
    local set = {}
    for _, id in ids do
        set[id] = true
    end
    return set
end

local function fail(error: string, cue: number?): Check
    return { ok = false, error = error, cue = cue }
end

local function isCue(c: any): boolean
    return type(c) == "table"
        and type(c.t_ms) == "number"
        and c.t_ms == c.t_ms -- not NaN
        and c.t_ms ~= math.huge
        and c.t_ms ~= -math.huge
        and type(c.slot) == "string"
        and type(c.shellId) == "string"
end

-- `cue` in a failure is ZERO-BASED, matching the fixture and the TypeScript twin.
function ShowPlan.validate(
    cues: any,
    stage: { [string]: string },
    shellMortar: { [string]: string },
    knownShells: { [string]: boolean }
): Check
    if type(cues) ~= "table" or #cues == 0 then
        return fail("EMPTY")
    end
    if #cues > ShowPlan.LIMITS.maxCues then
        return fail("TOO_MANY_CUES")
    end
    local last = -math.huge
    for i, c in ipairs(cues) do
        local idx = i - 1
        if not isCue(c) then
            return fail("BAD_CUE", idx)
        end
        if c.t_ms < 0 then
            return fail("NEGATIVE_TIME", idx)
        end
        if c.t_ms < last then
            return fail("CUES_OUT_OF_ORDER", idx)
        end
        last = c.t_ms
        local accepts = stage[c.slot]
        if accepts == nil then
            return fail("BAD_SLOT", idx)
        end
        if not knownShells[c.shellId] then
            return fail("BAD_SHELL", idx)
        end
        local needs = shellMortar[c.shellId]
        if accepts == "none" and needs ~= nil then
            return fail("TIER_MISMATCH", idx)
        end
        if string.sub(accepts, 1, 7) == "mortar:" and needs ~= accepts then
            return fail("TIER_MISMATCH", idx)
        end
    end
    if last > ShowPlan.LIMITS.maxDurationS * 1000 then
        return fail("TOO_LONG")
    end
    return { ok = true }
end

function ShowPlan.tally(cues: { Cue }): { [string]: number }
    local out: { [string]: number } = {}
    for _, c in cues do
        out[c.shellId] = (out[c.shellId] or 0) + 1
    end
    return out
end

return ShowPlan
```

- [ ] **Step 5: Run tests, format and lint**

Run: `cd roblox && lune run tests/run 2>&1 | tail -3 && stylua --check src tests tools && selene src tools`
Expected: all pass (1847 + the new tests), no style or lint output. If `stylua --check` fails, run `stylua src tests tools` and re-check.

- [ ] **Step 6: Commit**

```bash
git add roblox/tests/fixtures/shows.luau roblox/src/shared/ShowPlan.luau roblox/tests/ShowPlan.spec.luau
git commit -m "feat(shows): ShowPlan.luau -- the Luau validator, held to the same fixture as the server

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

