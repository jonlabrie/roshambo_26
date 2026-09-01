--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local BurstStyles = require("../src/shared/BurstStyles")

-- A deterministic rand: a fixed sequence, cycling.
local function seqRand(values: { number }): () -> number
    local i = 0
    return function()
        i += 1
        return values[((i - 1) % #values) + 1]
    end
end

describe("BurstStyles — the vocabulary's one source of truth", function()
    test("EVERY STYLE DECLARES EVERY APPLIED PROPERTY", function()
        -- Pool emitters are shared; an unwritten property inherits the previous
        -- shell's value. Completeness is the contract, not a courtesy.
        for name, style in BurstStyles.STYLES do
            for _, prop in BurstStyles.APPLIED do
                if (style :: any)[prop] == nil then
                    error(`style '{name}' is missing '{prop}'`)
                end
            end
        end
        expect(#BurstStyles.APPLIED >= 10).toBe(true)
    end)

    test("the five wave-one styles exist and unknown falls back to peony", function()
        for _, name in { "peony", "ring", "palm", "strobe", "kamuro" } do
            expect(BurstStyles.STYLES[name] ~= nil).toBe(true)
        end
        expect(BurstStyles.styleOf("nosuch") == BurstStyles.STYLES.peony).toBe(true)
        expect(BurstStyles.styleOf(nil) == BurstStyles.STYLES.peony).toBe(true)
    end)

    test("texture and sound roles resolve in the role tables", function()
        for name, style in BurstStyles.STYLES do
            if BurstStyles.TEXTURES[style.textureRole] == nil then
                error(`style '{name}' names unknown textureRole '{style.textureRole}'`)
            end
            if BurstStyles.SOUNDS[style.soundRole] == nil then
                error(`style '{name}' names unknown soundRole '{style.soundRole}'`)
            end
        end
        expect(BurstStyles.TEXTURES.dot ~= "").toBe(true)
        expect(BurstStyles.TEXTURES.streak ~= "").toBe(true)
    end)

    test("pointFrames is deterministic under a fixed rand", function()
        local a = BurstStyles.pointFrames("ring", 1, 0, seqRand({ 0.3, 0.7, 0.1 }))
        local b = BurstStyles.pointFrames("ring", 1, 0, seqRand({ 0.3, 0.7, 0.1 }))
        expect(#a).toBe(#b)
        for i, fa in a do
            for k = 1, 3 do
                expect(fa.pos[k] == b[i].pos[k]).toBe(true)
                expect(fa.rot[k] == b[i].rot[k]).toBe(true)
            end
        end
    end)

    test("scatter rule: n frames inside the scatter box, identity rotation", function()
        local frames = BurstStyles.pointFrames("peony", 6, 8, seqRand({ 0.1, 0.9, 0.5, 0.2, 0.8 }))
        expect(#frames).toBe(6)
        for _, f in frames do
            expect(math.abs(f.pos[1]) <= 8 and math.abs(f.pos[3]) <= 8).toBe(true)
            expect(math.abs(f.pos[2]) <= 8 * 0.6).toBe(true)
            expect(f.rot[1] == 0 and f.rot[2] == 0 and f.rot[3] == 0).toBe(true)
        end
    end)

    test("tilted rule: one frame, tilted but never past 30 degrees off-plane", function()
        local frames = BurstStyles.pointFrames("ring", 5, 10, seqRand({ 0.99, 0.01, 0.5 }))
        expect(#frames).toBe(1) -- a ring is one point regardless of asked points
        local f = frames[1]
        expect(math.abs(f.rot[1]) <= 30 and math.abs(f.rot[3]) <= 30).toBe(true)
    end)

    test("circle rule: arms sit on the circle and rotations differ per arm", function()
        local frames = BurstStyles.pointFrames("palm", 5, 6, seqRand({ 0.5 }))
        expect(#frames).toBe(5)
        local firstRot = frames[1].rot
        local anyDifferent = false
        for _, f in frames do
            local r = math.sqrt(f.pos[1] ^ 2 + f.pos[3] ^ 2)
            expect(math.abs(r - 6) < 0.01).toBe(true)
            expect(f.pos[2] == 0).toBe(true)
            if f.rot[1] ~= firstRot[1] or f.rot[3] ~= firstRot[3] then
                anyDifferent = true
            end
        end
        expect(anyDifferent).toBe(true) -- outward aim varies around the circle
    end)

    test("single rule: one identity frame; releaseTail is the style's max lifetime", function()
        local frames = BurstStyles.pointFrames("kamuro", 4, 12, seqRand({ 0.5 }))
        expect(#frames).toBe(1)
        expect(frames[1].pos[1] == 0 and frames[1].pos[2] == 0 and frames[1].pos[3] == 0).toBe(true)
        expect(BurstStyles.releaseTail("kamuro")).toBe(BurstStyles.STYLES.kamuro.lifetime[2])
        expect(BurstStyles.releaseTail(nil)).toBe(BurstStyles.STYLES.peony.lifetime[2])
    end)

    test("strobe's transparency is a flicker, not a fade", function()
        -- At least 4 falling AND 4 rising edges — a square wave, which is the strobe.
        local t = BurstStyles.STYLES.strobe.transparency
        local rises, falls = 0, 0
        for i = 2, #t do
            if t[i][2] > t[i - 1][2] then
                rises += 1
            elseif t[i][2] < t[i - 1][2] then
                falls += 1
            end
        end
        expect(rises >= 4 and falls >= 4).toBe(true)
    end)

    test("MAX_POINTS is 8 — the pool's per-slot break-part count", function()
        expect(BurstStyles.MAX_POINTS).toBe(8)
    end)
end)
