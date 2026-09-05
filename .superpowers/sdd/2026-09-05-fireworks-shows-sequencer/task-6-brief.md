### Task 6: Hand-authored show drafts and the Studio-only proving verb

**Files:**
- Create: `roblox/src/shared/FireworkShows.luau`
- Test: `roblox/tests/FireworkShows.spec.luau`
- Modify: `roblox/src/server/main.server.luau` (beside the `RequestProvingFire` handler)
- Modify: `roblox/src/client/ProvingController.client.luau` (a new "Shows" section)

**Interfaces:**
- Consumes: `ShowPlan.validate/PROVING_SLOTS/LIMITS`, `ProvingPlan.RACKS`, Task 5's `playShow`, the existing proving origin code (station axis / rooftop mount), `RequestProvingShow` remote (declared in Task 5).
- Produces:
  - `FireworkShows.DRAFTS: { [name: string]: { title: string, cues: { Cue } } }` with at least `finale_v1`
  - `FireworkShows.ORDER: { string }` — display order
  - RemoteEvent `RequestProvingShow(name: string)` (Studio-gated on the server)

- [ ] **Step 1: Write the failing test**

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local FireworkShows = require("../src/shared/FireworkShows")
local ShowPlan = require("../src/shared/ShowPlan")
local ProvingPlan = require("../src/shared/ProvingPlan")
local MortarPlacement = require("../src/shared/MortarPlacement")
local shellFixture = require("./fixtures/fireworkShells")

local known = ShowPlan.knownShellSet(shellFixture.shells)

