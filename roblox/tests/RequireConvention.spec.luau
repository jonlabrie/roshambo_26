--!strict
-- ⚠ A STRING REQUIRE THAT CROSSES src/ ROOTS RESOLVES UNDER LUNE AND DIES IN ROBLOX -- and it
-- takes the entire server down with it, silently, because the failure is at require time.
--
-- 2026-08-22, `TreatmentApplier` was given `require("../shared/KamonDraw")` when the crest
-- renderer was split out. That path is correct on disk, so every one of the 1465 Lune tests
-- passed and lint was clean. In the DataModel it is nonsense: src/server is
-- `ServerScriptService.Roshambo` and src/shared is `ReplicatedStorage.RoshamboShared`, so there
-- is no `shared` sibling to walk to. `main.server` threw while loading, everything after that
-- line never ran, and the game came up with no round clock and no server contact at all. Three
-- days of play-testing would have found it; a test run never would.
--
-- Relative requires WITHIN a root stay legal -- `themes/ZenDojo` -> `../ThemeManifest` is a real
-- parent in both runtimes, and nine modules rely on it. Crossing roots must use the INSTANCE
-- form, `require(shared:WaitForChild("X"))`, which is what every other server and client file
-- already does.
local fs = require("@lune/fs")
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect

local ROOTS = { "src/shared", "src/client", "src/server" }

local function rootOf(path: string): string?
    for _, r in ROOTS do
        if string.sub(path, 1, #r + 1) == r .. "/" then
            return r
        end
    end
    return nil
end

-- "src/server/../shared/KamonDraw" -> "src/shared/KamonDraw"
local function normalise(path: string): string
    local parts: { string } = {}
    for seg in string.gmatch(path, "[^/]+") do
        if seg == ".." then
            table.remove(parts)
        elseif seg ~= "." then
            table.insert(parts, seg)
        end
    end
    return table.concat(parts, "/")
end

-- ⚠ SCAN CODE, NOT PROSE -- see `harness.stripComments`, which this shares with the bird
-- scale guard. The first version of this test grepped raw text and flagged the very comment in
-- TreatmentApplier that documents the bug.
local stripComments = harness.stripComments

local function walk(dir: string, out: { string })
    for _, name in fs.readDir(dir) do
        local p = dir .. "/" .. name
        if fs.isDir(p) then
            walk(p, out)
        elseif string.sub(p, -5) == ".luau" then
            table.insert(out, p)
        end
    end
end

describe("require convention", function()
    test("no string require crosses between src/shared, src/client and src/server", function()
        local files: { string } = {}
        for _, r in ROOTS do
            walk(r, files)
        end
        -- ⚠ the walk must actually have found the tree, or this test passes by finding nothing
        expect(#files > 50).toBe(true)

        local offenders: { string } = {}
        for _, file in files do
            local home = rootOf(file)
            local dir = string.match(file, "^(.*)/[^/]+$") or ""
            local code = stripComments(fs.readFile(file))
            for target in string.gmatch(code, 'require%("([^"]+)"%)') do
                if string.sub(target, 1, 1) == "." then
                    local lands = rootOf(normalise(dir .. "/" .. target))
                    if home and lands and lands ~= home then
                        table.insert(offenders, `{file} -> {target}`)
                    end
                end
            end
        end
        -- concatenated rather than counted, so a failure NAMES the file and the bad path
        expect(table.concat(offenders, ", ")).toBe("")
    end)
end)
