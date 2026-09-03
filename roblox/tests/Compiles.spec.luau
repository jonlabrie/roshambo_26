--!strict
-- Every source file must COMPILE under Luau's own limits — not just parse. stylua, selene and
-- the spec suite all stayed green on 2026-09-03 while HudController exceeded the compiler's
-- 200-local-register ceiling ("Out of local registers when trying to allocate lerpNumber"),
-- so the whole script died in Studio and the owner lost the entire play HUD. None of those
-- gates compile; this one does, with the same Luau frontend Roblox runs (Lune embeds it).
-- Client/server entry files can't RUN under Lune (Roblox globals), but compiling never
-- resolves globals, so every file is checkable.
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function collect(dir: string, out: { string })
    for _, name in fs.readDir(dir) do
        local path = dir .. "/" .. name
        if fs.isDir(path) then
            collect(path, out)
        elseif name:match("%.luau$") then
            table.insert(out, path)
        end
    end
end

describe("Compiles — every src file passes the Luau compiler", function()
    local files: { string } = {}
    collect("src", files)
    test("found the source tree", function()
        expect(#files > 30).toBe(true)
    end)
    for _, path in files do
        test(path, function()
            local ok, err = pcall(function()
                -- O2 + O0 bracket what Studio (debug) and published servers actually run;
                -- register pressure is worst unoptimized.
                luau.compile(fs.readFile(path), { optimizationLevel = 0 } :: any)
                luau.compile(fs.readFile(path), { optimizationLevel = 2 } :: any)
            end)
            if not ok then
                error(`{path} failed to compile: {err}`, 0)
            end
            expect(ok).toBe(true)
        end)
    end
end)
