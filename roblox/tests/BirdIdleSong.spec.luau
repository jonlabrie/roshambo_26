--!strict
-- ⚠ THE IDLE SONG'S GATE, READ FROM SOURCE — because the bug it guards against was invisible.
--
-- In `BirdController`, `resting` means "no round result pending": the bird's ordinary world
-- state, the one where it sits on a perch. It does NOT mean "in the resting orbit". The first
-- idle-song gate (2026-09-03) required `not resting`, which let an idle song fire only while a
-- WIN or LOSS was being acted out — a LOSS resolves to RESTING instantly and a WIN has its own
-- song armed — so a perched familiar could never sing idly. Two minutes of listening at three
-- opportunities a minute and a coin flip each produced nothing, and the numbers said that was
-- a gate, not luck. The owner asked for singing "as part of their perching activities", so
-- the gate must require the bird to be resting AND on a perch.
--
-- `BirdController` is a Roblox-runtime file Lune cannot execute; reading its source can, the
-- same way `BirdScaleConvention.spec` polices the profile argument.
local fs = require("@lune/fs")
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect

local CONTROLLER = "src/client/BirdController.client.luau"

-- The `if <condition> then` that immediately guards the idle-song call.
local function idleGate(): string
    local src = harness.stripComments(fs.readFile(CONTROLLER))
    local callAt = string.find(src, "sing(b, false, IDLE_SONG_CHANCE)", 1, true)
    assert(callAt, "idle-song call site not found")
    local before = string.sub(src, 1, callAt - 1)
    local ifStart = string.match(before, ".*()%f[%w]if%f[%W]")
    assert(ifStart, "no `if` before the idle-song call")
    local cond = string.sub(before, ifStart)
    cond = string.gsub(cond, "^if%s*", "")
    cond = string.gsub(cond, "%s*then%s*$", "")
    return cond
end

describe("BirdIdleSong", function()
    test("the idle song fires while the bird is RESTING (no result pending), never `not resting`", function()
        local cond = idleGate()
        expect(string.find(cond, "not resting", 1, true)).toBe(nil)
        expect(string.find(cond, "%f[%w]resting%f[%W]") ~= nil).toBe(true)
    end)

    test("the idle song requires a perch — it is a perching activity, not an orbit one", function()
        local cond = idleGate()
        expect(string.find(cond, "b.perch", 1, true) ~= nil).toBe(true)
    end)
end)
