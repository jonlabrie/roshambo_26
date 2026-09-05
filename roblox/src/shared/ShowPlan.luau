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
ShowPlan.DECK_SLOTS = {
    hand = "none",
    ["mortar:S"] = "mortar:S",
    ["mortar:M"] = "mortar:M",
    ["mortar:L"] = "mortar:L",
} :: { [string]: string }
ShowPlan.PROVING_SLOTS = {
    ["north arena"] = "any",
    ["bridge"] = "any",
    ["upper north"] = "any",
    ["mid pool"] = "any",
    ["hi west"] = "any",
    ["hanabiya roof"] = "any",
} :: { [string]: string }

function ShowPlan.knownShellSet(ids: { string }): { [string]: boolean }
    local set: { [string]: boolean } = {}
    for _, id in ids do
        set[id] = true
    end
    return set
end

local function fail(err: string, cue: number?): Check
    return { ok = false, error = err, cue = cue }
end

-- t_ms must be a FINITE number: NaN and ±inf are malformed cues, not times, matching
-- Number.isFinite on the TypeScript side. Non-integer times are fine on both sides.
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
        -- A missing key AND a value outside the grammar are both BAD_SLOT: a typo'd tier in a
        -- stage table must not silently degrade to "any". (Luau tables have no inherited keys, so
        -- the fixture's "toString" slot is simply absent here -- the shape check exists so a
        -- malformed stage table is rejected identically on both sides of the wire.)
        local accepts = stage[c.slot]
        local shaped = accepts == "none"
            or accepts == "any"
            or (type(accepts) == "string" and string.sub(accepts, 1, 7) == "mortar:")
        if not shaped then
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
        -- "any" accepts everything (public tubes).
    end
    if last > ShowPlan.LIMITS.maxDurationS * 1000 then
        return fail("TOO_LONG")
    end
    return { ok = true }
end

-- HOLES ARE A HOSTILE INPUT (Task 2's review). ShowPlan.validate walks with `ipairs`, which stops
-- at the first gap, so a client sending { [1] = cue, [3] = cue } would have only the PREFIX
-- validated while the rest rode along into playback. Accept only a dense 1..n array -- every key a
-- positive integer with no gap (`#t` is a BORDER, not the max key, so the count must be checked
-- against the largest key, not against `#t`) -- and PROJECT every entry to exactly the three cue
-- fields, so hostile extra fields never reach validation, the wire, or playback.
function ShowPlan.dense(t: any): { Cue }?
    if type(t) ~= "table" then
        return nil
    end
    local count, maxKey = 0, 0
    for k, v in pairs(t) do
        if type(k) ~= "number" or k % 1 ~= 0 or k < 1 then
            return nil
        end
        if type(v) ~= "table" then
            return nil
        end
        count += 1
        if k > maxKey then
            maxKey = k
        end
    end
    if maxKey ~= count then
        return nil
    end
    local out = table.create(count)
    for i = 1, count do
        local v = t[i]
        out[i] = { t_ms = v.t_ms, slot = v.slot, shellId = v.shellId }
    end
    return out
end

function ShowPlan.tally(cues: { Cue }): { [string]: number }
    local out: { [string]: number } = {}
    for _, c in cues do
        out[c.shellId] = (out[c.shellId] or 0) + 1
    end
    return out
end

return ShowPlan
