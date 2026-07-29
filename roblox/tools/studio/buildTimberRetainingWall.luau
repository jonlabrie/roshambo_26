--!nocheck
-- buildTimberRetainingWall.luau — reusable timber-lagging retaining wall for CUT faces
-- (recipe §1a "pocket/cutting treatment"). Run in Studio (Edit; command bar / MCP execute_luau).
-- Parts-only (no published meshes), idempotent per wall name.
--
-- Recipe EXTRACTED 2026-07-09 from CanyonWorld/Structures/RetainingWalls/TimberWall_WestTraverse (+
-- Pocket_E/U, NWFallsWall). The load-bearing rules (a wall RETAINS — it is not a fence):
--   * POSTS at EVEN spacing over the whole run: nBays = round(runLen / postRhythm); spacing = runLen/nBays.
--     Never pick an interval then tack a short post on to absorb the remainder.
--   * Each BAY is a level rectangle of full-width lagging courses running POST-CENTRE to POST-CENTRE
--     (one continuous board per course — boards never end between posts). Bays STEP up with the grade.
--   * Board 0.71h x 0.40t, course pitch 0.75 (0.04 gap), length = spacing + 0.2 (laps onto the posts),
--     timber 72/60/48 +/-8. Bay height = round((bayTop-bayFoot)/pitch) courses.
--   * POST 1.1 sq, ink 45/48/56, foot = grade at the post, top = max adjacent bay top + proudTop (~1.3)
--     so it always stands proud of its boards; no top cap.
--   * The top follows the CUT depth ("hold"), which is probed at the step CENTRES only and held flat at
--     the run ends — so post heights progress smoothly with the path and never dip erratically.
--
-- Reads the path model's Step_<i> beds (bed centre = centreline, RightVector = cross-stream, LookVector =
-- travel, tread = bed.Y + 0.65). Registers on the side given by edgeSign (+1 = +RightVector). Parents
-- under CanyonWorld/Structures/RetainingWalls as TimberWall_<model>_<first>_<last>.
local ws = workspace

local CONFIG = {
    walls = {
        {
            model = "FarWall5063Path",
            first = 0,
            last = 3,
            edgeSign = 1,
            offset = 3.6,
            cap = 11,
            seed = 20260709,
        },
        {
            -- River path chapter 1: the Square stairway's SOUTH cut face. +Right is north
            -- here (the drop side, which carries the bamboo rail), so the cut bank is
            -- -Right. The bed is 8.0 wide rather than the network's 5.8, and the measured
            -- face rises between +4 and +6 from the centreline, so offset 5.0 stands the
            -- wall at the face with a 1.0 standoff off the built tread edge.
            model = "RiverSquareStair",
            first = 0,
            last = 41,
            edgeSign = -1,
            offset = 5.0,
            cap = 10,
            seed = 20260729,
        },
    },
    -- locked style:
    boardH = 0.71,
    boardT = 0.40,
    coursePitch = 0.75,
    boardOverlap = 0.2, -- board length = bay spacing + this (laps onto the posts)
    depthJit = 0.12,
    timber = Color3.fromRGB(72, 60, 48),
    timberTint = 8,
    postSq = 1.1,
    postRhythm = 6.0, -- target bay length; actual spacing = runLen / round(runLen/this)
    postProud = 0.25, -- posts stand this far proud toward the path
    postProudTop = 1.3, -- posts rise this far above their tallest adjacent bay
    postInk = Color3.fromRGB(45, 48, 56),
    footDrop = 0.8,
    holdBand = { 4.5, 5.0, 5.5, 6.0 },
    holdMin = 1.5,
    sampleStep = 0.5,
}

local function makeRng(seed)
    local s = seed % 2 ^ 32
    return function()
        s = (1664525 * s + 1013904223) % 2 ^ 32
        return s / 2 ^ 32
    end
end

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { ws.Terrain }
rp.IgnoreWater = true
local function terr(x, z)
    local h = ws:Raycast(Vector3.new(x, 260, z), Vector3.new(0, -160, 0), rp)
    return h and h.Position.Y or nil
