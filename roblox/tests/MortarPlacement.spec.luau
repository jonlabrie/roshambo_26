--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local MortarPlacement = require("../src/shared/MortarPlacement")
local shellFixture = require("./fixtures/fireworkShells")

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
            -- front edge = local MINZ (canyon-facing; verified against the live place --
            -- Nobori on -Z, back-door PortalControl on +Z)
            expect(p.z).toBe(BOUNDS.minZ + 1)
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
        local teahouse = { minX = -8, maxX = 8, minZ = -6, maxZ = -2 } -- swallows the front (minZ) edge
        local stored = { ["mortar:S"] = { offset = { 0, -5 }, facing = "N" } }
        local out = MortarPlacement.resolve(BOUNDS, { "mortar:S" }, stored, teahouse)
        local p = out["mortar:S"]
        local inside = p.x > teahouse.minX
            and p.x < teahouse.maxX
            and p.z > teahouse.minZ
            and p.z < teahouse.maxZ
        expect(inside).toBe(false)
    end)

    test("every SHELL_MORTAR value names a real mortar tier", function()
        for _, mortarId in MortarPlacement.SHELL_MORTAR do
            local known = false
            for _, id in MortarPlacement.MORTAR_ORDER do
                known = known or id == mortarId
            end
            expect(known).toBe(true)
        end
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

    test(
        "FOOTPRINT is a centered, size-independent gear footprint (matches the resolve clamp inset)",
        function()
            expect(MortarPlacement.FOOTPRINT.minX).toBe(-0.5)
            expect(MortarPlacement.FOOTPRINT.maxX).toBe(0.5)
            expect(MortarPlacement.FOOTPRINT.minZ).toBe(-0.5)
            expect(MortarPlacement.FOOTPRINT.maxZ).toBe(0.5)
        end
    )

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

-- Final-review fix round (deck-mortars): SHELL_MORTAR used to be a hand-mirrored copy of
-- server/src/fireworks.ts's REQUIREMENTS with no test on either side -- house rule is drift
-- fails CI. shared-fixtures/firework-shells.json's `mortars` list is the gear-required subset of
-- `shells`; fireworks.test.ts asserts the SAME fixture against REQUIREMENTS on the TS side, so a
-- shell's gear tier changing on either side without the other is now a CI failure, not a shell
-- that fires from the player's eye level instead of its mortar's muzzle.
describe("MortarPlacement.SHELL_MORTAR -- the fixture is the gear-requirement contract too", function()
    test("every fixture mortars entry matches SHELL_MORTAR exactly", function()
        for _, entry in shellFixture.mortars do
            expect(MortarPlacement.SHELL_MORTAR[entry.shell]).toBe(entry.mortar)
        end
    end)

    test("every fixture shell not listed in mortars has no SHELL_MORTAR entry", function()
        local gearShells: { [string]: boolean } = {}
        for _, entry in shellFixture.mortars do
            gearShells[entry.shell] = true
        end
        for _, id in shellFixture.shells do
            if not gearShells[id] then
                expect(MortarPlacement.SHELL_MORTAR[id] == nil).toBe(true)
            end
        end
    end)

    test("no OTHER shell in SHELL_MORTAR is missing from the fixture", function()
        local fixtureShells: { [string]: string } = {}
        for _, entry in shellFixture.mortars do
            fixtureShells[entry.shell] = entry.mortar
        end
        for shellId, mortarId in MortarPlacement.SHELL_MORTAR do
            expect(fixtureShells[shellId]).toBe(mortarId)
        end
    end)
end)
