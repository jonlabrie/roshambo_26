--!strict
local harness = require("./harness")
local JsonEmit = require("../tools/builders/JsonEmit")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("JsonEmit", function()
    test("emits sorted keys deterministically", function()
        local s = JsonEmit.encode({ b = 1, a = { 2, 3 }, c = "x" })
        expect(s).toBe('{"a":[2,3],"b":1,"c":"x"}')
    end)
    test("arrays of tables and numbers", function()
        expect(JsonEmit.encode({ { n = 1 }, { n = 2 } })).toBe('[{"n":1},{"n":2}]')
    end)
end)
