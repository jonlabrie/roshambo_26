--!strict
-- ⚠ THE GUARD ON THE ONE MISTAKE THE SCALING PASS CANNOT CATCH AT RUNTIME.
--
-- `BirdFlight`'s scale-sensitive functions take the profile as an OPTIONAL trailing argument, so
-- that the reference bird stays bit-identical and 1541 existing tests keep meaning what they
-- meant. The price of that ergonomics is that FORGETTING the argument compiles, runs, and looks
-- almost right: a karasu moving on uguisu timings hops too little and flaps three times too
-- fast, and it diagnoses as "the animation is wrong" rather than "the call is missing an
-- argument". That is the expensive direction, and it is a day of looking at a bird.
--
-- `BirdController` is a Roblox-runtime file -- it touches Players, RunService and CFrame -- so
-- Lune cannot execute it and no behavioural test can reach it. Reading its SOURCE can.
--
-- ⚠ THE LIST OF SCALE-SENSITIVE FUNCTIONS IS DERIVED FROM BirdFlight ITSELF, never typed here.
-- A hand-maintained list is a second copy that goes stale silently, and the failure would be
-- this guard quietly not guarding the newest function -- the worst possible place for rot. Add
-- `profile: Profile?` to a signature and this test starts policing that call site the same run.
local fs = require("@lune/fs")
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect

local CONTROLLER = "src/client/BirdController.client.luau"
local FLIGHT = "src/shared/BirdFlight.luau"

local function scaleSensitive(): { string }
    local src = harness.stripComments(fs.readFile(FLIGHT))
    local names: { string } = {}
    -- ⚠ CAPTURE THE PARAMETER LIST, DO NOT SCAN THE LINE. `stylua` wraps a long signature across
    -- lines the moment one more argument pushes it past the column limit -- which is precisely
    -- what adding `profile` did to `beatPose` -- so a line-bounded pattern silently stops seeing
    -- the functions that most recently gained the argument.
    for name, params in string.gmatch(src, "function BirdFlight%.([%w_]+)%((.-)%)%s*:") do
        if string.find(params, "profile: Profile?", 1, true) then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

-- Every argument list passed to `BirdFlight.<fn>(` in `src`, by balanced parentheses so a nested
-- call or an arithmetic group inside the arguments does not truncate the match.
local function callArgs(src: string, fn: string): { string }
    local found: { string } = {}
    local needle = "BirdFlight." .. fn .. "("
    local from = 1
    while true do
        local a, b = string.find(src, needle, from, true)
        if not a then
            break
        end
        local depth, i = 1, (b :: number) + 1
        while i <= #src and depth > 0 do
            local c = string.sub(src, i, i)
            if c == "(" then
                depth += 1
            elseif c == ")" then
                depth -= 1
            end
            i += 1
        end
        table.insert(found, string.sub(src, (b :: number) + 1, i - 2))
        from = i
    end
    return found
end

describe("bird scale convention", function()
    test("the scale-sensitive surface is discoverable, and it is not empty", function()
        -- ⚠ Without this the whole guard passes by finding nothing: a renamed type or a
        -- reformatted signature would silently reduce the list to zero and police no call at all.
        local names = scaleSensitive()
        expect(#names >= 8).toBe(true)
        local set: { [string]: boolean } = {}
        for _, n in names do
            set[n] = true
        end
        -- The perch behaviours the owner asked for by name, plus the flight they sit between.
        for _, must in
            {
                "idlePose",
                "legPose",
                "turnPose",
                "flutterExtension",
                "offsetFor",
                "beatPose",
                "wingExtension",
                "flightDuration",
            }
        do
            expect(set[must]).toBe(true)
        end
    end)

    test("every familiar call passes a profile -- none inherits the reference by omission", function()
        local src = harness.stripComments(fs.readFile(CONTROLLER))
        local offenders: { string } = {}
        local calls = 0
        for _, fn in scaleSensitive() do
            for _, args in callArgs(src, fn) do
                calls += 1
                if not string.find(args, "PROFILE", 1, true) then
                    table.insert(offenders, `BirdFlight.{fn}({args})`)
                end
            end
        end
        -- The controller must actually be calling into the module; a moved file would otherwise
        -- make this vacuously green.
        expect(calls >= 8).toBe(true)
        expect(table.concat(offenders, "\n")).toBe("")
    end)

    test("the controller gates on the PROFILE's durations, never the module's", function()
        -- ⚠ A gate is the subtler half. `now - turnSince < BirdFlight.TURN_TIME` would end a
        -- crow's turn on a warbler's clock while `turnPose` was still running it on its own --
        -- the turn would snap, and only in the middle. Reading the raw field is the tell.
        local src = harness.stripComments(fs.readFile(CONTROLLER))
        for _, field in
            { "TURN_TIME", "FLUTTER_BURST", "WING_OPEN_TIME", "FLIGHT_MIN_TIME", "CRUISE_SPEED", "ENTRY" }
        do
            local hit = string.find(src, "BirdFlight." .. field, 1, true)
            expect(if hit then `BirdFlight.{field} is read directly` else "").toBe("")
        end
    end)

    test("the species name drives assets, voice AND proportion from one place", function()
        -- A hardcoded "UguisuBody" beside a separate "Uguisu" for the voice is how a bird ends up
        -- wearing a crow's body with a warbler's song, with nothing positioned to notice.
        -- ⚠ BAN THE NAME OUTRIGHT, not just the quoted literal. The first version of this check
        -- banned `"UguisuBody"` and passed while two `warn` calls still SAID
        -- "no RoshamboBirds.UguisuBody" in their message text -- so the first thing a missing
        -- karasu asset would have done is name the wrong bird in the one line meant to diagnose
        -- it. A species name has no business appearing in this file at all.
        local src = harness.stripComments(fs.readFile(CONTROLLER))
        -- The ONE line allowed to name a bird is the declaration itself. Cut it, and nothing
        -- anywhere else in the file may mention a species -- not an asset lookup, not a warning
        -- message, not a comparison.
        local decl = string.match(src, 'local SPECIES = "[%w_]+"')
        expect(decl ~= nil).toBe(true)
        local rest = string.gsub(src, 'local SPECIES = "[%w_]+"', "", 1)
        for name in require("../src/shared/BirdSpecies").SPECIES do
            local hit = string.find(rest, name, 1, true)
            expect(if hit then `the species name "{name}" is hardcoded in the controller` else "").toBe("")
        end
        expect(string.find(src, "{SPECIES}Body", 1, true) ~= nil).toBe(true)
        expect(string.find(src, "BirdSpecies.scaleOf(SPECIES)", 1, true) ~= nil).toBe(true)
    end)
end)
