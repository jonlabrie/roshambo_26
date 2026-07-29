--!strict
-- Pure geometry for a benched dirt/gravel TRAIL -- the register introduced for the river
-- path's Mid climb (spec section 5a). No Roblox API, so Lune can test it and
-- tools/studio/buildTrailPath.luau can mirror it.
--
-- WHY A TRAIL IS NOT A PATH WITH THE STONEWORK REMOVED. An ishidan path lays a bed per
-- riser and lets the terrain be whatever it is underneath. A trail has no bed: the
-- terrain IS the walking surface, so the geometry problem is the opposite one -- decide
-- what the ground should become, then cut and fill to it.
--
-- That is what `smooth` is for. A trail tread does not follow the ground; it cuts
-- through bumps and fills hollows. Local raw-terrain grade is therefore NOT a step
-- criterion -- measured on this route the raw ground hits 0.58 on stretches whose
-- benched mean is 0.21, and stepping those would put a flight on every gentle slope.
local TrailProfile = {}

export type Sample = {
    x: number,
    y: number,
    z: number,
    s: number, -- arc length along the HORIZONTAL projection, from the east end
}

export type Frame = {
    fx: number, -- unit forward, horizontal (the direction of travel, east -> west)
    fz: number,
    rx: number, -- unit cross-stream, forward rotated -90 degrees about +Y
    rz: number,
}

export type Stone = {
    s: number, -- arc position
    lateral: number, -- offset from the centreline, + is toward `right`
    scale: number,
    yaw: number, -- radians
    sink: number, -- fraction of the stone's height to bury
}

-- MINSTD (Lehmer). Deliberately integer-only: committed assets must hash identically on
-- arm64 and x86_64 or the roblox-ci drift check fails, and transcendental PRNGs do not
-- guarantee that. 16807 * 2147483646 stays under 2^53, so the product is exact in a
-- double.
local function lcg(state: number): (number, number)
    local next_ = (state * 16807) % 2147483647
    return next_, (next_ - 1) / 2147483646
end

TrailProfile.lcg = lcg

local function horizDist(a: { number }, b: { number }): number
    return math.sqrt((b[1] - a[1]) ^ 2 + (b[3] - a[3]) ^ 2)
end

