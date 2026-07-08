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
