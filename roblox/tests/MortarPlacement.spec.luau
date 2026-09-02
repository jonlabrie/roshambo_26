--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local MortarPlacement = require("../src/shared/MortarPlacement")

local BOUNDS = { minX = -8, maxX = 8, minZ = -6, maxZ = 6 }
local ALL = { "mortar:S", "mortar:M", "mortar:L" }

describe("MortarPlacement — default-first gear placement", function()
    test("every owned mortar gets a spot; defaults sit on the front edge, staggered", function()
        local out = MortarPlacement.resolve(BOUNDS, ALL, nil, nil)
        local xs = {}
        for _, id in MortarPlacement.MORTAR_ORDER do
            local p = out[id]
            expect(p ~= nil).toBe(true)
            assert(p)
            expect(p.z).toBe(BOUNDS.maxZ - 1)
            table.insert(xs, p.x)
        end
        expect(xs[1] < xs[2] and xs[2] < xs[3]).toBe(true) -- S left of M left of L
    end)

    test("a single owned mortar defaults to front-center", function()
        local out = MortarPlacement.resolve(BOUNDS, { "mortar:S" }, nil, nil)
        expect(out["mortar:S"].x).toBe(0)
        expect(out["mortar:M"] == nil).toBe(true)
    end)

    test("stored placements override defaults and get clamped, never mutated", function()
        local stored = { ["mortar:S"] = { offset = { 40, -40 }, facing = "E" } }
        local out = MortarPlacement.resolve(BOUNDS, { "mortar:S" }, stored, nil)
        expect(out["mortar:S"].x).toBe(BOUNDS.maxX - 0.5)
        expect(out["mortar:S"].z).toBe(BOUNDS.minZ + 0.5)
        expect(out["mortar:S"].facing).toBe("E")
        expect(stored["mortar:S"].offset[1]).toBe(40) -- untouched
    end)

    test("a spot inside the teahouse footprint NUDGES clear -- mortars never hide", function()
        local teahouse = { minX = -8, maxX = 8, minZ = 2, maxZ = 6 } -- swallows the front edge
        local stored = { ["mortar:S"] = { offset = { 0, 5 }, facing = "N" } }
        local out = MortarPlacement.resolve(BOUNDS, { "mortar:S" }, stored, teahouse)
        local p = out["mortar:S"]
        local inside = p.x > teahouse.minX
            and p.x < teahouse.maxX
            and p.z > teahouse.minZ
            and p.z < teahouse.maxZ
        expect(inside).toBe(false)
    end)

    test("unowned/unknown stored ids are ignored", function()
        local stored = {
            ["mortar:L"] = { offset = { 0, 0 }, facing = "N" },
            nonsense = { offset = { 0, 0 }, facing = "N" },
        }
        local out = MortarPlacement.resolve(BOUNDS, { "mortar:S" }, stored, nil)
        expect(out["mortar:L"] == nil).toBe(true)
        expect(out["mortar:S"] ~= nil).toBe(true)
    end)

    test("muzzleWorld transforms deck-local to world through the 12-number row", function()
        -- identity rotation, deck origin at (100, 50, -20)
        local row = { 100, 50, -20, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
        local x, y, z = MortarPlacement.muzzleWorld(row, { x = 2, z = 3, facing = "N" }, "mortar:L")
        expect(x).toBe(102)
        expect(z).toBe(-17)
        expect(math.abs(y - (50 + 0.5 + 2.5)) < 1e-6).toBe(true) -- baseTop + L tube length
        -- 90-degree yaw: local x maps to world -z (row-major R applied as p' = R*p)
        local rot = { 100, 50, -20, 0, 0, 1, 0, 1, 0, -1, 0, 0 }
        local rx, _, rz = MortarPlacement.muzzleWorld(rot, { x = 2, z = 0, facing = "N" }, "mortar:S")
        expect(math.abs(rx - 100) < 1e-6).toBe(true)
        expect(math.abs(rz - -22) < 1e-6).toBe(true)
    end)
end)
