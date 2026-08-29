--!strict
-- ⚠ THE GUARD ON A COST THAT ONLY SHOWS UP AT 60 Hz.
--
-- The eyeballs are a separate MeshPart because gloss cannot be localised on a single ColorMap.
-- That leaves ONE question with an expensive wrong answer: how does a separate part follow a
-- head turn that is driven on bones INSIDE the body mesh?
--
-- Two MeshParts do not share a skeleton. `KarasuBody`'s `joint4` and `KarasuEyes`'s `joint4` are
-- different instances, and driving one does nothing to the other -- a fact that reads as obvious
-- written down and did not stop a session from claiming the opposite. Making the eyes' OWN bones
-- track the head means mirroring every driven bone above them (joint1, joint3, joint4) plus the
-- part CFrame: four writes per bird per frame. Eyeballs are RIGID relative to the skull, so the
-- correct amount of work is one rigid transform -- one write, off `TransformedWorldCFrame`.
--
-- Nothing at runtime distinguishes the two. Both put the eyes in the right place; one costs four
-- times as much forever. `BirdController` is a Roblox-runtime file that Lune cannot execute, so
-- reading its source is the only reach a test has -- the same argument as BirdScaleConvention.
local fs = require("@lune/fs")
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect

local CONTROLLER = "src/client/BirdController.client.luau"

local function source(): string
    return harness.stripComments(fs.readFile(CONTROLLER))
end

