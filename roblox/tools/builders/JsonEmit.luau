--!strict
-- Deterministic JSON (sorted object keys) so generated model.json files are
-- stable across runs — required for the CI drift check.
local JsonEmit = {}

local function isArray(t: { [any]: any }): boolean
    local n = 0
    for _ in t do
        n += 1
    end
    return n == #t and n > 0
end

function JsonEmit.encode(v: any): string
    local ty = type(v)
    if ty == "number" then
        if v % 1 == 0 and math.abs(v) < 2 ^ 53 then
            return string.format("%d", v)
        end
        return string.format("%.6g", v)
    elseif ty == "string" then
        local s = (string.format("%q", v):gsub("\\\n", "\\n"))
        return s
    elseif ty == "boolean" then
        return tostring(v)
    elseif ty == "table" then
        local tbl = v :: { [any]: any }
        if isArray(tbl) then
            local parts = {}
            for _, item in ipairs(tbl) do
                table.insert(parts, JsonEmit.encode(item))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for k in tbl do
            table.insert(keys, k)
        end
        table.sort(keys)
        local parts = {}
        for _, k in keys do
            local key = (string.format("%q", k):gsub("\\\n", "\\n"))
            table.insert(parts, key .. ":" .. JsonEmit.encode(tbl[k]))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    error(`JsonEmit: unsupported type {ty}`)
end

return JsonEmit
