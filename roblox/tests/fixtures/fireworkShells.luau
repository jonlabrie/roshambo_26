--!strict
-- THE ONE id list, read from shared-fixtures/firework-shells.json rather than transcribed.
--
-- The plan called for copying the four ids into Luau by hand, on the belief that Lune cannot
-- require JSON. It cannot `require` one — but it can READ one (@lune/fs) and parse it
-- (@lune/serde), which is better: a transcribed list is exactly the "keep the two in sync" hope
-- this repo refuses everywhere else. A copy would drift the first time a shell is added on the
-- server, and it would drift SILENTLY, because a fixture that agrees with itself always passes.
--
-- Path is relative to the `roblox/` working directory, which is where `lune run tests/run` is
-- invoked from — the same assumption tests/run makes when it reads the `tests` directory.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local PATH = "../shared-fixtures/firework-shells.json"

local decoded = serde.decode("json", fs.readFile(PATH))
assert(type(decoded) == "table" and type(decoded.shells) == "table", `{PATH} has no shells array`)
assert(#decoded.shells > 0, `{PATH} lists no shells`)

-- Final-review fix round (deck-mortars): the gear-required subset of `shells` + the mortar tier
-- each needs, read the same way -- MortarPlacement.spec asserts SHELL_MORTAR against this instead
-- of the two tables trusting a comment to stay in sync.
assert(type(decoded.mortars) == "table", `{PATH} has no mortars array`)

return {
    shells = decoded.shells :: { string },
    mortars = decoded.mortars :: { { shell: string, mortar: string } },
}
