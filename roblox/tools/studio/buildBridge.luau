--!strict
-- buildBridge — gentle Japanese arch footbridges (taiko-bashi) in the deck-timber language.
-- Studio runnable (command bar / MCP execute_luau); builds ad-hoc Parts into Workspace.Bridges, one
-- per-bridge sub-model, idempotent. Endpoints are BAKED per bridge (A/B = the grade-spring point at each
-- landing) — draft markers are deleted in the final terrain, so NO build path may depend on them. To add a
-- bridge: survey its two landing points once, then bake them here. PLACE-ONLY (not Rojo — the fully-curved
-- geometry needs CFrame, which the pure-Lune Spec builders can't use) — SAVE THE PLACE after running.
--
-- Look (user-approved 2026-06-29): a gentle parabola (rise ~3 over the span), dark-timber WoodPlanks deck +
-- curved KŌRAN railing (cap + mid-rail + balusters + end newels) squared to the bridge axis, with a
-- DARK/BLACK top rail (cap), and squared stone footings at the landings. No finials, no invisible walls.
local ws = workspace

-- A/B are baked grade-spring endpoints, surveyed from the approved prototype (NOT read from markers).
-- Optional per-bridge fields (Teahouse3Bridge introduced these, 2026-07-04):
--   rise = 0            -> FLAT span (the parabola degenerates to the straight lerp)
--   footingA {pos,size} -> as-built override for the A footing (user-placed)
--   noFootingB = true   -> skip the B footing (e.g. the deck lands on an engawa; stone would float)
--   pierParts {..}      -> baked as-built stone pier stack (squared to the bridge axis)
local BRIDGES = {
    {
        name = "Bridge3",
        A = { 45.70, 111.40, -13.40 },
        B = { 50.80, 110.80, -36.40 },
        rise = 3.0,
        width = 6.5,
    },
    -- Teahouse3Bridge (2026-07-04): flat span + stone pier, the pad-access bridge for Teahouse_03
    -- (recipe §0.7 — access registers to the pad, replaced Teahouse3Stair/Landing, now parked in
    -- ServerStorage.RetiredTeahouse3Access along with the engawa-corner kōran newel it displaced).
    -- A = the line's crossing of NW2040Path's gorge edge at Step_21 (railing opening steps 20-22,
    -- see buildBambooRailing RUNS); B = 0.4 past Teahouse_03's engawa outer edge, deck top tucked
    -- 0.06 under the engawa lip (no z-fight, no gap). Footing + pier baked AS-BUILT (user-tuned).
    {
        name = "Teahouse3Bridge",
        A = { -144.55, 187.55, 90.43 },
        B = { -180.97, 189.86, 59.73 },
        rise = 0,
        width = 6.5,
        footingA = { pos = { -144.59, 182.77, 90.40 }, size = { 7.50, 8.45, 4.00 } },
        noFootingB = true,
        pierParts = {
            { name = "PierBase", pos = { -168.22, 175.86, 70.48 }, size = { 4.90, 2.00, 4.10 } },
            { name = "PierShaft", pos = { -168.22, 182.05, 70.48 }, size = { 3.75, 12.39, 3.00 } },
            { name = "PierCap", pos = { -168.22, 187.85, 70.48 }, size = { 5.60, 1.20, 3.45 } },
        },
    },
}

-- locked dims / colours
local N = 20 -- deck + cap/mid segments along the span (curve resolution)
local THICK = 0.6 -- deck plank thickness
local RAIL_H, RAIL_INSET = 3.2, 0.35
local NEWEL_W, NEWEL_H, BAL_W, NBAL = 0.62, 3.7, 0.34, 12
local TIMBER = Color3.fromRGB(107, 79, 51) -- deck + rail timber (matches the decks)
local CAP_DARK = Color3.fromRGB(30, 26, 20) -- dark/black top rail
local STONE = Color3.fromRGB(96, 94, 88)

local function part(
    parent: Instance,
    name: string,
    size: Vector3,
    cf: CFrame,
    color: Color3,
    mat: Enum.Material
)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = mat
    p.Parent = parent
    return p
end

local function buildOne(parent: Instance, cfg): string
    local sub = parent:FindFirstChild(cfg.name)
    if sub then
        sub:Destroy()
    end
    sub = Instance.new("Model")
    sub.Name = cfg.name
    sub.Parent = parent

    local A = Vector3.new(cfg.A[1], cfg.A[2], cfg.A[3]) -- baked grade-spring endpoints (no marker dependency)
    local B = Vector3.new(cfg.B[1], cfg.B[2], cfg.B[3])
    local WIDTH, RISE = cfg.width, cfg.rise
    local OFF = WIDTH / 2 - RAIL_INSET
    local dir = Vector3.new(B.X - A.X, 0, B.Z - A.Z).Unit
    local zAxis = Vector3.new(dir.Z, 0, -dir.X) -- horizontal cross axis (everything squares to this)
    local function curve(t: number): Vector3
        local base = A:Lerp(B, t)
        return Vector3.new(base.X, base.Y + RISE * 4 * t * (1 - t), base.Z) -- deck-top follows a parabola
    end

    -- deck planks (top surface follows the curve)
    for i = 0, N - 1 do
        local p0, p1 = curve(i / N), curve((i + 1) / N)
        local mid = (p0 + p1) / 2
        local xA = (p1 - p0).Unit
        local yA = xA:Cross(zAxis).Unit
        part(
            sub,
            "Deck_" .. i,
            Vector3.new((p1 - p0).Magnitude + 0.1, THICK, WIDTH),
            CFrame.fromMatrix(mid - yA * (THICK / 2), xA, yA),
            TIMBER,
            Enum.Material.WoodPlanks
        )
    end

    -- curved KŌRAN railing, both sides
    for _, s in { 1, -1 } do
        local sfx = if s > 0 then "P" else "N"
        local off = zAxis * (s * OFF)
        for i = 0, N - 1 do
            local function pt(t: number, dy: number): Vector3
                return curve(t) + off + Vector3.new(0, dy, 0)
            end
            local c0, c1 = pt(i / N, RAIL_H), pt((i + 1) / N, RAIL_H)
            local cx = (c1 - c0).Unit
            part(
                sub,
                "RailCap" .. sfx .. "_" .. i,
                Vector3.new((c1 - c0).Magnitude + 0.05, 0.3, 0.6),
                CFrame.fromMatrix((c0 + c1) / 2, cx, cx:Cross(zAxis).Unit),
                CAP_DARK,
                Enum.Material.Wood
            )
            local m0, m1 = pt(i / N, RAIL_H - 1.1), pt((i + 1) / N, RAIL_H - 1.1)
            local mx = (m1 - m0).Unit
            part(
                sub,
                "RailMid" .. sfx .. "_" .. i,
                Vector3.new((m1 - m0).Magnitude + 0.05, 0.2, 0.3),
                CFrame.fromMatrix((m0 + m1) / 2, mx, mx:Cross(zAxis).Unit),
                TIMBER,
                Enum.Material.Wood
            )
        end
        for i = 1, NBAL - 1 do
            local base = curve(i / NBAL) + off
            part(
                sub,
                "Bal" .. sfx .. "_" .. i,
                Vector3.new(BAL_W, RAIL_H, BAL_W),
                CFrame.fromMatrix(base + Vector3.new(0, RAIL_H / 2, 0), zAxis, Vector3.yAxis),
                TIMBER,
                Enum.Material.Wood
            )
        end
        for _, t in { 0, 1 } do
            local base = curve(t) + off
            part(
                sub,
                "Newel" .. sfx .. "_" .. t,
                Vector3.new(NEWEL_W, NEWEL_H, NEWEL_W),
                CFrame.fromMatrix(base + Vector3.new(0, NEWEL_H / 2, 0), zAxis, Vector3.yAxis),
                TIMBER,
                Enum.Material.Wood
            )
        end
    end

    -- squared stone footings at the landings (overridable per landing; see BRIDGES field docs)
    if cfg.footingA then
        part(
            sub,
            "Footing_A",
            Vector3.new(cfg.footingA.size[1], cfg.footingA.size[2], cfg.footingA.size[3]),
            CFrame.fromMatrix(
                Vector3.new(cfg.footingA.pos[1], cfg.footingA.pos[2], cfg.footingA.pos[3]),
                zAxis,
                Vector3.yAxis
            ),
            STONE,
            Enum.Material.Slate
        )
    else
        part(
            sub,
            "Footing_A",
            Vector3.new(WIDTH + 1, 3, 4),
            CFrame.fromMatrix(Vector3.new(A.X, A.Y - 1.0, A.Z), zAxis, Vector3.yAxis),
            STONE,
            Enum.Material.Slate
        )
    end
    if not cfg.noFootingB then
        part(
            sub,
            "Footing_B",
            Vector3.new(WIDTH + 1, 3, 4),
            CFrame.fromMatrix(Vector3.new(B.X, B.Y - 1.0, B.Z), zAxis, Vector3.yAxis),
            STONE,
            Enum.Material.Slate
        )
    end

    -- baked as-built stone pier stack, squared to the bridge axis
    for _, pp in (cfg.pierParts or {}) :: { any } do
        part(
            sub,
            pp.name,
            Vector3.new(pp.size[1], pp.size[2], pp.size[3]),
            CFrame.fromMatrix(Vector3.new(pp.pos[1], pp.pos[2], pp.pos[3]), zAxis, Vector3.yAxis),
            STONE,
            Enum.Material.Slate
        )
    end

    return string.format("%s: span %.1f, rise %.1f", cfg.name, (B - A).Magnitude, RISE)
end

local parent = ws:FindFirstChild("Bridges") or Instance.new("Model")
parent.Name = "Bridges"
parent.Parent = ws
local report = {}
for _, cfg in BRIDGES do
    report[#report + 1] = buildOne(parent, cfg)
end
return table.concat(report, "\n")
