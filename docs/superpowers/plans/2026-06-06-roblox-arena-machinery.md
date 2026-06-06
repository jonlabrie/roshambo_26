# Arena Machinery Implementation Plan (Milestone 4a)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** All Lune-testable machinery of the Dojo Arena spec plus placeholder-visual wiring — so a Studio session shows the full round theater (flap board, hammer countdown, gong, grows, pursuing fates with fate-binding and Accept Fate) with gray-box visuals, ready for milestone 4b's art pass.

**Architecture:** Spec: `docs/superpowers/specs/2026-06-06-dojo-arena-design.md`. Same dual-runtime DI discipline as M2/M3: pure modules in `src/shared` (Lune-tested, no Roblox globals, no cross-requires), thin Roblox-runtime controllers in `src/client`, composition in `main.server.luau`. New remotes: `RevealTheater` (broadcast results map), `FateResolved` (victim→server→broadcast, reason `caught|accepted`), `BoardData` (board rows). **Milestone 4b (separate plan, after this ships): Studio worldbuilding** — terrain, teahouses + TextChannels, authentic models/materials/sounds, lighting, tatami watermark, real basin skinned mesh.

**Tech Stack:** Luau, Lune tests (74 passing now), Rojo, TweenService, SurfaceGui, ParticleEmitter.

**Conventions:** Run from `roblox/` with `export PATH="$HOME/.rokit/bin:$PATH"`. Tests: `lune run tests/run`. Branch: `feature/arena-machinery` — verify with `git branch --show-current` before every commit; never check out a bare SHA. After each task: `stylua --check src tests` (auto-fix + re-run tests if needed) and `selene src` clean.

---

## File Structure

```
roblox/src/shared/
  ThemeManifest.luau        validation of theme data modules
  themes/ZenDojo.luau       theme #1 (placeholder asset ids "0" until 4b)
  EffectRegistry.luau       slot → variant pools (data)
  EffectSelector.luau       registry lookup + selection policy
  FlapScheduler.luau        split-flap flip planning (utf8-aware)
  HammerCurve.luau          hammer angle/latch state from phase+time
  DoomEscalation.luau       pursuit math: stages, spawns, caps, homing, fast-catch
  ChoreographyMachine.luau  phase/reveal cues with stagger
  FateRegistry.luau         who is fate-bound (server gate state)
roblox/src/client/
  EventBus.luau             BindableEvents for cross-controller cues
  BoardController.client.luau    flap board renderer (placeholder part)
  HammerController.client.luau   hammer/gong/basin placeholder animation
  TheaterController.client.luau  cue executor: petals, umbrella, lanterns stubs
  FateController.client.luau     pursuit sim (per-victim authority) + placeholders
roblox/src/server/
  NetworkClient.luau        MODIFY: +getLeaderboards
  RoundCoordinator.luau     MODIFY: tape in onRound; whiffed in onReveal
  main.server.luau          MODIFY: v3 composition (new remotes, grow, fate gate, board loop)
roblox/src/client/main.client.luau  MODIFY: fate lock UI, Accept Fate button, whiff toast
roblox/default.project.json MODIFY: new remotes + Workspace placeholder stage parts
roblox/tests/*.spec.luau    new specs per pure module + extensions
```

---

### Task 1: Data plumbing — getLeaderboards, tape, whiffed

**Files:**
- Modify: `roblox/src/server/NetworkClient.luau`, `roblox/src/server/RoundCoordinator.luau`
- Test: append to `roblox/tests/NetworkClient.spec.luau`, `roblox/tests/RoundCoordinator.spec.luau`

- [ ] **Step 1: Failing tests.** Append to `NetworkClient.spec.luau`:

```lua
describe("NetworkClient.getLeaderboards", function()
    test("hits the world-scope path", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = '{"scope":"world","leaders":[]}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:getLeaderboards("world")
        expect(res.ok).toBe(true)
        expect(res.data.scope).toBe("world")
        expect(f.calls[1].url).toBe("http://x/api/v1/leaderboards?scope=world")
    end)
end)
```

Append to `RoundCoordinator.spec.luau` (uses existing `makeFakes`/`makeCoordinator`/`okState`; note `okState` builds `data` — add a `tape` field to it: `tape = { { id = roundId, worldThrow = "R" } }`):

```lua
describe("RoundCoordinator v3 payload extensions", function()
    test("onRound includes the tape from /state", function()
        local f = makeFakes({ okState("r1", "ACTIVE", 7) }, {})
        local rounds: { any } = {}
        local c = makeCoordinator(f, {
            onRound = function(info: any)
                table.insert(rounds, info)
            end,
        })
        c:pollOnce()
        expect(#rounds).toBe(1)
        expect(rounds[1].tape[1].worldThrow).toBe("R")
    end)

    test("onReveal includes the whiffed set", function()
        -- now() consumption: submitPick takes 0; poll2's flush check takes 1000
        -- (cadence baseline, no flush); poll3 takes 7000 (6s elapsed -> flush,
        -- which whiffs); poll4 is TALLY (no flush check) and fires the reveal.
        local f = makeFakes(
            {
                okState("r1", "ACTIVE", 7, 99000),
                okState("r1", "ACTIVE", 7, 99000),
                okState("r1", "ACTIVE", 7, 99000),
                okState("r1", "TALLY", 7),
            },
            { { ok = true, data = { worldThrow = "S", distribution = { R = 100, P = 0, S = 0 }, totalPlayers = 1 } } },
            { nows = { 0, 1000, 7000 } }
        )
        f.net.postThrows = function(_self, batch: any): any
            table.insert(f.postCalls, batch)
            return { ok = false, status = 409, error = "PICKS_CLOSED" }
        end
        local reveals: { any } = {}
        local c = makeCoordinator(f, {
            onReveal = function(r: any)
                table.insert(reveals, r)
            end,
        })
        c:pollOnce() -- no picks: consumes no now()
        c:submitPick("9", "R")
        c:pollOnce() -- baseline, no flush
        c:pollOnce() -- flush -> PICKS_CLOSED -> whiff
        c:pollOnce() -- TALLY: reveal fires
        expect(reveals[1].whiffed["9"]).toBe(true)
        expect(reveals[1].results["9"]).toBeNil()
    end)
end)
```

In `okState`, change the `data` table to include tape: `data = { roundId = roundId, phase = phase, roundCount = roundCount, serverTime = 1, phaseEndsAt = phaseEndsAt or 100000, tape = { { id = roundId, worldThrow = "R" } } }`.

- [ ] **Step 2: Run; expect the 3 new tests to fail.**
- [ ] **Step 3: Implement.** NetworkClient (after `postBank`):

```lua
function NetworkClient.getLeaderboards(self: any, scope: string): Result
    return self:_request("GET", `/api/v1/leaderboards?scope={scope}`)
end
```

RoundCoordinator: in the `onRound` callback payload add `tape = state.tape`; in `_fetchRevealIfDue`'s `onReveal` payload add `whiffed = self._whiffed`.

- [ ] **Step 4: Run → `77 passed`.** Lint/format clean.
- [ ] **Step 5: Commit** — `git add roblox/src/server/ roblox/tests/ && git commit -m "feat(roblox): leaderboards endpoint + tape/whiffed in coordinator payloads"`

### Task 2: ThemeManifest + ZenDojo

**Files:**
- Create: `roblox/src/shared/ThemeManifest.luau`, `roblox/src/shared/themes/ZenDojo.luau`
- Test: `roblox/tests/ThemeManifest.spec.luau`

- [ ] **Step 1: Failing test:**