describe("BirdController eye convention", function()
    test("the eyes are placed with ONE write, off the head bone", function()
        local src = source()
        -- Exactly one assignment to the eyes part's CFrame anywhere in the file. Two would mean
        -- a per-eye loop had come back; zero means the eyes stopped following the head.
        local writes = 0
        for _ in string.gmatch(src, "%.eyes%s*%.CFrame%s*=") do
            writes += 1
        end
        expect(writes).toBe(1)
        -- ⚠ OFF THE DRIVEN POSE, NOT THE REST POSE, and asserted on the WRITE ITSELF rather
        -- than anywhere in the file -- the spawn-time offset legitimately reads `WorldCFrame`,
        -- so a file-wide search for the right word passes on a render loop using the wrong one.
        -- `WorldCFrame` is where the bone was authored; `TransformedWorldCFrame` is where it
        -- currently is. The wrong one looks perfectly correct in every screenshot of a bird
        -- facing forward and only breaks when the head turns.
        local rhs = string.match(src, "%.eyes%s*%.CFrame%s*=([^\n]*)")
        expect(rhs ~= nil).toBe(true)
        expect(string.find(rhs :: string, "TransformedWorldCFrame", 1, true) ~= nil).toBe(true)
    end)

    test("the offset is computed ONCE, not rebuilt per frame", function()
        -- The eyes sit at a fixed place in the skull, so their offset from the head bone is a
        -- constant. Recomputing it inside RenderStepped would add an inverse per bird per frame
        -- to buy a number that cannot change.
        local src = source()
        local inverses = 0
        for _ in string.gmatch(src, ":Inverse%(%)") do
            inverses += 1
        end
        expect(inverses <= 1).toBe(true)
    end)

    test("the rest pose is seated by the SHARED ORIGIN, not by the part centre", function()
        -- ⚠ THE BUG THIS EXISTS FOR, seen in play as "two blue-ish balls floating behind the
        -- bird, nearer the tail than the head, moving more than eyes would".
        --
        -- `part.CFrame` puts a part's BOUNDING-BOX CENTRE somewhere, and the body and the eyes
        -- have different centres: body PivotOffset (0.0010, -0.4485, 0.0000) against eyes
        -- (0.0065, -0.8329, 0.5900). Seating one to the other's CFrame therefore lands the eyes
        -- 0.59 studs down the nose-to-tail axis and 0.38 up -- behind the bird.
        --
        -- ⚠ AND THE ERROR IS AMPLIFIED, not merely offset, because the bad rest pose is then
        -- MEASURED into `eyeOffset`. A ~0.7-stud lever arm replaces a 0.038-stud one, so every
        -- head turn swings the eyes through an arc eighteen times too large. That is why the
        -- symptom read as wrong MOTION rather than as a wrong position.
        --
        -- Both parts were exported around the same origin, and `PivotOffset.Position` is the
        -- offset from each part's centre to it -- so going through the origin is what makes the
        -- two agree. The render loop already seats the body and the wings exactly this way.
        -- ⚠ SCAN THE BLOCK, NOT THE LINE. The seating is naturally two statements -- compute
        -- the shared origin, then place the eyes relative to it -- and a line-bounded pattern
        -- sees only one `PivotOffset` and fails on correct code. Same trap BirdScaleConvention
        -- hit when stylua wrapped a signature: bound a source scan by the STRUCTURE it lives in.
        local src = source()
        local seat = string.match(src, "if eyes and head then(.-)\n    end")
        expect(seat ~= nil).toBe(true)
        seat = seat :: string
        -- BOTH pivots: routing through only the eyes' leaves the body's own centre offset in.
        expect(string.find(seat, "part.PivotOffset", 1, true) ~= nil).toBe(true)
        expect(string.find(seat, "eyes.PivotOffset", 1, true) ~= nil).toBe(true)
        -- ⚠ POSITION ONLY. PivotOffset also carries the FBX axis conversion (90, 0, -180), so
        -- using the whole CFrame reintroduces the nose-up attitude cleared a few lines above.
        local _, positions = string.gsub(seat, "PivotOffset%.Position", "")
        expect(positions).toBe(2)
    end)

    test("no eyeball is built out of a Part", function()
        -- ⚠ OWNER RULING 2026-08-28, and it was earned: the runtime `Part` ball was chosen for a
        -- trade that does not exist. A MeshPart keeps Color, Material AND Reflectance at runtime
        -- -- every dial the Part was supposed to buy -- plus TextureID, which a Part has not. The
        -- Part gave up the iris and gave up being visible while authoring, and bought nothing.
        local src = source()
        expect(string.find(src, "Enum.PartType.Ball", 1, true)).toBe(nil)
        -- The per-eye bone lookups went with it. They could never have worked: Roblox strips any
        -- bone that influences no vertex, so `eye_R`/`eye_L` never survive the import at all.
        expect(string.find(src, "eye_R", 1, true)).toBe(nil)
        expect(string.find(src, "eye_L", 1, true)).toBe(nil)
    end)

    test("the eyes are placed AFTER the head is posed this frame", function()
        -- ⚠ THE ONE-FRAME LAG, seen in play as eyes that "don't seem to turn accurately with the
        -- head" and "popping in and out of the geometry". Both are the same defect.
        --
        -- `TransformedWorldCFrame` reports where a bone IS, so it answers with whatever
        -- `Transform` was last written. The head and neck are posed at the END of the per-frame
        -- block; placing the eyes before that reads LAST frame's skull. Standing still it looks
        -- perfect -- the pose is unchanged, so a frame late is indistinguishable. It only breaks
        -- while the head is moving, and it breaks in the two ways reported: the eyes trail the
        -- turn, and because the skull moves out from under them they sink into it and re-emerge.
        --
        -- Ordering has no runtime signal at all. Both orders compile, run, and place the eyes on
        -- the head; only one is a frame stale.
        local src = source()
        local place = string.find(src, "%.eyes%s*%.CFrame%s*=")
        local lastHeadPose = nil
        for i in string.gmatch(src, "()[%w_]+%.head%.Transform%s*=") do
            lastHeadPose = i
        end
        expect(place ~= nil).toBe(true)
        expect(lastHeadPose ~= nil).toBe(true)
        expect((place :: number) > (lastHeadPose :: number)).toBe(true)
    end)

    test("every teardown that destroys the bird destroys the eyes", function()
        -- ⚠ TWO TEARDOWN PATHS EXIST and only one was updated: the roster sweep and
        -- `Players.PlayerRemoving`. An eyes part missed by either is ANCHORED, so it does not
        -- fall or fade -- it hangs over the canyon for the rest of the session.
        local src = source()
        local _, bodies = string.gsub(src, "%.part:Destroy%(%)", "")
        local _, eyes = string.gsub(src, "%.eyes:Destroy%(%)", "")
        expect(eyes).toBe(bodies)
    end)

    test("the eyes hide with the bird", function()
        -- ⚠ AN ANCHORED PART LEFT VISIBLE HANGS IN THE AIR at the last place the head was. The
        -- body and the wings are both hidden on the cull path; the eyes must be too, or a culled
        -- bird leaves a pair of eyeballs floating over the canyon.
        local src = source()
        -- ⚠ Bounded by the function's OWN indent (`\n        end`), not by the first `end` --
        -- a non-greedy match stops inside the `if b.wings` branch and would pass on a hideBird
        -- that hides nothing after it.
        local hide = string.match(src, "local function hideBird%(%).-\n        end")
        expect(hide ~= nil).toBe(true)
        expect(string.find(hide :: string, "eyes", 1, true) ~= nil).toBe(true)
    end)
end)
