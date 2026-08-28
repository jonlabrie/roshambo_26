--!strict
-- Minimal jest-style test harness for Lune. Replace with Jest-Lua if it ever
-- gains Lune support (today it requires the Roblox runtime).
local harness = {}

type Test = { name: string, fn: () -> () }
local tests: { Test } = {}
local prefix = ""

function harness.describe(name: string, fn: () -> ())
    local prev = prefix
    prefix = prefix .. name .. " > "
    fn()
    prefix = prev
end

function harness.test(name: string, fn: () -> ())
    table.insert(tests, { name = prefix .. name, fn = fn })
end

local function deepEqual(a: any, b: any): boolean
    if a == b then
        return true
    end
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    for k, v in a :: { [any]: any } do
        if not deepEqual(v, (b :: { [any]: any })[k]) then
            return false
        end
    end
    for k in b :: { [any]: any } do
        if (a :: { [any]: any })[k] == nil then
            return false
        end
    end
    return true
end

local function fmt(v: any): string
    if type(v) == "table" then
        local parts = {}
        for k, val in v :: { [any]: any } do
            table.insert(parts, tostring(k) .. "=" .. fmt(val))
        end
        table.sort(parts)
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

function harness.expect(actual: any)
    return {
        toBe = function(expected: any)
            if actual ~= expected then
                error(("expected %s to be %s"):format(fmt(actual), fmt(expected)), 2)
            end
        end,
        toEqual = function(expected: any)
            if not deepEqual(actual, expected) then
                error(("expected %s to deep-equal %s"):format(fmt(actual), fmt(expected)), 2)
            end
        end,
        toBeCloseTo = function(expected: number, eps: number?)
            local e = eps or 1e-6
            if math.abs((actual :: number) - expected) > e then
                error(
                    ("expected %s to be within %s of %s"):format(fmt(actual), tostring(e), fmt(expected)),
                    2
                )
            end
        end,
        toBeTruthy = function()
            if not actual then
                error(("expected %s to be truthy"):format(fmt(actual)), 2)
            end
        end,
        toBeNil = function()
            if actual ~= nil then
                error(("expected %s to be nil"):format(fmt(actual)), 2)
            end
        end,
        toThrow = function()
            local ok = pcall(actual :: () -> ())
            if ok then
                error("expected function to throw", 2)
            end
        end,
    }
end

function harness.run(): boolean
    local passed, failed = 0, 0
    for _, t in tests do
        local ok, err = pcall(t.fn)
        if ok then
            passed += 1
        else
            failed += 1
            print(("FAIL  %s\n      %s"):format(t.name, tostring(err)))
        end
    end
    print(("\n%d passed, %d failed, %d total"):format(passed, failed, passed + failed))
    return failed == 0
end

-- ⚠ SCAN CODE, NOT PROSE. Source-scanning guards must strip comments first, or a note that
-- QUOTES the mistake it warns about fails the build -- which is exactly what a warning note is
-- supposed to do. Shared rather than copied: two subtly different strippers would be the defect
-- class in `practice/duplicated-server-constants.md`, in the tests that police it.
function harness.stripComments(src: string): string
    local body = string.gsub(src, "%-%-%[%[.-%]%]", "") -- block comments, possibly multi-line
    local out: { string } = {}
    for line in string.gmatch(body .. "\n", "(.-)\n") do
        local quote: string? = nil
        local cut: number? = nil
        local i = 1
        while i <= #line do
            local c = string.sub(line, i, i)
            if quote then
                if c == "\\" then
                    i += 1
                elseif c == quote then
                    quote = nil
                end
            elseif c == '"' or c == "'" or c == "`" then
                quote = c
            elseif c == "-" and string.sub(line, i + 1, i + 1) == "-" then
                cut = i - 1
                break
            end
            i += 1
        end
        table.insert(out, if cut then string.sub(line, 1, cut) else line)
    end
    return table.concat(out, "\n")
end

-- Allows the runner to detect double-loading mistakes in specs.
function harness.count(): number
    return #tests
end

return harness