```lua
--!strict
local harness = require("./harness")
local ThemeManifest = require("../src/shared/ThemeManifest")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function validTheme(): any
    return {
        name = "T",
        labels = { boardHeader = "世界 · THE WORLD" },
        sounds = { clack = "0", gong = "0", drumroll = "0", latch = "0", splash = "0", bank = "0" },
        models = { boulder = "0", paperSheet = "0", shears = "0", umbrella = "0" },
    }
end

describe("ThemeManifest", function()
    test("accepts a complete theme", function()
        local ok, errs = ThemeManifest.validate(validTheme())
        expect(ok).toBe(true)
        expect(#errs).toBe(0)
    end)

    test("rejects missing name and boardHeader", function()
        local t = validTheme()
        t.name = nil
        t.labels.boardHeader = nil
        local ok, errs = ThemeManifest.validate(t)
        expect(ok).toBe(false)
        expect(#errs).toBe(2)
    end)

    test("rejects a missing required sound", function()
        local t = validTheme()
        t.sounds.gong = nil
        local ok, errs = ThemeManifest.validate(t)
        expect(ok).toBe(false)
        expect(errs[1]).toBe("missing sound: gong")
    end)

    test("rejects a non-string model ref", function()
        local t = validTheme()
        t.models.boulder = 123
        local ok = ThemeManifest.validate(t)
        expect(ok).toBe(false)
    end)

    test("the shipped ZenDojo theme validates", function()
        local ok, errs = ThemeManifest.validate(ZenDojo)
        expect(ok).toBe(true)
        expect(#errs).toBe(0)
    end)
end)
```

- [ ] **Step 2: Run; fail.**
- [ ] **Step 3: Implement.** `ThemeManifest.luau`:

```lua
--!strict
-- Validates ArenaTheme data modules at boot: a missing key is a loud failure,
-- never a silent gray prop (spec §8).
local ThemeManifest = {}

ThemeManifest.REQUIRED_SOUNDS = { "clack", "gong", "drumroll", "latch", "splash", "bank" }
ThemeManifest.REQUIRED_MODELS = { "boulder", "paperSheet", "shears", "umbrella" }

function ThemeManifest.validate(theme: any): (boolean, { string })
    local errs: { string } = {}
    if type(theme) ~= "table" then
        return false, { "theme is not a table" }
    end
    if type(theme.name) ~= "string" then
        table.insert(errs, "missing name")
    end
    if type(theme.labels) ~= "table" or type(theme.labels.boardHeader) ~= "string" then
        table.insert(errs, "missing labels.boardHeader")
    end
    local sounds = if type(theme.sounds) == "table" then theme.sounds else {}
    for _, key in ThemeManifest.REQUIRED_SOUNDS do
        if type(sounds[key]) ~= "string" then
            table.insert(errs, `missing sound: {key}`)
        end
    end
    local models = if type(theme.models) == "table" then theme.models else {}
    for _, key in ThemeManifest.REQUIRED_MODELS do
        if type(models[key]) ~= "string" then
            table.insert(errs, `missing model: {key}`)
        end
    end
    return #errs == 0, errs
end

return ThemeManifest
```

`themes/ZenDojo.luau` (asset ids are "0" placeholders until 4b; the sound/model players no-op on "0"):

```lua
--!strict
-- Zen Dojo theme (Edo Japan). Asset ids land in milestone 4b's art pass;
-- "0" means "placeholder visual / no sound" to the runtime players.
return {
    name = "ZenDojo",
    labels = { boardHeader = "世界 · THE WORLD" },
    sounds = { clack = "0", gong = "0", drumroll = "0", latch = "0", splash = "0", bank = "0" },
    models = { boulder = "0", paperSheet = "0", shears = "0", umbrella = "0" },
}
```

- [ ] **Step 4: Run → `82 passed`.** Lint/format clean.
- [ ] **Step 5: Commit** — `git add roblox/src/shared/ThemeManifest.luau roblox/src/shared/themes/ roblox/tests/ThemeManifest.spec.luau && git commit -m "feat(roblox): ThemeManifest validation + ZenDojo theme skeleton"`

### Task 3: EffectRegistry + EffectSelector

**Files:**
- Create: `roblox/src/shared/EffectRegistry.luau`, `roblox/src/shared/EffectSelector.luau`
- Test: `roblox/tests/EffectSelector.spec.luau`

- [ ] **Step 1: Failing test:**

```lua
--!strict
local harness = require("./harness")
local EffectRegistry = require("../src/shared/EffectRegistry")
local EffectSelector = require("../src/shared/EffectSelector")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("EffectSelector", function()
    test("LOSS maps deterministically by world throw", function()
        local s = EffectSelector.new(EffectRegistry, { random = function()
            return 0
        end })
        expect(s:select("LOSS", { worldThrow = "R" })).toBe("fateBoulder")
        expect(s:select("LOSS", { worldThrow = "P" })).toBe("fatePaper")
        expect(s:select("LOSS", { worldThrow = "S" })).toBe("fateShears")
    end)

    test("other slots pick from the pool via injected random", function()
        local s = EffectSelector.new(
            { WIN = { "a", "b", "c" } },
            { random = function()
                return 0.5
            end }
        )
        expect(s:select("WIN", {})).toBe("b")
    end)

    test("single-variant pools always return the variant", function()
        local s = EffectSelector.new(EffectRegistry, { random = function()
            return 0.99
        end })
        expect(s:select("SAFE", {})).toBe("umbrellaPop")
        expect(s:select("REVEAL", {})).toBe("waterHammer")
    end)

    test("unknown slot returns nil", function()
        local s = EffectSelector.new(EffectRegistry, { random = function()
            return 0
        end })
        expect(s:select("NOPE", {})).toBeNil()
    end)
end)
```

- [ ] **Step 2: Run; fail.**
- [ ] **Step 3: Implement.** `EffectRegistry.luau`:

```lua
--!strict
-- Effect slot → variant pools (spec §2). Adding a variant is a data change.
return {
    REVEAL = { "waterHammer" },
    WIN = { "growPetals" },
    SAFE = { "umbrellaPop" },
    LOSS = { byThrow = { R = "fateBoulder", P = "fatePaper", S = "fateShears" } },
    BANK = { "coinToss" },
}
```

`EffectSelector.luau`:

```lua
--!strict
-- Picks an effect variant for a slot. LOSS is deterministic (the doom IS the
-- world throw); other slots use the injected selection policy (random now;
-- pot-tier escalation is a future policy — spec §2).
local EffectSelector = {}
EffectSelector.__index = EffectSelector

function EffectSelector.new(registry: any, deps: { random: () -> number })
    return setmetatable({ _registry = registry, _random = deps.random }, EffectSelector)
end

function EffectSelector.select(self: any, slot: string, ctx: any): string?
    local entry = self._registry[slot]
    if entry == nil then
        return nil
    end
    if entry.byThrow then
        return entry.byThrow[ctx.worldThrow]
    end
    local n = #entry
    if n == 0 then
        return nil
    end
    return entry[1 + math.floor(self._random() * n) % n]
end

return EffectSelector
```

- [ ] **Step 4: Run → `86 passed`.** Lint/format clean.
- [ ] **Step 5: Commit** — `git add roblox/src/shared/EffectRegistry.luau roblox/src/shared/EffectSelector.luau roblox/tests/EffectSelector.spec.luau && git commit -m "feat(roblox): EffectRegistry + EffectSelector with deterministic LOSS mapping"`

### Task 4: FlapScheduler

**Files:**
- Create: `roblox/src/shared/FlapScheduler.luau`
- Test: `roblox/tests/FlapScheduler.spec.luau`

- [ ] **Step 1: Failing test:**

```lua
--!strict
local harness = require("./harness")
local FlapScheduler = require("../src/shared/FlapScheduler")
local describe, test, expect = harness.describe, harness.test, harness.expect

local OPTS = { stepMs = 100, staggerMs = 50 }

local function stepsFor(plan: { any }, col: number): { any }
    local out = {}
    for _, s in plan do
        if s.col == col then
            table.insert(out, s)
        end
    end
    table.sort(out, function(a, b)
        return a.atMs < b.atMs
    end)
    return out
end

describe("FlapScheduler", function()
    test("unchanged columns produce no steps", function()
        expect(#FlapScheduler.plan("AB", "AB", OPTS)).toBe(0)
    end)

    test("steps cycle the drum from current to target", function()
        -- drum order contains "...ABC..."; A->C is exactly 2 steps: B then C
        local plan = FlapScheduler.plan("A", "C", OPTS)
        local s = stepsFor(plan, 1)
        expect(#s).toBe(2)
        expect(s[1].char).toBe("B")
        expect(s[1].atMs).toBe(0)
        expect(s[1].isFinal).toBe(false)
        expect(s[2].char).toBe("C")
        expect(s[2].atMs).toBe(100)
        expect(s[2].isFinal).toBe(true)
    end)

    test("columns are staggered left to right", function()
        local plan = FlapScheduler.plan("AA", "BB", OPTS)
        expect(stepsFor(plan, 1)[1].atMs).toBe(0)
        expect(stepsFor(plan, 2)[1].atMs).toBe(50)
    end)

    test("wraps around the end of the drum", function()
        -- drum ends "...9,.!?+%○─∧" then wraps to leading space then A
        local plan = FlapScheduler.plan("∧", "A", OPTS)
        local s = stepsFor(plan, 1)
        expect(s[#s].char).toBe("A")
        expect(s[#s].isFinal).toBe(true)
        expect(#s).toBe(2) -- ∧ -> space -> A
    end)

    test("shorter strings are padded with spaces", function()
        local plan = FlapScheduler.plan("A", "AB", OPTS)
        -- col 1 unchanged; col 2 goes space -> ... -> B (space is drum position 1, A is 2, B is 3)
        local s = stepsFor(plan, 2)
        expect(#s).toBe(2)
        expect(s[#s].char).toBe("B")
    end)

    test("multibyte glyphs count as single columns", function()
        local plan = FlapScheduler.plan("○─∧", "○─○", OPTS)
        expect(#stepsFor(plan, 1)).toBe(0)
        expect(#stepsFor(plan, 2)).toBe(0)
        local s = stepsFor(plan, 3)
        expect(s[#s].char).toBe("○")
        expect(s[1].atMs).toBe(100) -- stagger: (3-1)*50ms
    end)
end)
```

