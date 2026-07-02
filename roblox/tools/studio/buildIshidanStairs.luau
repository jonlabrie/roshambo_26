-- buildIshidanStairs.luau — slate ishidan stairway from a BAKED centerline.
-- MIRROR of tools/builders/IshidanStairs.luau (Lune-tested) — keep in sync.
-- Run in Studio (command bar / MCP execute_luau, Edit datamodel). Idempotent:
-- destroys and rebuilds Workspace.<CONFIG.outModel>.
-- Part contract for downstream builders (ishigaki/railing/chochin): per step a
-- full-width bed Part "Step_<i>" (RightVector = cross-stream, top = tread-0.05)
-- plus Slate stones "Stone_<i>a/b". CONFIG.buildRange stages partial builds
-- WITHOUT reshuffling jitter (slabs always computes every step; the range only
-- filters Part creation — do not "optimize" by slicing steps before slabs).
-- Spec: docs/superpowers/specs/2026-07-01-zendojo-nw1012-ishidan-stairway-design.md
local CONFIG = {
    outModel = "NW1012Stairs",
    -- BAKED {x,y,z} centerline control points, FOOT (pad edge) FIRST —
    -- from bakeNW1012Stairway.luau, surveyed 2026-07-02:
    control = {
        -- stair foot = pad stair-side edge midpoint (pad top level)
        { 50.65, 113.30, 43.28 },
        -- foot marker (terrain Y - 1; interior Y only shapes flight-boundary grades)
        { 47.85, 116.65, 45.22 },
        -- old timber centers (tread grade)
        { 45.00, 120.20, 47.18 },
        { 41.77, 122.27, 49.05 },
        { 38.95, 124.45, 50.60 },
        { 36.10, 126.36, 52.01 },
        { 33.14, 128.10, 53.40 },
        { 29.73, 130.24, 55.11 },
        { 26.84, 132.40, 56.65 },
        { 23.60, 134.00, 58.27 },
        { 19.86, 135.80, 60.03 },
        { 16.15, 138.05, 61.52 },
        { 13.04, 140.16, 62.59 },
        { 9.86, 141.96, 63.69 },
        { 6.56, 143.72, 64.89 },
        { 3.23, 145.41, 66.11 },
        { -0.46, 147.40, 67.35 },
        { -3.58, 149.18, 68.26 },
        { -6.90, 151.39, 69.29 },
        { -9.60, 153.55, 70.31 },
        { -13.12, 155.80, 71.53 },
        { -16.47, 157.69, 72.55 },
        { -20.43, 159.40, 73.76 },
        { -23.86, 161.09, 74.85 },
        { -27.20, 162.60, 75.93 },
    },
    footY = 113.3, -- pad top; first tread = footY + riser
    headY = 162.6, -- must equal the old Timber_23 top so Rail_NW1012_Tunnel still meets the head
    riserTarget = 0.6,
    landings = { { frac = 0.33, len = 5 }, { frac = 0.66, len = 5 } },
    width = 6.4,
    depth = 1.25,
    body = 0.8,
    bedW = 5.8,
    bedH = 1.2,
    seed = 20260702,
    splitFrac = 0.25, -- calmed from 0.5 (user gate 2026-07-02: "too busy")
    yawDeg = 1.2, -- calmed from 2
    latJitter = 0.1, -- calmed from 0.15
    buildRange = nil, -- {i0, i1} step indices to build; nil = all
    resampleSpacing = 2.0,
    stoneColor = { 96, 98, 94 }, -- base RGB, per-stone tint added
    bedColor = Color3.fromRGB(138, 142, 142),
    -- "" = plain Concrete; ZenCement2 read as river rock at this scale (user gate)
    bedMaterialVariant = "",
}

----------------------------------------------------------------------------
-- >>> MIRRORED from tools/builders/IshidanStairs.luau — KEEP IN SYNC <<<
----------------------------------------------------------------------------
local function hyp(dx: number, dz: number): number
    return math.sqrt(dx * dx + dz * dz)
end

local function resample(control: { { number } }, spacing: number): { { number } }
    local n = #control
    assert(n >= 2, "need at least 2 control points")
    local function P(i: number): { number }
        return control[math.clamp(i, 1, n)]
    end
    local out: { { number } } = { { control[1][1], control[1][2], control[1][3] } }
    for seg = 1, n - 1 do
        local p0, p1, p2, p3 = P(seg - 1), P(seg), P(seg + 1), P(seg + 2)
        local segRun = hyp(p2[1] - p1[1], p2[3] - p1[3])
        local samples = math.max(1, math.ceil(segRun / spacing))
        for k = 1, samples do
            local t = k / samples
            local q = {}
            for a = 1, 3 do
                local t2, t3 = t * t, t * t * t
                q[a] = 0.5
                    * (
                        (2 * p1[a])
                        + (-p0[a] + p2[a]) * t
                        + (2 * p0[a] - 5 * p1[a] + 4 * p2[a] - p3[a]) * t2
                        + (-p0[a] + 3 * p1[a] - 3 * p2[a] + p3[a]) * t3
                    )
            end
            table.insert(out, q)
        end
    end
    return out