end

local function buildWall(cfg)
    local rng = makeRng(cfg.seed)
    local model = ws.CanyonWorld.Paths:FindFirstChild(cfg.model)
    assert(model, "path model not found: " .. cfg.model)

    local steps = {}
    for i = cfg.first, cfg.last do
        local bed = model:FindFirstChild("Step_" .. i)
        assert(bed, "missing Step_" .. i)
        steps[i] = {
            center = Vector2.new(bed.Position.X, bed.Position.Z),
            dir = Vector2.new(bed.CFrame.LookVector.X, bed.CFrame.LookVector.Z).Unit,
            cross = Vector2.new(bed.CFrame.RightVector.X, bed.CFrame.RightVector.Z).Unit,
            tread = bed.Position.Y + 0.65,
            pitch = bed.Size.Z,
        }
    end

    -- cut depth ("hold") probed at step CENTRES only; ends hold the adjacent centre's value (smooth top)
    local function holdAt(p, cross, tread)
        local maxcut = -1e9
        for _, off in CONFIG.holdBand do
            local w = p + cross * (cfg.edgeSign * off)
            local t = terr(w.X, w.Y)
            if t then
                maxcut = math.max(maxcut, t - tread)
            end
        end
        return math.clamp(maxcut, CONFIG.holdMin, cfg.cap)
    end
    local hold = {}
    for i = cfg.first, cfg.last do
        hold[i] = holdAt(steps[i].center, steps[i].cross, steps[i].tread)
    end

    -- centreline controls: front of first -> centres -> back of last (ends reuse the end centre's hold)
    local sF, sL = steps[cfg.first], steps[cfg.last]
    local controls = {
        { p = sF.center - sF.dir * (sF.pitch / 2), tread = sF.tread, hold = hold[cfg.first] },
    }
    for i = cfg.first, cfg.last do
        controls[#controls + 1] = { p = steps[i].center, tread = steps[i].tread, hold = hold[i] }
    end
    controls[#controls + 1] =
        { p = sL.center + sL.dir * (sL.pitch / 2), tread = sL.tread, hold = hold[cfg.last] }

    -- resample -> edge-line samples with foot/top
    local cum = { 0 }
    for i = 2, #controls do
        cum[i] = cum[i - 1] + (controls[i].p - controls[i - 1].p).Magnitude
    end
    local total = cum[#controls]
    local samples = {}
    local d = 0
    while d <= total + 1e-6 do
        local k = 1
        while k < #controls and cum[k + 1] < d do
            k += 1
        end
        local a, b = controls[k], controls[math.min(k + 1, #controls)]
        local seg = cum[math.min(k + 1, #controls)] - cum[k]
        local t = seg > 1e-6 and (d - cum[k]) / seg or 0
        local p = a.p:Lerp(b.p, t)
        local tread = a.tread + (b.tread - a.tread) * t
        local hv = a.hold + (b.hold - a.hold) * t
        local dir = (b.p - a.p)
        dir = dir.Magnitude > 1e-6 and dir.Unit or (a.p - controls[math.max(k - 1, 1)].p).Unit
        local cross = Vector2.new(-dir.Y, dir.X)
        samples[#samples + 1] = {
            edge = p + cross * (cfg.edgeSign * cfg.offset),
            footY = tread - CONFIG.footDrop,
            topY = tread + hv,
            dir = dir,
            cross = cross,
        }
        d += CONFIG.sampleStep
    end
    local function at(arc)
        local fi = math.clamp(arc / CONFIG.sampleStep, 0, #samples - 1)
        local i0 = math.floor(fi) + 1
        local i1 = math.min(i0 + 1, #samples)
        local t = fi - (i0 - 1)
        local a, b = samples[i0], samples[i1]
        local dir = a.dir:Lerp(b.dir, t)
        dir = dir.Magnitude > 1e-6 and dir.Unit or a.dir
        return {
            edge = a.edge:Lerp(b.edge, t),
            footY = a.footY + (b.footY - a.footY) * t,
            topY = a.topY + (b.topY - a.topY) * t,
            dir = dir,
            cross = Vector2.new(-dir.Y, dir.X),
        }
    end

    -- EVEN post spacing over the whole run
    local nBays = math.max(1, math.floor(total / CONFIG.postRhythm + 0.5))
    local spacing = total / nBays
    local postArc = {}
    for i = 0, nBays do
        postArc[i + 1] = i * spacing
    end

    -- (re)create the wall model
    local parent = ws.CanyonWorld.Structures:FindFirstChild("RetainingWalls")
    assert(parent, "CanyonWorld.Structures.RetainingWalls missing")
    local name = string.format("TimberWall_%s_%d_%d", cfg.model, cfg.first, cfg.last)
    local existing = parent:FindFirstChild(name)
    if existing then
        existing:Destroy()
    end
    local wall = Instance.new("Model")
    wall.Name = name
    wall.Parent = parent

    -- bays: level rectangles of full-width courses, post-centre to post-centre
    local bayTop, bayFoot = {}, {}
    local nBoards = 0
    for bi = 1, nBays do
        local a0, a1 = postArc[bi], postArc[bi + 1]
        local mid = at((a0 + a1) / 2)
        local top = mid.topY
        local foot = mid.footY
        bayTop[bi], bayFoot[bi] = top, foot
        local courses = math.max(1, math.floor((top - foot) / CONFIG.coursePitch + 0.5))
        local blen = (a1 - a0) + CONFIG.boardOverlap
        for c = 0, courses - 1 do
            local yc = foot + (c + 0.5) * CONFIG.coursePitch
            local depth = (rng() * 2 - 1) * CONFIG.depthJit
            local ctr = mid.edge + mid.cross * (cfg.edgeSign * (CONFIG.boardT / 2 + depth))
            local tint = math.floor((rng() * 2 - 1) * CONFIG.timberTint + 0.5)
            local part = Instance.new("Part")
            part.Name = "Board_" .. bi .. "_" .. c
            part.Anchored = true
            part.Material = Enum.Material.Wood
            part.Color = Color3.fromRGB(
                math.clamp(72 + tint, 0, 255),
                math.clamp(60 + tint, 0, 255),
                math.clamp(48 + tint, 0, 255)
            )
            part.Size = Vector3.new(blen, CONFIG.boardH, CONFIG.boardT)
            part.CFrame = CFrame.fromMatrix(
                Vector3.new(ctr.X, yc, ctr.Y),
                Vector3.new(mid.dir.X, 0, mid.dir.Y),
                Vector3.yAxis
            )
            part.Parent = wall
            nBoards += 1
        end
    end

    -- posts: foot = grade at the post, top = tallest adjacent bay top + proudTop
    for pi = 1, nBays + 1 do
        local s = at(postArc[pi])
        local topRef = -1e9
        if bayTop[pi - 1] then
            topRef = math.max(topRef, bayTop[pi - 1])
        end
        if bayTop[pi] then
            topRef = math.max(topRef, bayTop[pi])
        end
        local top = topRef + CONFIG.postProudTop
        local foot = s.footY
        local h = math.max(top - foot, 1)
        local ctr = s.edge - s.cross * (cfg.edgeSign * CONFIG.postProud)
        local post = Instance.new("Part")
        post.Name = "Post_" .. pi
        post.Anchored = true
        post.Material = Enum.Material.Wood
        post.Color = CONFIG.postInk
        post.Size = Vector3.new(CONFIG.postSq, h, CONFIG.postSq)
        post.CFrame = CFrame.fromMatrix(
            Vector3.new(ctr.X, (foot + top) / 2, ctr.Y),
            Vector3.new(s.dir.X, 0, s.dir.Y),
            Vector3.yAxis
        )
        post.Parent = wall
    end

    return string.format(
        "%s: %d bays, %d posts (spacing %.2f), %d boards, run %.1f",
        name,
        nBays,
        nBays + 1,
        spacing,
        nBoards,
        total
    )
end

local report = {}
for _, cfg in CONFIG.walls do
    report[#report + 1] = buildWall(cfg)
end
return table.concat(report, "\n")
