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

-- Every test above compares DECLARED against itself, so the allowlist could drift from
-- what Rojo actually mounts and nothing would notice. That is exactly what happened:
-- FallsDock was added to default.project.json on 2026-07-28 and never to the allowlist,
-- so the pre-publish gate failed on a legitimately-declared model. Read the project file.
describe("DECLARED_STAGE_CHILDREN vs default.project.json", function()
    local fs = require("@lune/fs")
    local serde = require("@lune/serde")

    local function projectStageChildren(): { string }
        local project = serde.decode("json", fs.readFile("default.project.json"))
        local stage = project.tree.Workspace.RoshamboStage
        local names = {}
        for key, value in pairs(stage) do
            -- skip Rojo's $-prefixed directives; everything else is a mounted child
            if type(key) == "string" and key:sub(1, 1) ~= "$" and type(value) == "table" then
                table.insert(names, key)
            end
        end
        table.sort(names)
        return names
    end

    test("the allowlist names exactly what Rojo mounts under RoshamboStage", function()
        local fromProject = projectStageChildren()
        local fromModule = copy(DECLARED)
        table.sort(fromModule)

        local missing, extra = {}, {}
        for _, n in fromProject do
            if not table.find(fromModule, n) then
                table.insert(missing, n)
            end
        end
        for _, n in fromModule do
            if not table.find(fromProject, n) then
                table.insert(extra, n)
            end
        end

        -- surface WHICH names drifted; a bare count tells the next person nothing
        expect(table.concat(missing, ",")).toBe("")
        expect(table.concat(extra, ",")).toBe("")
        expect(#fromModule).toBe(#fromProject)
    end)
end)
