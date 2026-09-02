--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local MortarPlacement = require("../src/shared/MortarPlacement")
local shellFixture = require("./fixtures/fireworkShells")

local BOUNDS = { minX = -8, maxX = 8, minZ = -6, maxZ = 6 }
local ALL = { "mortar:S", "mortar:M", "mortar:L" }

describe("MortarPlacement — default-first gear placement", function()
    test("every owned mortar gets a spot; defaults ride the front RAIL, staggered", function()
        -- DEFAULT_MOUNT = "rail" (owner pulled the lever, 2026-09-05): a mortar with no stored
        -- record saddles the front rail cap, staggered, aimed straight over the canyon.
        local out = MortarPlacement.resolve(BOUNDS, ALL, nil, nil)
        local xs = {}
        for _, id in MortarPlacement.MORTAR_ORDER do
            local p = out[id]
            expect(p ~= nil).toBe(true)
            assert(p)
            expect(p.mount).toBe("rail")
            expect(p.aim).toBe("C")
            -- cap line: front edge = local MINZ (canyon-facing; verified against the live
            -- place -- Nobori on -Z, back-door PortalControl on +Z)
            expect(math.abs(p.z - (BOUNDS.minZ + 0.225)) < 1e-9).toBe(true)
            table.insert(xs, p.x)
        end
        expect(xs[1] < xs[2] and xs[2] < xs[3]).toBe(true) -- S left of M left of L
    end)

    test("a single owned mortar defaults to rail front-center", function()
        local out = MortarPlacement.resolve(BOUNDS, { "mortar:S" }, nil, nil)
        expect(out["mortar:S"].x).toBe(0)
        expect(out["mortar:S"].mount).toBe("rail")
        expect(out["mortar:M"] == nil).toBe(true)
    end)

    test("stored placements override defaults and get clamped, never mutated", function()
        local stored = { ["mortar:S"] = { offset = { 40, -40 }, facing = "E" } }
        local out = MortarPlacement.resolve(BOUNDS, { "mortar:S" }, stored, nil)
        expect(out["mortar:S"].x).toBe(BOUNDS.maxX - 0.5)
        expect(out["mortar:S"].z).toBe(BOUNDS.minZ + 0.5)
        -- facing is legacy and ignored now (mount/aim rule placement instead); a record
        -- without either defaults to floor/C
        expect(out["mortar:S"].mount).toBe("floor")
        expect(out["mortar:S"].aim).toBe("C")
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

    test("legacy records and absent records resolve floor/C; rail records ride the cap", function()
        local stored = {
            ["mortar:S"] = { offset = { 2, -3 }, facing = "E" }, -- legacy: facing ignored
            ["mortar:M"] = { offset = { 40, 0 }, mount = "rail", aim = "R" },
        }
        local out = MortarPlacement.resolve(BOUNDS, ALL, stored, nil)
        expect(out["mortar:S"].mount).toBe("floor")
        expect(out["mortar:S"].aim).toBe("C")
        expect(out["mortar:S"].x).toBe(2)
        -- no record at all -> the pulled lever: rail default. A LEGACY STORED record (above)
        -- stays floor at its saved spot -- the lever must never relocate saved placements.
        expect(out["mortar:L"].mount).toBe("rail")
        expect(out["mortar:M"].mount).toBe("rail")
        expect(out["mortar:M"].aim).toBe("R")
        expect(out["mortar:M"].x).toBe(BOUNDS.maxX - 0.95) -- newelMargin clamp
        expect(math.abs(out["mortar:M"].z - (BOUNDS.minZ + 0.225)) < 1e-9).toBe(true)
    end)

    -- Final-review fix round: the spec's "one-line lever" (flipping the default mount from
    -- "floor" to "rail") must not error when NO stored record exists at all -- that is the
    -- only case where `resolve`'s rail branch sees a nil override. `resolve` itself can't be
    -- driven down that path while the default mount stays "floor" this round, so this tests
    -- the shared mechanism directly: the same i/n stagger the floor defaults use, clamped into
    -- the rail's newel margins, pinned to the cap rail z, aimed C.
    test(
        "railDefault: staggers S/M/L along the cap, clamped to the newel margins, aim C, never throws",
        function()
            local n = 3
            local xs = {}
            for i = 1, n do
                local x, z, aim = MortarPlacement.railDefault(BOUNDS, i, n)
                table.insert(xs, x)
                expect(aim).toBe("C")
                expect(math.abs(z - (BOUNDS.minZ + 0.225)) < 1e-9).toBe(true)
                expect(x >= BOUNDS.minX + 0.95 - 1e-9).toBe(true)
                expect(x <= BOUNDS.maxX - 0.95 + 1e-9).toBe(true)
            end
            expect(xs[1] < xs[2] and xs[2] < xs[3]).toBe(true) -- same i/n stagger the floor defaults use
        end
    )

    test("axisLocal: C leans toward -Z by the mount's elevation; L/R yaw 30 degrees", function()
        local x, y, z = MortarPlacement.axisLocal("rail", "C")
        expect(math.abs(x) < 1e-9).toBe(true)
        expect(math.abs(y - math.cos(math.rad(25))) < 1e-9).toBe(true)
        expect(math.abs(z - (-math.sin(math.rad(25)))) < 1e-9).toBe(true)
        local lx, _, lz = MortarPlacement.axisLocal("floor", "L")
        expect(math.abs(lx - (-0.5 * math.sin(math.rad(12)))) < 1e-9).toBe(true)
        expect(lz < 0).toBe(true)
        -- always unit length
        local ux, uy, uz = MortarPlacement.axisLocal("rail", "R")
        expect(math.abs(ux * ux + uy * uy + uz * uz - 1) < 1e-9).toBe(true)
    end)

    test("launch: identity deck row, rail C -- muzzle sits up the tilted axis, heading matches", function()
        local row = { 100, 50, -20, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
        local resolved = { mount = "rail", x = 2, z = -5.775, aim = "C" }
        local ox, oy, oz, hx, hy, hz = MortarPlacement.launch(row, resolved, "mortar:L")
        local el = math.rad(25)
        local run = 0.35 + 2.5 -- BASE_OFFSET.rail + L tube length
        expect(math.abs(ox - 102) < 1e-9).toBe(true)
        expect(math.abs(oy - (50 + 2.75 + run * math.cos(el))) < 1e-9).toBe(true)
        expect(math.abs(oz - (-20 + -5.775 - run * math.sin(el))) < 1e-9).toBe(true)
        expect(math.abs(hx) < 1e-9).toBe(true)
        expect(math.abs(hy - math.cos(el)) < 1e-9).toBe(true)
        expect(math.abs(hz - (-math.sin(el))) < 1e-9).toBe(true)
    end)

    test("launch: 90-degree yaw deck row rotates both point and heading", function()
        -- same rotation rows the old muzzleWorld test used: local x -> world -z
        local rot = { 100, 50, -20, 0, 0, 1, 0, 1, 0, -1, 0, 0 }
        local resolved = { mount = "floor", x = 2, z = 0, aim = "C" }
        local _, _, oz, hx, hy = MortarPlacement.launch(rot, resolved, "mortar:S")
        local el = math.rad(12)
        -- local heading (0, cos el, -sin el): world x' = z*1 -> hx = -sin el... via R rows:
        -- x' = r4*lx + r5*ly + r6*lz = lz ; y' = ly ; z' = -lx
        expect(math.abs(hx - (-math.sin(el))) < 1e-9).toBe(true)
        expect(math.abs(hy - math.cos(el)) < 1e-9).toBe(true)
        -- point: local (2, mountY+..., 0) -> z' = -2 for the x component of the mount
        expect(math.abs(oz - -22) < 1e-9).toBe(true)
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