- [ ] **Step 2: Run; fail.**
- [ ] **Step 3: Implement** `FlapScheduler.luau`:

```lua
--!strict
-- Plans split-flap transitions: which cell flips when, cycling through the
-- character drum to its target (spec §4.2). Pure — the client controller
-- executes the schedule with tweens and clacks.
local FlapScheduler = {}

FlapScheduler.DRUM = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789,.!?+%○─∧"

export type Step = { col: number, atMs: number, char: string, isFinal: boolean }
export type Opts = { stepMs: number?, staggerMs: number?, drum: string? }

local function toChars(s: string): { string }
    local chars: { string } = {}
    for _, code in utf8.codes(s) do
        table.insert(chars, utf8.char(code))
    end
    return chars
end

function FlapScheduler.plan(current: string, target: string, opts: Opts?): { Step }
    local o = opts or {}
    local stepMs = o.stepMs or 83 -- ~12 steps/sec
    local staggerMs = o.staggerMs or 60
    local drum = toChars(o.drum or FlapScheduler.DRUM)
    local index: { [string]: number } = {}
    for i, ch in drum do
        index[ch] = i
    end

    local cur = toChars(current)
    local tgt = toChars(target)
    local cols = math.max(#cur, #tgt)
    local steps: { Step } = {}

    for col = 1, cols do
        local c = cur[col] or " "
        local t = tgt[col] or " "
        if c ~= t then
            local ci = index[c] or 1
            local ti = index[t] or 1
            local n = #drum
            local count = (ti - ci) % n
            for k = 1, count do
                table.insert(steps, {
                    col = col,
                    atMs = (col - 1) * staggerMs + (k - 1) * stepMs,
                    char = drum[(ci + k - 1) % n + 1],
                    isFinal = k == count,
                })
            end
        end
    end
    return steps
end

return FlapScheduler
```

- [ ] **Step 4: Run → `92 passed`.** Lint/format clean. (If the wrap test fails on step count, check the DRUM string: `∧` is the last drum char, so `∧→A` is exactly `space, A` = 2 steps.)
- [ ] **Step 5: Commit** — `git add roblox/src/shared/FlapScheduler.luau roblox/tests/FlapScheduler.spec.luau && git commit -m "feat(roblox): FlapScheduler - utf8-aware split-flap planning with stagger"`

### Task 5: HammerCurve

**Files:**
- Create: `roblox/src/shared/HammerCurve.luau`
- Test: `roblox/tests/HammerCurve.spec.luau`

- [ ] **Step 1: Failing test:**

```lua
--!strict
local harness = require("./harness")
local HammerCurve = require("../src/shared/HammerCurve")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("HammerCurve", function()
    test("round start: hammer at rest, not latched", function()
        local s = HammerCurve.state("ACTIVE", 20)
        expect(s.angleDeg).toBe(-75)
        expect(s.latched).toBe(false)
        expect(s.released).toBe(false)
    end)

    test("mid-round: halfway up the crank", function()
        -- crank runs over 18s (20 - 2 lockout lead); at secondsLeft 11, elapsed 9 -> p = 0.5
        local s = HammerCurve.state("ACTIVE", 11)
        expect(s.angleDeg).toBeCloseTo((-75 + 55) / 2)
    end)

    test("at lockout: apex + latched", function()
        local s = HammerCurve.state("ACTIVE", 2)
        expect(s.angleDeg).toBe(55)
        expect(s.latched).toBe(true)
    end)

    test("TALLY: trembling at apex", function()
        local s = HammerCurve.state("TALLY", 1)
        expect(s.angleDeg).toBe(55)
        expect(s.trembling).toBe(true)
    end)

    test("REVEAL: released", function()
        local s = HammerCurve.state("REVEAL", 3)
        expect(s.released).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run; fail.**
- [ ] **Step 3: Implement** `HammerCurve.luau`:

```lua
--!strict
-- The Water Hammer's arm state as a pure function of phase + time (spec §5).
-- The arm IS the round countdown: it cranks from rest to apex over ACTIVE,
-- latches at lockout (T0-2s), trembles through TALLY, releases at REVEAL.
local HammerCurve = {}

export type Cfg = { activeSeconds: number, lockoutLeadSec: number, restDeg: number, apexDeg: number }
export type State = { angleDeg: number, latched: boolean, trembling: boolean, released: boolean }

local DEFAULT: Cfg = { activeSeconds = 20, lockoutLeadSec = 2, restDeg = -75, apexDeg = 55 }

function HammerCurve.state(phase: string, secondsLeft: number, cfg: Cfg?): State
    local c = cfg or DEFAULT
    if phase == "REVEAL" then
        return { angleDeg = c.apexDeg, latched = false, trembling = false, released = true }
    end
    if phase == "TALLY" then
        return { angleDeg = c.apexDeg, latched = true, trembling = true, released = false }
    end
    local crank = c.activeSeconds - c.lockoutLeadSec
    local elapsed = c.activeSeconds - secondsLeft
    local p = math.clamp(elapsed / crank, 0, 1)
    return {
        angleDeg = c.restDeg + (c.apexDeg - c.restDeg) * p,
        latched = secondsLeft <= c.lockoutLeadSec,
        trembling = false,
        released = false,
    }
end

return HammerCurve
```

- [ ] **Step 4: Run → `97 passed`.** Lint/format clean.
- [ ] **Step 5: Commit** — `git add roblox/src/shared/HammerCurve.luau roblox/tests/HammerCurve.spec.luau && git commit -m "feat(roblox): HammerCurve - diegetic countdown arm state"`

### Task 6: DoomEscalation

**Files:**
- Create: `roblox/src/shared/DoomEscalation.luau`
- Test: `roblox/tests/DoomEscalation.spec.luau`

- [ ] **Step 1: Failing test:**

```lua
--!strict
local harness = require("./harness")
local Doom = require("../src/shared/DoomEscalation")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("DoomEscalation", function()
    test("stage grows every 5 seconds", function()
        expect(Doom.stageAt(0)).toBe(1)
        expect(Doom.stageAt(4.9)).toBe(1)
        expect(Doom.stageAt(5)).toBe(2)
        expect(Doom.stageAt(23)).toBe(5)
    end)

    test("spawn interval shrinks per stage but floors at the minimum", function()
        local s1 = Doom.spawnInterval("fateBoulder", 1)
        local s3 = Doom.spawnInterval("fateBoulder", 3)
        expect(s1).toBe(2.5)
        expect(s3 < s1).toBe(true)
        expect(Doom.spawnInterval("fateBoulder", 50)).toBe(0.6) -- floor
    end)

    test("entity cap rises with stage and plateaus", function()
        expect(Doom.entityCap("fatePaper", 1)).toBe(2)
        expect(Doom.entityCap("fatePaper", 10)).toBe(20)
        expect(Doom.entityCap("fatePaper", 100)).toBe(40) -- plateau (spec: ~40 sheets)
        expect(Doom.entityCap("fateBoulder", 100)).toBe(6)
        expect(Doom.entityCap("fateShears", 100)).toBe(8)
    end)

    test("homing step moves toward the target at speed*dt and never overshoots", function()
        local p = Doom.homingStep({ x = 0, y = 0, z = 0 }, { x = 10, y = 0, z = 0 }, 5, 1)
        expect(p.x).toBe(5)
        local q = Doom.homingStep({ x = 9, y = 0, z = 0 }, { x = 10, y = 0, z = 0 }, 5, 1)
        expect(q.x).toBe(10) -- clamped at target
    end)

    test("zero-distance homing is a no-op (no NaN)", function()
        local p = Doom.homingStep({ x = 1, y = 2, z = 3 }, { x = 1, y = 2, z = 3 }, 5, 1)
        expect(p).toEqual({ x = 1, y = 2, z = 3 })
    end)

    test("standing still triggers fast catch after 1.5s; moving does not", function()
        expect(Doom.shouldFastCatch(0.5, 2)).toBe(true)
        expect(Doom.shouldFastCatch(0.5, 1)).toBe(false)
        expect(Doom.shouldFastCatch(12, 30)).toBe(false)
    end)
end)
```

- [ ] **Step 2: Run; fail.**
- [ ] **Step 3: Implement** `DoomEscalation.luau`:

```lua
--!strict
-- Pursuit math for the Three Fates (spec §6.1). Pure: positions are {x,y,z}
-- tables; the client controller converts to/from Vector3. No guaranteed catch:
-- intensity escalates and plateaus; contact (or acceptance) ends the flight.
local DoomEscalation = {}

