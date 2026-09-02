--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ShellDisplay = require("../src/shared/ShellDisplay")
local fixture = require("./fixtures/fireworkShells")

describe("ShellDisplay — the counter shows every shell the server sells", function()
    test("EVERY FIXTURE SHELL HAS A DISPLAY ROW AND A PLACE IN THE ORDER", function()
        -- The kiku shipped server-side on 2026-09-04 and missed the menu because this
        -- table lived hardcoded in ShopController with nothing holding it to the fixture.
        local ordered = {}
        for _, id in ShellDisplay.ORDER do
            ordered[id] = true
        end
        for _, id in fixture.shells do
            if not ordered[id] then
                error(`fixture shell '{id}' missing from ShellDisplay.ORDER`)
            end
            if typeof(ShellDisplay.NAME[id]) ~= "string" or #ShellDisplay.NAME[id] == 0 then
                error(`fixture shell '{id}' has no display name`)
            end
            expect(true).toBe(true)
        end
    end)

    test("and no display row exists for a shell the server cannot sell", function()
        local known = {}
        for _, id in fixture.shells do
            known[id] = true
        end
        for _, id in ShellDisplay.ORDER do
            expect(known[id] == true).toBe(true)
        end
        for id in ShellDisplay.NAME do
            expect(known[id] == true).toBe(true)
        end
    end)
end)
