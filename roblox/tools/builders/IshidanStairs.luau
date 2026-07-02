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

return IshidanStairs