local STAGE_SECONDS = 5
local FAST_CATCH_SPEED = 1 -- studs/sec: "standing still"
local FAST_CATCH_AFTER = 1.5

DoomEscalation.CONFIG = {
    fateBoulder = { plateau = 6, baseSpawnSec = 2.5, minSpawnSec = 0.6, baseSpeed = 14, speedPerStage = 3 },
    fatePaper = { plateau = 40, baseSpawnSec = 0.8, minSpawnSec = 0.15, baseSpeed = 16, speedPerStage = 2 },
    fateShears = { plateau = 8, baseSpawnSec = 2.0, minSpawnSec = 0.5, baseSpeed = 0, speedPerStage = 0 },
}

export type Vec = { x: number, y: number, z: number }

function DoomEscalation.stageAt(elapsedSec: number): number
    return 1 + math.floor(elapsedSec / STAGE_SECONDS)
end

function DoomEscalation.spawnInterval(fateId: string, stage: number): number
    local c = DoomEscalation.CONFIG[fateId]
    return math.max(c.minSpawnSec, c.baseSpawnSec * 0.7 ^ (stage - 1))
end

function DoomEscalation.entityCap(fateId: string, stage: number): number
    local c = DoomEscalation.CONFIG[fateId]
    return math.min(c.plateau, 2 * stage)
end

function DoomEscalation.speed(fateId: string, stage: number): number
    local c = DoomEscalation.CONFIG[fateId]
    return c.baseSpeed + c.speedPerStage * (stage - 1)
end

function DoomEscalation.homingStep(pos: Vec, target: Vec, speed: number, dt: number): Vec
    local dx, dy, dz = target.x - pos.x, target.y - pos.y, target.z - pos.z
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    local stepLen = speed * dt
    if dist <= stepLen or dist == 0 then
        return { x = target.x, y = target.y, z = target.z }
    end
    local s = stepLen / dist
    return { x = pos.x + dx * s, y = pos.y + dy * s, z = pos.z + dz * s }
end

function DoomEscalation.shouldFastCatch(victimSpeed: number, elapsedSec: number): boolean
    return victimSpeed < FAST_CATCH_SPEED and elapsedSec > FAST_CATCH_AFTER
end

return DoomEscalation
```

- [ ] **Step 4: Run → `103 passed`.** Lint/format clean. (Check the entityCap test: `2 * stage` capped at plateau gives 2/20/40 for paper stages 1/10/100 ✓, 6 for boulder ✓, 8 for shears ✓.)
- [ ] **Step 5: Commit** — `git add roblox/src/shared/DoomEscalation.luau roblox/tests/DoomEscalation.spec.luau && git commit -m "feat(roblox): DoomEscalation - stages, plateaus, homing, fast-catch"`

### Task 7: ChoreographyMachine

**Files:**
- Create: `roblox/src/shared/ChoreographyMachine.luau`
- Test: `roblox/tests/ChoreographyMachine.spec.luau`

- [ ] **Step 1: Failing test:**

```lua
--!strict
local harness = require("./harness")
local Choreo = require("../src/shared/ChoreographyMachine")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function fixedSelect(slot: string, ctx: any): string?
    if slot == "LOSS" then
        return "fate" .. ctx.worldThrow
    end
    return slot:lower()
end

local OPTS = { staggerMaxMs = 600, random = function()
    return 0.5
end, selectEffect = fixedSelect }

describe("ChoreographyMachine.phaseCues", function()
    test("ACTIVE and TALLY cue sets", function()
        expect(Choreo.phaseCues("ACTIVE")).toEqual({ "lanternsAmbient", "hammerReset", "tickerCountdown" })
        expect(Choreo.phaseCues("TALLY")).toEqual({ "lanternsDim", "drumrollStart", "heroTileSpin", "tickerCascade" })
        expect(Choreo.phaseCues("REVEAL")).toEqual({})
    end)
end)

describe("ChoreographyMachine.revealCues", function()
    local reveal = {
        worldThrow = "S",
        results = { ["9"] = { result = "WIN", pick = "R" }, ["10"] = { result = "LOSS", pick = "P" } },
        whiffed = { ["11"] = true },
    }

    test("base cues fire at t=0 and consequences are staggered", function()
        local cues = Choreo.revealCues(reveal, OPTS)
        expect(cues[1].atMs).toBe(0)
        local kinds = {}
        for _, c in cues do
            if c.atMs == 0 then
                table.insert(kinds, c.kind)
            end
        end
        expect(kinds).toEqual({ "drumrollStop", "gongStrike", "basinErupt", "heroTileLand" })
    end)

    test("each participant gets one consequence cue with the selected effect", function()
        local cues = Choreo.revealCues(reveal, OPTS)
        local byUser = {}
        for _, c in cues do
            if c.kind == "consequence" then
                byUser[c.userId] = c
            end
        end
        expect(byUser["9"].effect).toBe("win")
        expect(byUser["10"].effect).toBe("fateS")
        expect(byUser["9"].atMs).toBe(300) -- random 0.5 * 600
    end)

    test("whiffed users get a whiffToast cue", function()
        local cues = Choreo.revealCues(reveal, OPTS)
        local found = false
        for _, c in cues do
            if c.kind == "whiffToast" and c.userId == "11" then
                found = true
            end
        end
        expect(found).toBe(true)
    end)

    test("cues are sorted by atMs", function()
        local cues = Choreo.revealCues(reveal, OPTS)
        for i = 2, #cues do
            expect(cues[i].atMs >= cues[i - 1].atMs).toBe(true)
        end
    end)

    test("heroTileLand carries the world throw", function()
        local cues = Choreo.revealCues(reveal, OPTS)
        for _, c in cues do
            if c.kind == "heroTileLand" then
                expect(c.worldThrow).toBe("S")
            end
        end
    end)
end)
```

- [ ] **Step 2: Run; fail.**
- [ ] **Step 3: Implement** `ChoreographyMachine.luau`:

```lua
--!strict
-- Turns phase changes and reveals into ordered effect cues (spec §6/§8).
-- Pure: the client TheaterController executes cues with task.delay.
local ChoreographyMachine = {}

export type Cue = { atMs: number, kind: string, userId: string?, effect: string?, worldThrow: string? }
export type Opts = { staggerMaxMs: number, random: () -> number, selectEffect: (slot: string, ctx: any) -> string? }

local PHASE_CUES: { [string]: { string } } = {
    ACTIVE = { "lanternsAmbient", "hammerReset", "tickerCountdown" },
    TALLY = { "lanternsDim", "drumrollStart", "heroTileSpin", "tickerCascade" },
    REVEAL = {},
}

function ChoreographyMachine.phaseCues(phase: string): { string }
    return PHASE_CUES[phase] or {}
end