end

type Landing = { frac: number, len: number }
type LayoutOpts = { riserTarget: number, footY: number, headY: number, landings: { Landing } }
type Step = {
    i: number,
    kind: string,
    pos: { number },
    dir: { number },
    tread: number,
    riser: number,
    pitch: number,
    len: number?,
}

local function arcTable(polyline: { { number } })
    local cum = { 0 }
    for k = 2, #polyline do
        local a, b = polyline[k - 1], polyline[k]
        cum[k] = cum[k - 1] + hyp(b[1] - a[1], b[3] - a[3])
    end
    local total = cum[#cum]
    local function at(d: number): ({ number }, { number })
        d = math.clamp(d, 0, total)
        for k = 2, #polyline do
            if d <= cum[k] + 1e-9 then
                local a, b = polyline[k - 1], polyline[k]
                local seg = cum[k] - cum[k - 1]
                local t = seg > 1e-9 and (d - cum[k - 1]) / seg or 0
                local run = hyp(b[1] - a[1], b[3] - a[3])
                local dir = run > 1e-9 and { (b[1] - a[1]) / run, (b[3] - a[3]) / run } or { 1, 0 }
                return {
                    a[1] + (b[1] - a[1]) * t,
                    a[2] + (b[2] - a[2]) * t,
                    a[3] + (b[3] - a[3]) * t,
                },
                    dir
            end
        end
        local last = polyline[#polyline]
        return { last[1], last[2], last[3] }, { 1, 0 }
    end
    return total, at
end

local function layout(polyline: { { number } }, opts: LayoutOpts)
    local total, at = arcTable(polyline)
    local marks: { { a0: number, a1: number, landing: Landing? } } = {}
    local cursor = 0
    local sorted = table.clone(opts.landings)
    table.sort(sorted, function(x, y)
        return x.frac < y.frac
    end)
    for _, l in sorted do
        local a = math.clamp(l.frac, 0.05, 0.95) * total
        table.insert(marks, { a0 = cursor, a1 = a, landing = l })
        cursor = a + l.len
    end
    table.insert(marks, { a0 = cursor, a1 = total })

    local steps: { Step } = {}
    local flights = {}
    local E0 = opts.footY
    local idx = 0
    for m, fl in marks do
        local isLast = (m == #marks)
        local posEnd = select(1, at(fl.a1))
        local E1 = if isLast then opts.headY else posEnd[2]
        local rise = E1 - E0
        local runArc = fl.a1 - fl.a0
        local n = math.max(1, math.floor(rise / opts.riserTarget + 0.5))
        local riser = rise / n
        local pitch = runArc / n
        table.insert(flights, { n = n, riser = riser, pitch = pitch })
        for i = 1, n do
            local d = fl.a0 + (i - 0.5) * pitch
            local pos, dir = at(d)
            local tread = E0 + i * riser
            idx += 1
            table.insert(steps, {
                i = idx - 1,
                kind = "step",
                pos = { pos[1], tread, pos[3] },
                dir = dir,
                tread = tread,
                riser = riser,
                pitch = pitch,
            })
        end
        E0 = E1
        if fl.landing then
            local d = fl.a1 + fl.landing.len / 2
            local pos, dir = at(d)
            idx += 1
            table.insert(steps, {
                i = idx - 1,
                kind = "landing",
                pos = { pos[1], E0, pos[3] },
                dir = dir,
                tread = E0,
                riser = 0,
                pitch = 0,
                len = fl.landing.len,
            })
        end
    end
    return { flights = flights, steps = steps }
end

local function makeRng(seed: number): () -> number
    local state = seed % 2 ^ 32
    return function(): number
        state = (1664525 * state + 1013904223) % 2 ^ 32
        return state / 2 ^ 32
    end
end

type SlabOpts = {
    width: number,
    depth: number,
    body: number,
    bedW: number,
    bedH: number,
    seed: number,
    splitFrac: number?,
    yawDeg: number?,
    latJitter: number?,
}

local function slabs(layoutR: any, opts: SlabOpts)
    local rng = makeRng(opts.seed)
    local splitFrac = opts.splitFrac or 0.5
    local yawAmp = opts.yawDeg or 2
    local latAmp = opts.latJitter or 0.15
    local out = {}
    for _, s in layoutR.steps :: { Step } do
        local perp = { -s.dir[2], s.dir[1] } -- unit cross-stream (left of travel)
        if s.kind == "landing" then
            local len = (s.len :: number) + 1
            table.insert(out, {
                i = s.i,
                kind = s.kind,
                stones = {},
                bed = {
                    pos = { s.pos[1], s.tread - 0.05 - opts.bedH / 2, s.pos[3] },
                    dir = s.dir,
                    size = { opts.bedW, opts.bedH, len },
                },
            })
            continue
        end
        local stones = {}
        local split = rng() < splitFrac
        local depth = opts.depth * (0.95 + 0.10 * rng())
        local widths = { opts.width }
        if split then
            local f = 0.4 + 0.2 * rng() -- 40–60% split
            widths = { opts.width * f - 0.04, opts.width * (1 - f) - 0.04 } -- 0.08 grout gap
        end
        local edge = -opts.width / 2
        for _, w in widths do
            local cCross = edge + w / 2
            edge += w + 0.08
            local lat = (rng() * 2 - 1) * latAmp
            local along = (rng() * 2 - 1) * 0.1
            table.insert(stones, {
                pos = {
                    s.pos[1] + perp[1] * (cCross + lat) + s.dir[1] * along,
                    s.tread - opts.body / 2,
                    s.pos[3] + perp[2] * (cCross + lat) + s.dir[2] * along,
                },
                dir = s.dir,
                yawDeg = (rng() * 2 - 1) * yawAmp,
                size = { w, opts.body, depth },
                tint = math.floor((rng() * 2 - 1) * 3 + 0.5),
            })
        end
        table.insert(out, {
            i = s.i,
            kind = s.kind,
            stones = stones,
            bed = {
                -- tucked 0.35 uphill so the bed's downhill face hides behind the
                -- stone's riser face (recipe §1 bed rule); centered beds alternated
                -- concrete/slate riser faces depending on stone jitter (2026-07-02)
                pos = {
                    s.pos[1] + s.dir[1] * 0.35,
                    s.tread - 0.05 - opts.bedH / 2,
                    s.pos[3] + s.dir[2] * 0.35,
                },
                dir = s.dir,
                size = { opts.bedW, opts.bedH, s.pitch + 0.5 },
            },
        })
    end
    return out
end
----------------------------------------------------------------------------
-- >>> END MIRROR <<<
----------------------------------------------------------------------------

local function box(name: string, b, material: Enum.Material, color: Color3, parent: Instance, yawDeg: number?)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Material = material
    p.Color = color
    p.Size = Vector3.new(b.size[1], b.size[2], b.size[3])
    local cross = Vector3.new(-b.dir[2], 0, b.dir[1])
    local cf = CFrame.fromMatrix(Vector3.new(b.pos[1], b.pos[2], b.pos[3]), cross, Vector3.yAxis)
    if yawDeg and yawDeg ~= 0 then
        cf = cf * CFrame.Angles(0, math.rad(yawDeg), 0)
    end
    p.CFrame = cf
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

assert(#CONFIG.control >= 2, "CONFIG.control is empty — paste the baked centerline first (plan Task 4)")

local old = workspace:FindFirstChild(CONFIG.outModel)
if old then
    old:Destroy()
end
local model = Instance.new("Model")
model.Name = CONFIG.outModel
model.Parent = workspace

local polyline = resample(CONFIG.control, CONFIG.resampleSpacing)
local layoutR = layout(polyline, {
    riserTarget = CONFIG.riserTarget,
    footY = CONFIG.footY,
    headY = CONFIG.headY,
    landings = CONFIG.landings,
})
local builds = slabs(layoutR, {
    width = CONFIG.width,
    depth = CONFIG.depth,
    body = CONFIG.body,
    bedW = CONFIG.bedW,
    bedH = CONFIG.bedH,
    seed = CONFIG.seed,
    splitFrac = CONFIG.splitFrac,
    yawDeg = CONFIG.yawDeg,
    latJitter = CONFIG.latJitter,
})
local made = 0
for _, sb in builds do
    if CONFIG.buildRange and (sb.i < CONFIG.buildRange[1] or sb.i > CONFIG.buildRange[2]) then
        continue
    end
    local bed = box("Step_" .. sb.i, sb.bed, Enum.Material.Concrete, CONFIG.bedColor, model)
    if CONFIG.bedMaterialVariant ~= "" then
        bed.MaterialVariant = CONFIG.bedMaterialVariant
    end
    for si, st in sb.stones do
        box(
            "Stone_" .. sb.i .. string.char(96 + si),
            st,
            Enum.Material.Slate,
            Color3.fromRGB(
                CONFIG.stoneColor[1] + st.tint,
                CONFIG.stoneColor[2] + st.tint,
                CONFIG.stoneColor[3] + st.tint
            ),
            model,
            st.yawDeg
        )
    end
    made += 1
end
print(("NW1012Stairs: built %d/%d steps (flights: %d)"):format(made, #builds, #layoutR.flights))
