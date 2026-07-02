--!strict
-- Ishidan (stone stair) layout: from a centerline polyline, compute uniform-riser
-- flights, flat landings, and per-step positions/headings. Pure + deterministic
-- (seeded LCG, no math.random) so it is Lune-tested; the Studio runnable
-- (tools/studio/buildIshidanStairs.luau) mirrors this logic since MCP Studio
-- scripts cannot require repo modules — keep them in sync.
-- Spec: docs/superpowers/specs/2026-07-01-zendojo-nw1012-ishidan-stairway-design.md
local IshidanStairs = {}

local function hyp(dx: number, dz: number): number
    return math.sqrt(dx * dx + dz * dz)
end

-- Catmull-Rom through control points (clamped ends), sampled ~every `spacing`
-- studs of horizontal arc. Returns { {x, y, z} }, endpoints included.
function IshidanStairs.resample(control: { { number } }, spacing: number): { { number } }
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
export type Step = {
    i: number,
    kind: string,
    pos: { number },
    dir: { number },
    tread: number,
    riser: number,
    pitch: number,
    len: number?,
}

-- cumulative horizontal arc table + sampler for pos/dir at an arc distance
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

function IshidanStairs.layout(polyline: { { number } }, opts: LayoutOpts)
    local total, at = arcTable(polyline)
    -- flight arc boundaries from landings (foot-first fracs)
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

    -- flight end elevations: intermediate boundaries follow the polyline profile
    -- (snapped analytic); the final flight ends exactly at headY.
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

-- deterministic LCG (Numerical Recipes constants), returns [0,1)
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
    splitFrac: number?, -- probability a step splits into 2 stones (default 0.5)
    yawDeg: number?, -- max per-stone yaw jitter (default 2)
    latJitter: number?, -- max per-stone lateral jitter (default 0.15)
}

function IshidanStairs.slabs(layout: any, opts: SlabOpts)
    local rng = makeRng(opts.seed)
    local splitFrac = opts.splitFrac or 0.5
    local yawAmp = opts.yawDeg or 2
    local latAmp = opts.latJitter or 0.15
    local out = {}
    for _, s in layout.steps :: { Step } do
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

return IshidanStairs
