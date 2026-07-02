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

-- ============================================================================
-- dress() — THE CANONICAL STEP RECIPE ("worn dark timber backed by worn
-- flagstone", user-locked 2026-07-02 on the NW1012 stairway; supersedes the
-- earlier slate-slab and cobble-dome treatments for steps everywhere).
-- Per step: a worn timber riser beam at the front (top = tread), a fine-gravel
-- bed spanning riser to riser, and (where the tread is deep enough) flat
-- flagstones with rough notched organic outlines. Pure data out; the Studio
-- mirror turns flags into a published EditableMesh (chunk <= 20 steps per mesh:
-- Studio's triangle limit) and the rest into Parts.
-- ============================================================================

type Pt = { u: number, v: number }

local function subdivide(poly: { Pt }, maxSeg: number): { Pt }
    local out = {}
    for i = 1, #poly do
        local a, b = poly[i], poly[(i % #poly) + 1]
        table.insert(out, a)
        local d = math.sqrt((b.u - a.u) ^ 2 + (b.v - a.v) ^ 2)
        local nSub = math.floor(d / maxSeg)
        for k = 1, nSub do
            local t = k / (nSub + 1)
            table.insert(out, { u = a.u + (b.u - a.u) * t, v = a.v + (b.v - a.v) * t })
        end
    end
    return out
end

local function chaikin(poly: { Pt }): { Pt }
    local out = {}
    for i = 1, #poly do
        local a, b = poly[i], poly[(i % #poly) + 1]
        table.insert(out, { u = 0.75 * a.u + 0.25 * b.u, v = 0.75 * a.v + 0.25 * b.v })
        table.insert(out, { u = 0.25 * a.u + 0.75 * b.u, v = 0.25 * a.v + 0.75 * b.v })
    end
    return out
end

local function clipCell(poly: { Pt }, S: Pt, O: Pt): { Pt }
    local dx, dv = S.u - O.u, S.v - O.v
    local mx, mv = (S.u + O.u) / 2, (S.v + O.v) / 2
    local function inside(p: Pt)
        return (p.u - mx) * dx + (p.v - mv) * dv >= 0
    end
    local function isect(a: Pt, b: Pt): Pt
        local da = (a.u - mx) * dx + (a.v - mv) * dv
        local db = (b.u - mx) * dx + (b.v - mv) * dv
        local t = da / (da - db)
        return { u = a.u + (b.u - a.u) * t, v = a.v + (b.v - a.v) * t }
    end
    local out = {}
    for i = 1, #poly do
        local a, b = poly[i], poly[(i % #poly) + 1]
        local ina, inb = inside(a), inside(b)
        if ina then
            table.insert(out, a)
        end
        if ina ~= inb then
            table.insert(out, isect(a, b))
        end
    end
    return out
end

type DressOpts = {
    seed: number,
    riserWidth: number?, -- default 6.4
    riserDepth: number?, -- default 0.45
    splitFrac: number?, -- default 0.35 (chance a beam splits into 2 planks)
    flagHW: number?, -- default 2.7 (flag field half-width)
    flagMinDepth: number?, -- default 0.4 (skip flags on tighter treads)
    bedW: number?, -- default 5.8
    bedH: number?, -- default 1.2
}

function IshidanStairs.dress(layout: any, opts: DressOpts)
    local rng = makeRng(opts.seed)
    local RW = opts.riserWidth or 6.4
    local RD = opts.riserDepth or 0.45
    local splitFrac = opts.splitFrac or 0.35
    local HW = opts.flagHW or 2.7
    local minDepth = opts.flagMinDepth or 0.4
    local bedW = opts.bedW or 5.8
    local bedH = opts.bedH or 1.2
    local out = {}
    for _, s in layout.steps :: { Step } do
        local isLanding = s.kind == "landing"
        local pitch = isLanding and (s.len :: number) or s.pitch
        local front = { s.pos[1] - s.dir[1] * pitch / 2, s.pos[3] - s.dir[2] * pitch / 2 }
        local entry = { i = s.i, kind = s.kind, risers = {}, flags = {}, bed = nil }
        -- worn timber riser beam(s) at the step front (landings get none)
        if not isLanding then
            local split = rng() < splitFrac
            local pieces = split and 2 or 1
            local splitF = 0.35 + 0.3 * rng()
            local widths = pieces == 1 and { RW } or { RW * splitF - 0.03, RW * (1 - splitF) - 0.03 }
            local edge = -RW / 2
            for _, wd in widths do
                local h = 0.6 + 0.12 * rng()
                local cCross = edge + wd / 2
                edge += wd + 0.06
                local tint = math.floor((rng() * 2 - 1) * 7 + 0.5)
                local latJ = (rng() * 2 - 1) * 0.06
                local lenTrim = 0.05 * rng()
                local yaw = (rng() * 2 - 1) * 1.5
                local perp = { -s.dir[2], s.dir[1] }
                table.insert(entry.risers, {
                    pos = {
                        front[1] + s.dir[1] * (RD / 2) + perp[1] * (cCross + latJ),
                        s.tread - h / 2,
                        front[2] + s.dir[2] * (RD / 2) + perp[2] * (cCross + latJ),
                    },
                    dir = s.dir,
                    size = { wd - lenTrim, h, RD },
                    yawDeg = yaw,
                    color = { 72 + tint, 60 + tint, 48 + tint },
                })
            end
        end
        -- fine-gravel bed: spans riser to riser (front+0.2 .. front+pitch+0.3)
        local bedLen = pitch + 0.1
        local bedCtrAlong = 0.2 + bedLen / 2 -- from the front
        entry.bed = {
            pos = {
                front[1] + s.dir[1] * bedCtrAlong,
                s.tread - 0.05 - bedH / 2,
                front[2] + s.dir[2] * bedCtrAlong,
            },
            dir = s.dir,
            size = { bedW, bedH, bedLen },
        }
        -- flat flagstones with rough notched outlines (only where the tread is deep enough)
        local V0 = isLanding and 0.3 or 0.55
        local V1 = isLanding and pitch + 0.7 or pitch - 0.08
        if V1 - V0 >= minDepth then
            local seeds = {}
            local tries = (V1 - V0) > 1.4 and 14 or 8
            for _ = 1, tries do
                local su, sv = -HW + 2 * HW * rng(), V0 + (V1 - V0) * rng()
                local ok = true
                for _, s2 in seeds do
                    if (s2.u - su) ^ 2 + (s2.v - sv) ^ 2 < 1.44 then
                        ok = false
                        break
                    end
                end
                if ok then
                    table.insert(seeds, { u = su, v = sv })
                end
            end
            local R0 = { { u = -HW, v = V0 }, { u = HW, v = V0 }, { u = HW, v = V1 }, { u = -HW, v = V1 } }
            for _, S in seeds do
                local poly = R0
                for _, O in seeds do
                    if O ~= S then
                        poly = clipCell(poly, S, O)
                    end
                    if #poly < 3 then
                        break
                    end
                end
                if #poly >= 3 then
                    local cu, cv = 0, 0
                    for _, p in poly do
                        cu, cv = cu + p.u, cv + p.v
                    end
                    cu, cv = cu / #poly, cv / #poly
                    -- rough outline: subdivide -> radial jitter with notches -> ONE chaikin
                    local ins = {}
                    for _, p in subdivide(poly, 0.45) do
                        local du, dv = cu - p.u, cv - p.v
                        local ml = math.sqrt(du * du + dv * dv)
                        if ml > 1e-4 then
                            local amt = 0.05 + rng() * 0.09
                            local roll = rng()
                            if roll < 0.12 then
                                amt = amt + 0.15 + rng() * 0.18 -- notch
                            elseif roll > 0.92 then
                                amt = amt - 0.06 -- slight bulge
                            end
                            table.insert(ins, { u = p.u + du / ml * amt, v = p.v + dv / ml * amt })
                        end
                    end
                    if #ins >= 3 then
                        ins = chaikin(ins) -- single pass: worn, not oval
                        local topJ = (rng() * 2 - 1) * 0.02
                        local warm = rng() < 0.35
                        local g = math.floor(78 + rng() * 38) -- dark mean ~96, wide spread
                        table.insert(entry.flags, {
                            outline = ins,
                            centroid = { u = cu, v = cv },
                            topJitter = topJ,
                            warm = warm,
                            g = g,
                        })
                    end
                end
            end
        end
        table.insert(out, entry)
    end
    return out
end

return IshidanStairs
