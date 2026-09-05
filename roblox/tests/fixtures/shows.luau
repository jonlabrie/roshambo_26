--!strict
-- shared-fixtures/shows.json, read under Lune the same way fireworkShells.luau reads its fixture:
-- never transcribed, so a case added on the server side is a case here the next time tests run.
--
-- Path is relative to the `roblox/` working directory, which is where `lune run tests/run` is
-- invoked from.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local PATH = "../shared-fixtures/shows.json"

local decoded = serde.decode("json", fs.readFile(PATH))
assert(type(decoded) == "table", `{PATH} is not a table`)
assert(type(decoded.limits) == "table", `{PATH} has no limits`)
assert(type(decoded.stages) == "table", `{PATH} has no stages`)
assert(type(decoded.cases) == "table" and #decoded.cases > 0, `{PATH} lists no cases`)

export type Case = { name: string, stage: string, cues: { any }, expect: string, cue: number? }

return {
    limits = decoded.limits :: { maxCues: number, maxDurationS: number },
    stages = decoded.stages :: { [string]: { [string]: string } },
    cases = decoded.cases :: { Case },
}
