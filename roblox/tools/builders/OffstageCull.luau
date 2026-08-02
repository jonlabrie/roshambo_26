--!strict
-- Decide which planted trees a player can never see, and of the rest, which stand
-- against SKY and which against ROCK.
--
-- WHY THIS IS A MODULE AND NOT PART OF THE BAKE. A bake owns its zone folders and
-- rebuilds them wholesale, so any hand-curation inside one is destroyed on the next run.
-- Rather than defend the curation, REPRODUCE it: this runs after a bake and re-derives
-- the same decision every time. Nothing has to be protected because nothing is unique.
-- (Same shape as cullWaterMargin: park, never delete, deterministic, dry-run first.)
--
-- WHY THE THREE-WAY SPLIT MATTERS. Measured on the ZenDojo fringe 2026-08-02: the trees
-- silhouetted against sky are small, high and numerous — 362 of them carrying 72% of the
-- fringe's triangles — and they ARE the wooded rim, so culling them is wrong. The trees
-- seen against rock are large, low and few, and they are what a player walks past. The
-- first group wants cheaper geometry; the second wants full detail. A single "is it
-- visible" test cannot tell them apart, which is why `terrainBehind` exists.
--
-- Raycasting is INJECTED. The Studio shell supplies the real thing; the tests supply a
-- table of who-can-see-what, so the policy is testable headless under Lune.

local OffstageCull = {}

export type Vec3 = { x: number, y: number, z: number }

export type Tree = {
    id: string,
    base: Vec3, -- the trunk's foot, not its centre
    height: number,
}

export type Options = {
    -- viewpoints further than this are not considered at all
    maxSight: number,
    -- a tree a player can walk within this distance of keeps full detail, whether or
    -- not it is visible from there: an impostor's crossed planes betray themselves
    -- close up, and today's blocked sightline is tomorrow's new path
    nearTrailRadius: number,
    -- aim the sightline at mid-canopy rather than the foot
    targetFrac: number,
    -- how close a ray must land to count as reaching the tree (used by the shell)
    hitTolerance: number,
}

export type Classification = "OFFSTAGE" | "SKYLINE" | "AGAINST_ROCK"

export type Result = {
    id: string,
    class: Classification,
    -- distance to the closest viewpoint, REGARDLESS of whether it can see the tree
    nearestApproach: number,
    -- tree height / distance from the closest viewpoint that CAN see it. 0 when unseen.
    -- A rough angular size: how big the tree reads at its most favourable viewing spot.
    angular: number,
    nearTrail: boolean,
    seenFrom: number,
}

export type Summary = {
    total: number,
    offstage: number,
    skyline: number,
    againstRock: number,
    nearTrail: number,
}

local function dist(a: Vec3, b: Vec3): number
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

--[=[
	trees          — everything planted in the zones under consideration
	views          — every position a player can stand, at eye height
	lineOfSight    — (viewIndex, tree) -> is the sightline to mid-canopy clear?
	terrainBehind  — (viewIndex, tree) -> continuing PAST the tree, is there rock?
	opts           — see Options

	Returns one Result per tree, sorted by id so a re-run is byte-comparable.
]=]
function OffstageCull.classify(
    trees: { Tree },
    views: { Vec3 },
    lineOfSight: (number, Tree) -> boolean,
    terrainBehind: (number, Tree) -> boolean,
    opts: Options
): { Result }
    local out: { Result } = {}

    for _, tree in trees do
        local nearest = math.huge
        local bestSeeing, bestIndex = math.huge, nil :: number?
        local seenFrom = 0

        for i, view in views do
            local d = dist(view, tree.base)
            if d < nearest then
                nearest = d
            end
            -- the sight test is the expensive one, so distance-gate it first
            if d <= opts.maxSight and lineOfSight(i, tree) then
                seenFrom += 1
                if d < bestSeeing then
                    bestSeeing, bestIndex = d, i
                end
            end
        end

        local class: Classification
        local angular = 0
        if bestIndex == nil then
            class = "OFFSTAGE"
        else
            angular = if bestSeeing > 0 then tree.height / bestSeeing else math.huge
            class = if terrainBehind(bestIndex, tree) then "AGAINST_ROCK" else "SKYLINE"
        end

        table.insert(out, {
            id = tree.id,
            class = class,
            nearestApproach = nearest,
            angular = angular,
            nearTrail = nearest < opts.nearTrailRadius,
            seenFrom = seenFrom,
        })
    end

    table.sort(out, function(a, b)
        return a.id < b.id
    end)
    return out
end

function OffstageCull.summarise(results: { Result }): Summary
    local s: Summary = { total = 0, offstage = 0, skyline = 0, againstRock = 0, nearTrail = 0 }
    for _, r in results do
        s.total += 1
        if r.class == "OFFSTAGE" then
            s.offstage += 1
        elseif r.class == "SKYLINE" then
            s.skyline += 1
        else
            s.againstRock += 1
        end
        if r.nearTrail then
            s.nearTrail += 1
        end
    end
    return s
end

--[=[
	The impostor set: silhouetted against sky, and far enough away that crossed planes
	will not give themselves away. Held back separately are the near-trail skyline trees,
	which stay at full detail.
]=]
function OffstageCull.impostorSet(results: { Result }): ({ string }, { string })
    local swap, hold = {}, {}
    for _, r in results do
        if r.class == "SKYLINE" then
            if r.nearTrail then
                table.insert(hold, r.id)
            else
                table.insert(swap, r.id)
            end
        end
    end
    return swap, hold
end

return OffstageCull