describe("FireworkShows -- every draft is a valid proving-stage show", function()
    test("ORDER names every draft exactly once", function()
        local seen = {}
        for _, name in FireworkShows.ORDER do
            expect(FireworkShows.DRAFTS[name]).toBeTruthy()
            expect(seen[name]).toBeNil()
            seen[name] = true
        end
        local n = 0
        for _ in FireworkShows.DRAFTS do
            n += 1
        end
        expect(#FireworkShows.ORDER).toBe(n)
    end)
    for name, draft in FireworkShows.DRAFTS do
        test(`{name} validates against PROVING_SLOTS with shipped shells only`, function()
            local r = ShowPlan.validate(draft.cues, ShowPlan.PROVING_SLOTS, MortarPlacement.SHELL_MORTAR, known)
            expect(r.ok).toBe(true)
        end)
        test(`{name} uses only real stations`, function()
            local racks = {}
            for _, r in ProvingPlan.RACKS do
                racks[r] = true
            end
            for _, c in draft.cues do
                expect(racks[c.slot]).toBe(true)
            end
        end)
    end
    test("finale_v1 is LARGE: it exists to stress the director", function()
        local f = FireworkShows.DRAFTS.finale_v1
        expect(#f.cues >= 80).toBe(true)
        -- at least one moment with six cues inside 300 ms -- a real volley, not a metronome
        local best = 0
        for i, c in f.cues do
            local n = 0
            for j = i, #f.cues do
                if f.cues[j].t_ms - c.t_ms <= 300 then
                    n += 1
                end
            end
            best = math.max(best, n)
        end
        expect(best >= 6).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run 2>&1 | tail -3` — expected: missing module.

- [ ] **Step 3: Write the drafts**

```lua
--!strict
-- HAND-AUTHORED SHOWS for the proving verb and the A13 test (spec §10 row B). Pure data. These are
-- the first programs the sequencer plays and the first thing that puts many shells in one sky on
-- purpose; finale_v1 is deliberately dense so the director's concurrent-shell budget is exercised
-- at scale for the first time. Author here, sync with Rojo, press Play, open the proving panel.
local FireworkShows = {}

export type Cue = { t_ms: number, slot: string, shellId: string }
export type Draft = { title: string, cues: { Cue } }

local S = { "north arena", "bridge", "upper north", "mid pool", "hi west" }
local ROOF = "hanabiya roof"

local function cue(t_ms: number, slot: string, shellId: string): Cue
    return { t_ms = t_ms, slot = slot, shellId = shellId }
end

-- Build a program section: every `gapMs`, one shell round-robin across the five stations.
local function walk(startMs: number, gapMs: number, shells: { string }, count: number): { Cue }
    local out = {}
    for i = 1, count do
        table.insert(out, cue(startMs + (i - 1) * gapMs, S[((i - 1) % #S) + 1], shells[((i - 1) % #shells) + 1]))
    end
    return out
end

-- Fire `shellId` from every station (and the roof) within `spreadMs` of `atMs`.
local function volley(atMs: number, shellId: string, spreadMs: number, withRoof: boolean): { Cue }
    local out = {}
    for i, st in S do
        table.insert(out, cue(atMs + math.floor((i - 1) * spreadMs / #S), st, shellId))
    end
    if withRoof then
        table.insert(out, cue(atMs, ROOF, shellId))
    end
    return out
end

local function concat(...: { Cue }): { Cue }
    local out = {}
    for _, list in { ... } do
        for _, c in list do
            table.insert(out, c)
        end
    end
    table.sort(out, function(a, b)
        return a.t_ms < b.t_ms
    end)
    return out
end

FireworkShows.DRAFTS = {
    -- A short program to check timing by eye before anything heavy: one shell every second.
    warmup = {
        title = "Warm-up (5 shells, 1 s apart)",
        cues = walk(0, 1000, { "peony", "kiku", "wa", "rai", "willow" }, 5),
    },
    -- THE STRESS PROGRAM. ~2 minutes: an opening walk, three volleys that put six bursts in the
    -- sky inside 300 ms, a quiet middle, then a finale that stacks heavies. Shipped shells only.
    finale_v1 = {
        title = "Finale v1 (stress: volleys + heavies)",
        cues = concat(
            walk(0, 900, { "peony", "kiku", "rai" }, 15), -- 0–12.6 s: opening walk
            volley(15000, "wa", 250, true), -- 15 s: six red rings
            walk(18000, 600, { "willow", "hotaru", "banrai" }, 20), -- 18–29.4 s: faster walk
            volley(32000, "yashi", 200, true), -- 32 s
            volley(33000, "kiku", 200, false), -- 33 s: back-to-back volleys
            walk(37000, 1500, { "peony" }, 8), -- 37–47.5 s: quiet middle
            walk(52000, 400, { "wa", "rai", "kiku", "banrai" }, 20), -- 52–59.6 s: build
            volley(62000, "kamuro", 300, true), -- 62 s: heavies together — the case the budget exists for
            volley(63500, "janken", 300, false), -- 63.5 s
            volley(65000, "kamuro", 250, true), -- 65 s
            walk(68000, 300, { "hotaru", "yashi" }, 12) -- 68–71.3 s: close
        ),
    },
}

FireworkShows.ORDER = { "warmup", "finale_v1" }

return FireworkShows
```

Count check: 15 + 6 + 20 + 6 + 5 + 8 + 20 + 6 + 5 + 6 + 12 = 109 cues, under `maxCues` 120, last cue at ~71 s, well under `maxDurationS`. If the count test fails, adjust the walks, never the limits.

- [ ] **Step 4: Run to verify it passes, format, lint**

Run: `cd roblox && lune run tests/run 2>&1 | tail -3 && stylua --check src tests tools && selene src tools`
Expected: green and clean.

- [ ] **Step 5: The Studio-gated server verb**

In `main.server.luau`, first extract the proving origin resolution so the show path can reuse it. Inside the `RequestProvingFire` handler the two branches (rooftop mount vs station rack) each compute `origin`, `heading`, `apexHeight`. Move that computation into a local function placed above the handler:

```lua
-- Resolve a proving slot (a station name, or "hanabiya roof" = one random battery mount) to a
-- launch origin/heading/apex, exactly as RequestProvingFire does. Shared with RequestProvingShow.
local function provingOriginFor(rackName: string): (Vector3?, Vector3?, number?)
    if rackName == "hanabiya roof" then
        local mounts = {}
        for _, m in CollectionService:GetTagged("FireworkTubeMount") do
            if m:IsA("BasePart") then
                table.insert(mounts, m)
            end
        end
        if #mounts == 0 then
            return nil, nil, nil
        end
        local mount = mounts[math.random(1, #mounts)]
        local muzzle = mount.Size.Y / 2 + MortarPlacement.TUBE["mortar:L"].length
        return mount.CFrame:PointToWorldSpace(Vector3.new(0, muzzle + 0.2, 0)), mount.CFrame.UpVector, mount:GetAttribute("LaunchApex")
    end
    -- The existing handler's lookup, verbatim: the ProvingGround model under the proving stage folder,
    -- rack part named after the station.
    local ground = stageForProving and stageForProving:FindFirstChild("ProvingGround")
    local rack = ground and ground:FindFirstChild(rackName)
    if rack == nil or not rack:IsA("BasePart") then
        return nil, nil, nil
    end
    local axis = rack.CFrame.RightVector
    return rack.Position + axis * (rack.Size.X / 2 + 0.1), axis, rack:GetAttribute("LaunchApex")
end
```

Then make `RequestProvingFire` call `provingOriginFor(rackName)` and `broadcastLaunch({ shellId = shellId, origin = origin, heading = heading, by = "proving", boosted = if forceBoost == true then true else nil, apexHeight = apex })` instead of its two inline copies, keeping its Studio gate and its draft-id handling exactly as they are. `stageForProving` is the local the handler already uses (line ~1652); `provingOriginFor` must be declared after it.

Add the show verb beside it, with the identical Studio gate the fire verb uses:

```lua
local RequestProvingShow = remotes:WaitForChild("RequestProvingShow") :: RemoteEvent
local FireworkShows = require(shared.FireworkShows)

RequestProvingShow.OnServerEvent:Connect(function(_player, name)
    if not RunService:IsStudio() then
        return -- the same gate as RequestProvingFire: a published client's request dies here
    end
    if typeof(name) ~= "string" then
        return
    end
    local draft = FireworkShows.DRAFTS[name]
    if draft == nil then
        return
    end
    local function originFor(c: ShowPlan.Cue): (Vector3?, Vector3?, number?)
        return provingOriginFor(c.slot)
    end
    playShow("proving", "proving", "proving", draft.cues, originFor, `proving:{name}`)
end)
```

- [ ] **Step 6: The panel's "Shows" section**

In `ProvingController.client.luau`, after the shipped-shells section is built (near the `makeHeader` / `makeRow` calls that lay out modes), add a header `Shows` and one row per `FireworkShows.ORDER` entry with the draft's `title` and a single **Play** button (`makeButton(row, "Play", …)`) whose click does `RequestProvingShow:FireServer(name)`. Follow the file's existing button/row helpers exactly; no new UI primitives. Require `FireworkShows` the way the file requires `ProvingPlan`.

- [ ] **Step 7: Format, lint, suite; commit**

Run: `cd roblox && stylua --check src tests tools && selene src tools && lune run tests/run 2>&1 | tail -3`

```bash
git add roblox/src/shared/FireworkShows.luau roblox/tests/FireworkShows.spec.luau roblox/src/server/main.server.luau roblox/src/client/ProvingController.client.luau
git commit -m "feat(shows): hand-authored show drafts (warmup, finale_v1) and a Studio-only Play verb on the proving panel; proving origin resolution shared

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