function ChoreographyMachine.revealCues(reveal: any, opts: Opts): { Cue }
    local cues: { Cue } = {
        { atMs = 0, kind = "drumrollStop" },
        { atMs = 0, kind = "gongStrike" },
        { atMs = 0, kind = "basinErupt" },
        { atMs = 0, kind = "heroTileLand", worldThrow = reveal.worldThrow },
    }

    local userIds: { string } = {}
    for userId in reveal.results do
        table.insert(userIds, userId)
    end
    table.sort(userIds) -- deterministic order before randomized stagger

    for _, userId in userIds do
        local r = reveal.results[userId]
        cues[#cues + 1] = {
            atMs = math.floor(opts.random() * opts.staggerMaxMs),
            kind = "consequence",
            userId = userId,
            effect = opts.selectEffect(r.result, { worldThrow = reveal.worldThrow }),
        }
    end

    if reveal.whiffed then
        for userId in reveal.whiffed do
            cues[#cues + 1] = { atMs = 200, kind = "whiffToast", userId = userId }
        end
    end

    table.sort(cues, function(a, b)
        return a.atMs < b.atMs
    end)
    return cues
end

return ChoreographyMachine
```

- [ ] **Step 4: Run → `108 passed`.** Lint/format clean. (NOTE: the base-cues test requires stable order among atMs=0 ties — `table.sort` is not stable in Luau. Fix: sort with a tiebreaker on insertion index. Implementation detail: build cues with an `idx` field, sort by `(atMs, idx)`, then strip `idx` — include this in the implementation if the test flakes; the test's expected base-cue order is the contract.)
- [ ] **Step 5: Commit** — `git add roblox/src/shared/ChoreographyMachine.luau roblox/tests/ChoreographyMachine.spec.luau && git commit -m "feat(roblox): ChoreographyMachine - phase + reveal cue scheduling"`

### Task 8: FateRegistry

**Files:**
- Create: `roblox/src/shared/FateRegistry.luau`
- Test: `roblox/tests/FateRegistry.spec.luau`

- [ ] **Step 1: Failing test:**

```lua
--!strict
local harness = require("./harness")
local FateRegistry = require("../src/shared/FateRegistry")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("FateRegistry", function()
    test("begin binds; isBound reflects it", function()
        local r = FateRegistry.new()
        expect(r:isBound("9")).toBe(false)
        r:begin("9")
        expect(r:isBound("9")).toBe(true)
    end)

    test("resolve unbinds and reports whether the user was bound", function()
        local r = FateRegistry.new()
        r:begin("9")
        expect(r:resolve("9")).toBe(true)
        expect(r:isBound("9")).toBe(false)
        expect(r:resolve("9")).toBe(false) -- double-resolve is safe
    end)

    test("bindings are per-user", function()
        local r = FateRegistry.new()
        r:begin("9")
        expect(r:isBound("10")).toBe(false)
    end)

    test("remove clears a user without resolution semantics (player left)", function()
        local r = FateRegistry.new()
        r:begin("9")
        r:remove("9")
        expect(r:isBound("9")).toBe(false)
    end)
end)
```

- [ ] **Step 2: Run; fail.**
- [ ] **Step 3: Implement** `FateRegistry.luau`:

```lua
--!strict
-- Tracks fate-bound players (spec §6.1): while bound, the server refuses
-- their throws — you can't play until you face your fate.
local FateRegistry = {}
FateRegistry.__index = FateRegistry

function FateRegistry.new()
    return setmetatable({ _bound = {} :: { [string]: boolean } }, FateRegistry)
end

function FateRegistry.begin(self: any, userId: string)
    self._bound[userId] = true
end

function FateRegistry.isBound(self: any, userId: string): boolean
    return self._bound[userId] == true
end

function FateRegistry.resolve(self: any, userId: string): boolean
    local was = self._bound[userId] == true
    self._bound[userId] = nil
    return was
end

function FateRegistry.remove(self: any, userId: string)
    self._bound[userId] = nil
end

return FateRegistry
```

- [ ] **Step 4: Run → `112 passed`.** Lint/format clean.
- [ ] **Step 5: Commit** — `git add roblox/src/shared/FateRegistry.luau roblox/tests/FateRegistry.spec.luau && git commit -m "feat(roblox): FateRegistry - the no-throw-while-doomed gate"`

### Task 9: Remotes, stage parts, server composition v3

**Files:**
- Modify: `roblox/default.project.json`, `roblox/src/server/main.server.luau`

- [ ] **Step 1: project json.** In `RoshamboRemotes` add three RemoteEvents: `"RevealTheater": { "$className": "RemoteEvent" }`, `"FateResolved": { "$className": "RemoteEvent" }`, `"BoardData": { "$className": "RemoteEvent" }`. Add a Workspace stage (sibling of HttpService etc. at tree level):

```json
        "Workspace": {
            "$className": "Workspace",
            "RoshamboStage": {
                "$className": "Folder",
                "JumbotronBoard": {
                    "$className": "Part",
                    "$properties": {
                        "Anchored": true, "Size": [28, 9, 1], "CFrame": [0, 24, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1],
                        "Color": [0.16, 0.13, 0.09]
                    }
                },
                "HammerArm": {
                    "$className": "Part",
                    "$properties": {
                        "Anchored": true, "Size": [0.8, 0.8, 9], "CFrame": [8, 8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1],
                        "Color": [0.54, 0.43, 0.27]
                    }
                },
                "GongPad": {
                    "$className": "Part",
                    "$properties": {
                        "Anchored": true, "Size": [6, 6, 0.6], "CFrame": [14, 6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1],
                        "Color": [0.79, 0.64, 0.42], "Shape": "Cylinder"
                    }
                }
            }
        },
```

(4b replaces these with art; positions are rough — adjust freely in the live check.)

- [ ] **Step 2: main.server.luau v3.** Apply these changes (full replacement blocks):

At requires, add:

```lua
local ThemeManifest = require(shared:WaitForChild("ThemeManifest"))
local ZenDojo = require(shared:WaitForChild("themes"):WaitForChild("ZenDojo"))
local FateRegistry = require(shared:WaitForChild("FateRegistry"))
```

After remotes block, add:

```lua
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent
local FateResolved = remotes:WaitForChild("FateResolved") :: RemoteEvent
local BoardData = remotes:WaitForChild("BoardData") :: RemoteEvent
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
```

After config require, add theme boot validation (loud failure per spec §8):

```lua
local themeOk, themeErrs = ThemeManifest.validate(ZenDojo)
if not themeOk then
    error("[THEME] ZenDojo invalid: " .. table.concat(themeErrs, "; "))
end
```

After `profiles`, add:

```lua
local fates = FateRegistry.new()

local function applyGrow(player: Player)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end
    for _, name in { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" } do
        local v = humanoid:FindFirstChild(name) :: NumberValue?
        if v then
            local up = TweenService:Create(v, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1.6 })
            up:Play()
            task.delay(8, function()
                TweenService:Create(v, TweenInfo.new(1.2), { Value = 1 }):Play()
            end)
        end
    end
end

local EPITHET = "A WANDERER"
local function filterExternalName(name: string): string
    local anyPlayer = Players:GetPlayers()[1]
    if not anyPlayer then
        return EPITHET
    end
    local ok, result = pcall(function()
        local r = TextService:FilterStringAsync(name, anyPlayer.UserId)
        return r:GetNonChatStringForBroadcastAsync()
    end)
    if not ok or result:find("#") then
        return EPITHET
    end
    return result
end
```

In the coordinator callbacks, REPLACE `onReveal` with:

```lua
        onReveal = function(reveal)
            RevealTheater:FireAllClients({
                worldThrow = reveal.worldThrow,
                distribution = reveal.distribution,
                totalPlayers = reveal.totalPlayers,
                results = reveal.results,
                whiffed = reveal.whiffed,
            })
            for _, player in Players:GetPlayers() do
                local userId = tostring(player.UserId)
                local mine = reveal.results[userId]
                RevealResult:FireClient(player, {
                    worldThrow = reveal.worldThrow,
                    distribution = reveal.distribution,
                    totalPlayers = reveal.totalPlayers,
                    pick = mine and mine.pick,
                    result = mine and mine.result,
                })
                if mine then
                    profiles:applyLocalResult(userId, mine.result)
                    pushStats(player)
                    fireProfile(player, "local")
                    if mine.result == "WIN" then
                        applyGrow(player)
                    elseif mine.result == "LOSS" then
                        fates:begin(userId)
                    end
                end
            end
        end,
```

And `onRound` gains board tape relay — REPLACE with:

```lua
        onRound = function(info)
            RoundUpdate:FireAllClients(info)
            if info.tape then
                lastTape = info.tape
            end
        end,
```

(declare `local lastTape: any = {}` above the coordinator construction).

In the `SubmitPick` handler, ADD the gate before `coordinator:submitPick`:

```lua
    if fates:isBound(tostring(player.UserId)) then
        print(`[PICK] {player.Name} rejected: FATE_BOUND`)
        return
    end
```

After the BankRequest handler, add the FateResolved handler and board loop:

```lua
FateResolved.OnServerEvent:Connect(function(player, reason)
    if reason ~= "caught" and reason ~= "accepted" then
        return
    end
    local userId = tostring(player.UserId)
    if fates:resolve(userId) then
        FateResolved:FireAllClients(userId, reason)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    fates:remove(tostring(player.UserId))
end)

local lastBoard: any = nil
task.spawn(function()
    while true do
        local res = net:getLeaderboards("world")
        local worldRec, hotStreak = nil, nil
        if res.ok and res.data.leaders then
            local top = res.data.leaders[1]
            if top then
                worldRec = { points = top.totalPoints, name = filterExternalName(top.displayName or "?") }
            end
            local best, bestName = 0, nil
            for _, l in res.data.leaders do
                if (l.currentStreak or 0) > best then
                    best, bestName = l.currentStreak, l.displayName
                end
            end
            if bestName then
                hotStreak = { streak = best, name = filterExternalName(bestName) }
            end
        end
        lastBoard = {
            tape = lastTape,
            worldRec = worldRec,
            hotStreak = hotStreak,
            playersNow = (lastTape[1] and lastTape[1].totalPlayers) or 0,
        }
        BoardData:FireAllClients(lastBoard)
        task.wait(30)
    end
end)

Players.PlayerAdded:Connect(function(player)
    if lastBoard then
        BoardData:FireClient(player, lastBoard)
    end
end)
```

Note: `playersNow` is the latest round's global participant count — the honest number available without presence infrastructure (deviation from "live player count" recorded; a true concurrent count needs presence infra, deferred).

- [ ] **Step 3: Verify** — `rojo build -o build.rbxl` exit 0; `lune run tests/run` still 112; lint/format clean.
- [ ] **Step 4: Commit** — `git add roblox/default.project.json roblox/src/server/main.server.luau && git commit -m "feat(roblox): server composition v3 - theater broadcast, fate gate, grow, board feed"`

### Task 10: BoardController (client)

**Files:**
- Create: `roblox/src/client/EventBus.luau`, `roblox/src/client/BoardController.client.luau`

- [ ] **Step 1: Create `EventBus.luau`** (shared client-side cue bus):

```lua
--!strict
-- Client-local BindableEvents so controllers stay decoupled.
local bus: { [string]: BindableEvent } = {}
local NAMES = { "Cue", "TickerMessage" }
for _, name in NAMES do
    local e = Instance.new("BindableEvent")
    e.Name = name
    bus[name] = e
end
return bus
```

- [ ] **Step 2: Create `BoardController.client.luau`:**

```lua
--!strict
-- Renders the split-flap jumbotron on the placeholder board part (spec §4).
-- Placeholder fidelity: one TextLabel per cell with a Y-squash tween standing
-- in for the fold illusion; 4b dresses this without changing the scheduling.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local FlapScheduler = require(shared:WaitForChild("FlapScheduler"))
local ZenDojo = require(shared:WaitForChild("themes"):WaitForChild("ZenDojo"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local BoardData = remotes:WaitForChild("BoardData") :: RemoteEvent
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent

local board = workspace:WaitForChild("RoshamboStage"):WaitForChild("JumbotronBoard")

local COLS = 28
local ROWS = { "LAST5", "WORLDREC", "HOTSTREAK", "PLAYERS", "TICKER1", "TICKER2" }
local GLYPH = { R = "○", P = "─", S = "∧" }

local faces: { { { TextLabel } } } = {} -- face -> row -> col
local current: { [number]: string } = {} -- row -> displayed line

local function buildFace(faceEnum: Enum.NormalId): { { TextLabel } }
    local gui = Instance.new("SurfaceGui")
    gui.Face = faceEnum
    gui.CanvasSize = Vector2.new(1120, 360)
    gui.Parent = board
    local grid: { { TextLabel } } = {}
    for r = 1, #ROWS do
        grid[r] = {}
        for c = 1, COLS do
            local cell = Instance.new("TextLabel")
            cell.Size = UDim2.fromOffset(36, 52)
            cell.Position = UDim2.fromOffset((c - 1) * 40 + 4, (r - 1) * 58 + 6)
            cell.BackgroundColor3 = Color3.fromRGB(244, 238, 222)
            cell.TextColor3 = Color3.fromRGB(58, 46, 30)
            cell.TextSize = 30
            cell.Font = Enum.Font.RobotoMono
            cell.Text = " "
            cell.Parent = gui
            grid[r][c] = cell
        end
    end
    return grid
end

local function flapTo(row: number, cell: TextLabel, char: string)
    local squash = TweenService:Create(cell, TweenInfo.new(0.04), { Size = UDim2.fromOffset(36, 4) })
    squash:Play()
    squash.Completed:Once(function()
        cell.Text = char
        TweenService:Create(cell, TweenInfo.new(0.04), { Size = UDim2.fromOffset(36, 52) }):Play()
    end)
end

local function setRow(row: number, line: string)
    -- No byte-based truncation: a :sub() could split a multibyte glyph and
    -- crash utf8.codes. Steps for columns beyond COLS are dropped by the
    -- nil-cell guard below.
    local target = line
    local plan = FlapScheduler.plan(current[row] or "", target)
    current[row] = target
    for _, step in plan do
        task.delay(step.atMs / 1000, function()
            for _, grid in faces do
                local cell = grid[row][step.col]
                if cell then
                    flapTo(row, cell, step.char)
                end
            end
        end)
    end
end

faces[1] = buildFace(Enum.NormalId.Front)
faces[2] = buildFace(Enum.NormalId.Back)

BoardData.OnClientEvent:Connect(function(d)
    local tape = ""
    for i = 1, math.min(5, #(d.tape or {})) do
        tape ..= (GLYPH[d.tape[i].worldThrow] or "?") .. " "
    end
    setRow(1, "LAST5 " .. tape)
    if d.worldRec then
        setRow(2, `REC {d.worldRec.points} {d.worldRec.name}`)
    end
    if d.hotStreak then
        setRow(3, `HOT {d.hotStreak.streak} {d.hotStreak.name}`)
    end
    setRow(4, `PLAYERS {d.playersNow}`)
end)

RoundUpdate.OnClientEvent:Connect(function(info)
    if info.phase == "ACTIVE" then
        setRow(5, "THE WORLD CHOOSES SOON")
    elseif info.phase == "TALLY" then
        setRow(5, "THE WORLD CHOOSES NOW")
    end
end)

RevealTheater.OnClientEvent:Connect(function(r)
    setRow(6, `WORLD THREW {GLYPH[r.worldThrow] or "?"}`)
end)

EventBus.TickerMessage.Event:Connect(function(line: string)
    setRow(5, line)
end)
```

- [ ] **Step 3: Verify** — `rojo build` exit 0; tests still 112; lint clean (selene: `workspace` is a roblox global, accepted).
- [ ] **Step 4: Commit** — `git add roblox/src/client/EventBus.luau roblox/src/client/BoardController.client.luau && git commit -m "feat(roblox): BoardController - flap board renderer on placeholder part"`

### Task 11: HammerController + TheaterController (client)

**Files:**
- Create: `roblox/src/client/HammerController.client.luau`, `roblox/src/client/TheaterController.client.luau`

- [ ] **Step 1: Create `HammerController.client.luau`:**

```lua
--!strict
-- Animates the placeholder hammer arm from HammerCurve and fires the gong
-- placeholder on reveal. 4b swaps parts for art; the curve stays.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local HammerCurve = require(shared:WaitForChild("HammerCurve"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent

local stage = workspace:WaitForChild("RoshamboStage")
local arm = stage:WaitForChild("HammerArm") :: BasePart
local gong = stage:WaitForChild("GongPad") :: BasePart
local pivot = arm.CFrame * CFrame.new(0, 0, arm.Size.Z / 2) -- hinge at the arm's rear end

local lastPhase = "ACTIVE"
local secondsToLockout: number? = nil
local phaseAt = os.clock()
local wasLatched = false

RoundUpdate.OnClientEvent:Connect(function(info)
    lastPhase = info.phase
    secondsToLockout = info.secondsToLockout
    phaseAt = os.clock()
    if info.phase == "ACTIVE" then
        wasLatched = false
    end
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "gongStrike" then
        TweenService:Create(arm, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            CFrame = pivot * CFrame.Angles(math.rad(-20), 0, 0) * CFrame.new(0, 0, -arm.Size.Z / 2),
        }):Play()
        local light = Instance.new("PointLight")
        light.Brightness = 12
        light.Range = 30
        light.Parent = gong
        task.delay(0.6, function()
            light:Destroy()
        end)
    elseif cue.kind == "basinErupt" then
        local ring = Instance.new("Part")
        ring.Shape = Enum.PartType.Cylinder
        ring.Anchored = true
        ring.CanCollide = false
        ring.Transparency = 0.5
        ring.Color = Color3.fromRGB(127, 180, 201)
        ring.Size = Vector3.new(0.3, 2, 2)
        ring.CFrame = gong.CFrame * CFrame.new(0, -4, 0) * CFrame.Angles(0, 0, math.rad(90))
        ring.Parent = workspace
        TweenService:Create(ring, TweenInfo.new(1.2), { Size = Vector3.new(0.3, 26, 26), Transparency = 1 }):Play()
        task.delay(1.3, function()
            ring:Destroy()
        end)
    end
end)

RunService.Heartbeat:Connect(function()
    local secondsLeft: number
    if lastPhase == "ACTIVE" then
        local lead = 2
        local toLockout = math.max(0, (secondsToLockout or 18) - (os.clock() - phaseAt))
        secondsLeft = toLockout + lead
    else
        secondsLeft = 1
    end
    local state = HammerCurve.state(lastPhase, secondsLeft)
    if not state.released then
        local tremble = if state.trembling then math.rad((math.random() - 0.5) * 2) else 0
        arm.CFrame = pivot
            * CFrame.Angles(math.rad(state.angleDeg) + tremble, 0, 0)
            * CFrame.new(0, 0, -arm.Size.Z / 2)
        if state.latched and not wasLatched then
            wasLatched = true
            EventBus.Cue:Fire({ kind = "latchClick" })
        end
    end
end)
```

- [ ] **Step 2: Create `TheaterController.client.luau`:**

```lua
--!strict
-- Executes choreography cues: builds the cue schedule from RevealTheater and
-- phase changes, fires them onto the EventBus, and plays the simple
-- placeholder consequence effects (petals, umbrella). Fates are handled by
-- FateController; UI toasts by main.client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local Choreo = require(shared:WaitForChild("ChoreographyMachine"))
local EffectRegistry = require(shared:WaitForChild("EffectRegistry"))
local EffectSelector = require(shared:WaitForChild("EffectSelector"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent

local selector = EffectSelector.new(EffectRegistry, { random = math.random })

local function characterOf(userId: string): Model?
    for _, p in Players:GetPlayers() do
        if tostring(p.UserId) == userId then
            return p.Character
        end
    end
    return nil
end

local function petals(character: Model)
    local head = character:FindFirstChild("Head") :: BasePart?
    if not head then
        return
    end
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(Color3.fromRGB(255, 217, 138))
    emitter.Lifetime = NumberRange.new(1, 1.8)
    emitter.Speed = NumberRange.new(4, 7)
    emitter.Rate = 0
    emitter.Parent = head
    emitter:Emit(30)
    task.delay(2.5, function()
        emitter:Destroy()
    end)
end

local function umbrella(character: Model)
    local head = character:FindFirstChild("Head") :: BasePart?
    if not head then
        return
    end
    local canopy = Instance.new("Part")
    canopy.Shape = Enum.PartType.Cylinder
    canopy.Anchored = true
    canopy.CanCollide = false
    canopy.Color = Color3.fromRGB(179, 74, 58)
    canopy.Size = Vector3.new(0.4, 0.5, 0.5)
    canopy.CFrame = head.CFrame * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90))
    canopy.Parent = workspace
    TweenService:Create(canopy, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = Vector3.new(0.4, 6, 6) }):Play()
    task.delay(2, function()
        TweenService:Create(canopy, TweenInfo.new(0.3), { Size = Vector3.new(0.4, 0.5, 0.5), Transparency = 1 }):Play()
        task.delay(0.35, function()
            canopy:Destroy()
        end)
    end)
end

local function execute(cue: any)
    EventBus.Cue:Fire(cue)
    if cue.kind == "consequence" then
        local character = characterOf(cue.userId)
        if not character then
            return
        end
        if cue.effect == "growPetals" then
            petals(character) -- the grow itself is server-side (replicated scale)
        elseif cue.effect == "umbrellaPop" then
            umbrella(character)
        end
        -- fate* effects are consumed by FateController via the same Cue event
    end
end

RoundUpdate.OnClientEvent:Connect(function(info)
    for _, kind in Choreo.phaseCues(info.phase) do
        EventBus.Cue:Fire({ kind = kind })
    end
end)

RevealTheater.OnClientEvent:Connect(function(reveal)
    local cues = Choreo.revealCues(reveal, {
        staggerMaxMs = 600,
        random = math.random,
        selectEffect = function(slot, ctx)
            return selector:select(slot, ctx)
        end,
    })
    for _, cue in cues do
        task.delay(cue.atMs / 1000, execute, cue)
    end
end)
```

- [ ] **Step 3: Verify** — `rojo build` exit 0; tests 112; lint/format clean.
- [ ] **Step 4: Commit** — `git add roblox/src/client/HammerController.client.luau roblox/src/client/TheaterController.client.luau && git commit -m "feat(roblox): hammer + theater controllers - cues, gong, basin, petals, umbrella"`

### Task 12: FateController + fate-bound UI

**Files:**
- Create: `roblox/src/client/FateController.client.luau`
- Modify: `roblox/src/client/main.client.luau`

- [ ] **Step 1: Create `FateController.client.luau`:**

```lua
--!strict
-- The Three Fates (spec §6.1), placeholder visuals. Per-victim authority:
-- the LOCAL player's pursuit is simulated here authoritatively (contact or
-- acceptance fires FateResolved); other victims' dooms are approximations
-- that snap on the broadcast.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local Doom = require(shared:WaitForChild("DoomEscalation"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local FateResolved = remotes:WaitForChild("FateResolved") :: RemoteEvent

local localPlayer = Players.LocalPlayer

type Flight = {
    userId: string,
    fateId: string,
    startedAt: number,
    lastSpawn: number,
    entities: { BasePart },
    accepted: boolean,
}
local flights: { [string]: Flight } = {}

local function characterOf(userId: string): Model?
    for _, p in Players:GetPlayers() do
        if tostring(p.UserId) == userId then
            return p.Character
        end
    end
    return nil
end

local function makeEntity(fateId: string, near: Vector3): BasePart
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    if fateId == "fateBoulder" then
        part.Shape = Enum.PartType.Ball
        part.Size = Vector3.new(6, 6, 6)
        part.Color = Color3.fromRGB(110, 105, 95)
        part.Position = near + Vector3.new(math.random(-8, 8), 40, math.random(-8, 8))
    elseif fateId == "fatePaper" then
        part.Size = Vector3.new(2.4, 0.1, 3.2)
        part.Color = Color3.fromRGB(245, 239, 223)
        part.Position = near + Vector3.new(math.random(-20, 20), math.random(4, 10), math.random(-20, 20))
    else -- fateShears: rises from the ground ahead
        part.Size = Vector3.new(0.6, 4, 1.6)
        part.Color = Color3.fromRGB(180, 184, 190)
        part.Position = near + Vector3.new(math.random(-10, 10), -3, math.random(-10, 10))
        TweenService:Create(part, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Position = part.Position + Vector3.new(0, 4, 0) }):Play()
    end
    part.Parent = workspace
    return part
end

local function squash(character: Model)
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if root then
        local dust = Instance.new("ParticleEmitter")
        dust.Rate = 0
        dust.Lifetime = NumberRange.new(0.5, 1)
        dust.Parent = root
        dust:Emit(20)
        task.delay(1.2, function()
            dust:Destroy()
        end)
    end
end

local function endFlight(userId: string)
    local flight = flights[userId]
    if not flight then
        return
    end
    for _, e in flight.entities do
        e:Destroy()
    end
    flights[userId] = nil
    local character = characterOf(userId)
    if character then
        squash(character)
    end
end

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "consequence" and cue.effect and cue.effect:sub(1, 4) == "fate" then
        flights[cue.userId] = {
            userId = cue.userId,
            fateId = cue.effect,
            startedAt = os.clock(),
            lastSpawn = 0,
            entities = {},
            accepted = false,
        }
    elseif cue.kind == "acceptFate" then
        local flight = flights[tostring(localPlayer.UserId)]
        if flight then
            flight.accepted = true
        end
    end
end)

FateResolved.OnClientEvent:Connect(function(userId: string)
    endFlight(userId)
end)

RunService.Heartbeat:Connect(function(dt)
    for userId, flight in flights do
        local character = characterOf(userId)
        local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not root then
            continue
        end
        local now = os.clock()
        local elapsed = now - flight.startedAt
        local stage = Doom.stageAt(elapsed)

        if now - flight.lastSpawn >= Doom.spawnInterval(flight.fateId, stage)
            and #flight.entities < Doom.entityCap(flight.fateId, stage) then
            flight.lastSpawn = now
            table.insert(flight.entities, makeEntity(flight.fateId, root.Position))
        end

        local speed = Doom.speed(flight.fateId, stage)
        local isLocal = userId == tostring(localPlayer.UserId)
        local caught = false
        for _, e in flight.entities do
            if flight.fateId ~= "fateShears" then
                local p = Doom.homingStep(
                    { x = e.Position.X, y = e.Position.Y, z = e.Position.Z },
                    { x = root.Position.X, y = root.Position.Y + 2, z = root.Position.Z },
                    speed,
                    dt
                )
                e.Position = Vector3.new(p.x, p.y, p.z)
            end
            if isLocal and (e.Position - root.Position).Magnitude < 3.5 then
                caught = true
            end
        end

        if isLocal then
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local victimSpeed = humanoid and humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed or 0
            if flight.accepted or caught or Doom.shouldFastCatch(victimSpeed, elapsed) then
                FateResolved:FireServer(if flight.accepted then "accepted" else "caught")
                flight.accepted = false
                flight.startedAt = now + 60 -- debounce until the broadcast clears it
            end
        end
    end
end)
```

- [ ] **Step 2: Modify `main.client.luau`** — add fate-bound state. After the `bankButton` block, add:

```lua
local acceptButton = Instance.new("TextButton")
acceptButton.Name = "AcceptFate"
acceptButton.Size = UDim2.fromOffset(180, 44)
acceptButton.AnchorPoint = Vector2.new(0, 1)
acceptButton.Position = UDim2.new(0, 16, 1, -24)
acceptButton.Text = "ACCEPT YOUR FATE"
acceptButton.TextSize = 16
acceptButton.Font = Enum.Font.GothamBold
acceptButton.TextColor3 = Color3.fromRGB(240, 234, 216)
acceptButton.BackgroundColor3 = Color3.fromRGB(90, 40, 40)
acceptButton.Visible = false
acceptButton.Parent = gui

local fateBound = false
local EventBus = require(script.Parent:WaitForChild("EventBus"))
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent
local FateResolvedEvt = remotes:WaitForChild("FateResolved") :: RemoteEvent

acceptButton.MouseButton1Click:Connect(function()
    EventBus.Cue:Fire({ kind = "acceptFate" })
end)

RevealTheater.OnClientEvent:Connect(function(r)
    local myId = tostring(player.UserId)
    local mine = r.results and r.results[myId]
    if mine and mine.result == "LOSS" then
        fateBound = true
        acceptButton.Visible = true
    end
    if r.whiffed and r.whiffed[myId] then
        resultLabel.Text = "⏳ TOO LATE — your throw didn't count"
        resultLabel.Visible = true
        task.delay(3, function()
            resultLabel.Visible = false
        end)
    end
end)

FateResolvedEvt.OnClientEvent:Connect(function(userId)
    if userId == tostring(player.UserId) then
        fateBound = false
        acceptButton.Visible = false
    end
end)
```

And in the `RoundUpdate` handler's ACTIVE branch, gate picking: change `canPick = true` to `canPick = not fateBound`, and in the countdown loop's else-branch add a fate message: when `fateBound` is true set `statusLabel.Text = "FACE YOUR FATE — accept it or be caught"` (place this check first in the loop body, before the canPick block).

- [ ] **Step 3: Verify** — `rojo build` exit 0; tests 112; lint/format clean.
- [ ] **Step 4: Commit** — `git add roblox/src/client/ && git commit -m "feat(roblox): FateController pursuits + fate-bound pick lock and Accept Fate"`

### Task 13: Live verification (USER-INTERACTIVE — controller hands to the human)

Prereqs: local backend (`docker compose up -d mongodb` + server with local env), `rojo serve` restarted (project file changed!), HttpEnabled (edit mode), Rojo reconnected so `RoshamboStage` + new remotes appear.

- [ ] Play. Watch a full round: hammer arm cranks up over ACTIVE; **latch click event** at ~T₀−2s (Output shows the cue); TALLY: arm trembles, board ticker flips "THE WORLD CHOOSES NOW"; reveal: arm swings, gong flashes, blue ring expands, ticker shows the world glyph.
- [ ] Board: LAST5 row flips with glyphs after each round; REC/HOT rows fill within ~30s; flap cascades visibly run left to right.
- [ ] Win a round (TEST_MODE cheat): your avatar grows ~1.6× with a petal burst, decays back; Pot updates.
- [ ] Lose a round: your doom appears (gray boulder rain / white sheet swarm / steel ambush snips per world throw); RUN — entities multiply and accelerate; pick buttons are LOCKED with "FACE YOUR FATE"; verify you cannot submit a pick.
- [ ] Click ACCEPT YOUR FATE → caught instantly → squash poff → next round you can pick again.
- [ ] Let yourself get caught while running (don't accept) → same unlock.
- [ ] Whiff case (optional, hard to trigger manually): n/a — covered by tests.
- [ ] Two-window check if convenient (Studio "Start Server + 2 Players"): both clients see each other's grows and dooms; the catch lands simultaneously on both.
- [ ] Report deviations.

### Task 14: Docs

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1:** Append to the Roblox client architecture section: "Milestone 4a adds the arena machinery: pure modules (`FlapScheduler`, `HammerCurve`, `DoomEscalation`, `ChoreographyMachine`, `FateRegistry`, `ThemeManifest`+`themes/ZenDojo`, `EffectRegistry`/`EffectSelector`) drive client controllers (`BoardController`, `HammerController`, `TheaterController`, `FateController`) over a client-side `EventBus`. New remotes: `RevealTheater` (arena-wide results), `FateResolved` (victim-authority catch/accept), `BoardData`. Fate-bound players cannot throw until their fate resolves (server gate in `main.server.luau`). All visuals are placeholders pending milestone 4b's art pass."
- [ ] **Step 2:** Commit — `git add CLAUDE.md && git commit -m "docs: milestone 4a arena machinery notes"`

---

## Out of Scope (milestone 4b plan, written after 4a ships)

Terrain/worldbuilding (terraces, teahouses, koi pond, torii), TextChatService alcove channels, real models (wheel, hammer, gong, basin skinned mesh, authentic fate models per §6.1's table), materials/lighting/soundscape, real sound asset ids in ZenDojo, tatami watermark, hero tile physical build, two-sided board housing art, R15 pinning in Game Settings (user does it during 4b's Studio session), wind-up bow gesture.

## Verification at the End

```bash
cd roblox && lune run tests/run && stylua --check src tests && selene src && rojo build -o build.rbxl
cd ../server && npm test
```
Expected: **112 Lune tests**, 82 server tests, green CI after push, plus Task 13's live session.