-- Walk the control polyline and emit a sample roughly every `spacing` studs of
-- HORIZONTAL distance.
--
-- EVERY CONTROL POINT IS EMITTED, and each segment is divided into a whole number of
-- EQUAL steps of roughly `spacing`. Two bugs live here, both found by tests:
--
-- 1. Carrying a single global arc phase lets a sample straddle a vertex, and the line
--    then CHORDS THE CORNER off -- 2.5 studs inside the marker on a 90-degree bend at
--    spacing 5. The user drags those markers to particular places; the trail has to go
--    through them.
-- 2. Restarting the phase at each vertex fixes that but leaves a runt step before every
--    one (0.4 studs on an 18.4-stud segment at spacing 2). `smooth` averages over an
--    INDEX window, so a runt step gets the same share of elevation change as a full one
--    -- and dividing that by its tiny run spikes the reported grade past
--    TRAIL_MAX_GRADE on a stretch that is actually fine. Rounding to whole subdivisions
--    keeps every step within half a spacing of the target and the index window honest.
function TrailProfile.resample(control: { { number } }, spacing: number): { Sample }
    assert(#control >= 2, "resample needs at least two control points")
    assert(spacing > 0, "spacing must be positive")

    local out: { Sample } = {}
    local walked = 0
    table.insert(out, { x = control[1][1], y = control[1][2], z = control[1][3], s = 0 })
    for i = 2, #control do
        local a, b = control[i - 1], control[i]
        local segLen = horizDist(a, b)
        if segLen > 1e-6 then
            local n = math.max(1, math.floor(segLen / spacing + 0.5))
            for k = 1, n - 1 do
                local t = k / n
                table.insert(out, {
                    x = a[1] + (b[1] - a[1]) * t,
                    y = a[2] + (b[2] - a[2]) * t,
                    z = a[3] + (b[3] - a[3]) * t,
                    s = walked + segLen * t,
                })
            end
            walked += segLen
            table.insert(out, { x = b[1], y = b[2], z = b[3], s = walked })
        end
    end
    -- a degenerate final segment would have been skipped above
    local last = control[#control]
    local tail = out[#out]
    if math.abs(tail.x - last[1]) > 1e-6 or math.abs(tail.z - last[3]) > 1e-6 then
        table.insert(out, { x = last[1], y = last[2], z = last[3], s = walked })
    end
    return out
end

-- Moving average over Y with a SYMMETRIC SHRINKING WINDOW: at sample i the radius is
-- min(radius, i-1, n-i). At the ends the radius collapses to zero, so BOTH ENDPOINTS
-- SURVIVE EXACTLY -- which is what lets a chapter meet the built stair head at 139.9
-- rather than near it. A fixed window would drag the seam.
function TrailProfile.smooth(samples: { Sample }, radius: number): { Sample }
    assert(radius >= 0, "radius must be non-negative")
    local n = #samples
    local out: { Sample } = {}
    local r = math.floor(radius)
    for i = 1, n do
        local ri = math.min(r, i - 1, n - i)
        local sum, count = 0, 0
        for j = i - ri, i + ri do
            sum += samples[j].y
            count += 1
        end
        table.insert(out, {
            x = samples[i].x,
            y = sum / count,
            z = samples[i].z,
            s = samples[i].s,
        })
    end
    return out
end

-- Unit forward/cross-stream per sample, by central difference so a frame does not jerk
-- at a control point. `right` is forward rotated -90 degrees about +Y, which is the
-- cross-stream direction the Step_<i> contract expects as its RightVector.
function TrailProfile.frames(samples: { Sample }): { Frame }
    local n = #samples
    assert(n >= 2, "frames needs at least two samples")
    local out: { Frame } = {}
    for i = 1, n do
        local a = samples[math.max(1, i - 1)]
        local b = samples[math.min(n, i + 1)]
        local dx, dz = b.x - a.x, b.z - a.z
        local len = math.sqrt(dx * dx + dz * dz)
        if len < 1e-9 then
            dx, dz, len = 1, 0, 1
        end
        local fx, fz = dx / len, dz / len
        table.insert(out, { fx = fx, fz = fz, rx = -fz, rz = fx })
    end
    return out
end

-- The realised grade between consecutive samples, i.e. what the walker actually climbs
-- AFTER smoothing. This -- not raw terrain -- is what decides whether a stretch needs
-- steps.
function TrailProfile.grades(samples: { Sample }): { number }
    local out: { number } = {}
    for i = 2, #samples do
        local run = samples[i].s - samples[i - 1].s
        if run > 1e-6 then
            table.insert(out, (samples[i].y - samples[i - 1].y) / run)
        else
            table.insert(out, 0)
        end
    end
    return out
end

function TrailProfile.maxGrade(samples: { Sample }): number
    local worst = 0
    for _, g in TrailProfile.grades(samples) do
        worst = math.max(worst, math.abs(g))
    end
    return worst
end

export type StoneOpts = {
    spacing: number, -- mean arc distance between stones
    jitter: number, -- +/- fraction of spacing to shift each stone along the trail
    halfWidth: number, -- the trail's half width
    lateralFrac: number, -- how far out a stone may sit, as a fraction of halfWidth
    minScale: number,
    maxScale: number,
    sinkMin: number,
    sinkMax: number,
}

-- Sparse half-buried stones along the tread. NOT a bed and not a kerb -- the point is a
-- trace that reads as a worn path, so stones sit at irregular arc positions and
-- alternate sides with a deliberate bias rather than lining up.
function TrailProfile.stoneSites(totalLength: number, opts: StoneOpts, seed: number): { Stone }
    assert(opts.spacing > 0, "stone spacing must be positive")
    local out: { Stone } = {}
    local state = (math.floor(seed) % 2147483646) + 1
    local r: number

    local s = opts.spacing * 0.5
    local side = 1
    while s < totalLength do
        state, r = lcg(state)
        local ds = (r * 2 - 1) * opts.jitter * opts.spacing
        local at = s + ds
        if at > 0 and at < totalLength then
            state, r = lcg(state)
            local lateral = side * (0.25 + 0.75 * r) * opts.lateralFrac * opts.halfWidth
            state, r = lcg(state)
            local scale = opts.minScale + (opts.maxScale - opts.minScale) * r
            state, r = lcg(state)
            local yaw = r * math.pi * 2
            state, r = lcg(state)
            local sink = opts.sinkMin + (opts.sinkMax - opts.sinkMin) * r
            table.insert(out, { s = at, lateral = lateral, scale = scale, yaw = yaw, sink = sink })
        end
        -- flip sides most of the time, but not every time: a strict alternation reads
        -- as a planted avenue rather than as scatter
        state, r = lcg(state)
        if r < 0.72 then
            side = -side
        end
        s += opts.spacing
    end
    return out
end

-- Interpolate a position on the resampled line at arc distance `s`.
function TrailProfile.at(samples: { Sample }, s: number): Sample
    local n = #samples
    if s <= samples[1].s then
        return samples[1]
    end
    if s >= samples[n].s then
        return samples[n]
    end
    local lo, hi = 1, n
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        if samples[mid].s <= s then
            lo = mid
        else
            hi = mid
        end
    end
    local a, b = samples[lo], samples[hi]
    local span = b.s - a.s
    local t = span > 1e-9 and (s - a.s) / span or 0
    return {
        x = a.x + (b.x - a.x) * t,
        y = a.y + (b.y - a.y) * t,
        z = a.z + (b.z - a.z) * t,
        s = s,
    }
end

return TrailProfile
