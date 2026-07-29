--!strict
-- buildBridge — gentle Japanese arch footbridges (taiko-bashi) in the deck-timber language.
-- Studio runnable (command bar / MCP execute_luau); builds ad-hoc Parts into CanyonWorld/Structures/Bridges
-- (shipped hand-built geometry — NEVER a stray top-level model; see the parent block at the bottom for why),
-- one per-bridge sub-model, idempotent. Endpoints are BAKED per bridge (A/B = the grade-spring point at each
-- landing) — draft markers are deleted in the final terrain, so NO build path may depend on them. To add a
-- bridge: survey its two landing points once, then bake them here. PLACE-ONLY (not Rojo — the fully-curved
-- geometry needs CFrame, which the pure-Lune Spec builders can't use) — SAVE THE PLACE after running.
--
-- Look (user-approved 2026-06-29): a gentle parabola (rise ~3 over the span), dark-timber WoodPlanks deck +
-- curved KŌRAN railing (cap + mid-rail + balusters + end newels) squared to the bridge axis, with a
-- DARK/BLACK top rail (cap), and squared stone footings at the landings. No finials, no invisible walls.
local ws = workspace

-- A/B are baked grade-spring endpoints, surveyed from the approved prototype (NOT read from markers).
-- Optional per-bridge override fields (Bridge3 needs none; kept for future spans e.g. the up-canyon
-- abutment bridge):
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
    -- (Teahouse3Bridge removed 2026-07-09: T03 is served by a bored access tunnel; no bridge to it, ever.)
    {
        -- The river-path trail crossing at the upper pool's west end (chapter data:
        -- tools/builders/RiverPathChapters.luau BRIDGES[1] -- keep A/B in sync).
        -- STYLE "rustic" (user-gated 2026-07-30): the koran railing belongs to the
        -- Square's formal register; 290 studs west the trail wants its own vocabulary
        -- -- a low arch with a single round log handrail on posts, everything in the
        -- dock's weathered grey cypress (Wood + CypressWeathered, 216/214/206), the
        -- same treatment as the falls-steps logs. Stone footings stay.
        name = "RiverCrossing",
        A = { -291.7, 178.6, 10.8 },
        B = { -297.9, 180.4, -11.6 },
        rise = 2.0,
        width = 4.5,
        style = "rustic",
        -- as-built: the end boards sit below the abutment grade (user-gated removal)
        omitBoards = { 0, 1, 29, 30, 31 },
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
-- rustic style: the dock's weathered grey cypress (Wood + CypressWeathered variant)
local CYPRESS = Color3.fromRGB(216, 214, 206)
local RUSTIC_RAIL_H = 2.2 -- log handrail centre height above the deck
local RUSTIC_RAIL_D = 0.36 -- handrail log diameter (user-gated: 20% down from 0.45)
local RUSTIC_POST_D = 0.5
local RUSTIC_RAIL_OVERHANG = 0.45 -- rail runs past the end posts' far face by ~2 inches
-- Low INVISIBLE fall-guard above each rail line, per the deck fall-prevention decision:
-- 3.5 from the deck stops the casual willy-nilly hop, while a deliberate jump-and-climb
-- still clears it -- players must work for the swim.
local RUSTIC_GUARD_H = 3.5
-- rustic deck: cross boards on curved stringers, not a solid curved slab. 2x8 lumber
-- at 1 stud = 1 foot: 2 in = 0.17 thick, 8 in = 0.67 wide.
local BOARD_T = 0.17
local BOARD_W = 0.67
local BOARD_PITCH = 0.74 -- board width + a visible seam
local STRINGER_H = 0.7
local STRINGER_W = 0.45
local STRINGER_INSET = 1.1 -- stringer centreline in from each deck edge

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

    local rustic = cfg.style == "rustic"

    if rustic then
        -- Rustic deck: two curved STRINGERS under CROSS BOARDS -- honest bridge
        -- carpentry, not a solid curved slab (user-gated). The boards' tops follow
        -- the parabola; the stringers hang beneath, tops flush to the board
        -- undersides.
        for _, s in { 1, -1 } do
            local off = zAxis * (s * (WIDTH / 2 - STRINGER_INSET))
            for i = 0, N - 1 do
                local p0, p1 = curve(i / N) + off, curve((i + 1) / N) + off
                local mid = (p0 + p1) / 2
                local xA = (p1 - p0).Unit
                local yA = xA:Cross(zAxis).Unit
                local st = part(
                    sub,
                    ("Stringer%s_%d"):format(if s > 0 then "P" else "N", i),
                    Vector3.new((p1 - p0).Magnitude + 0.12, STRINGER_H, STRINGER_W),
                    CFrame.fromMatrix(mid - yA * (BOARD_T + STRINGER_H / 2), xA, yA),
                    CYPRESS,
                    Enum.Material.Wood
                )
                st.MaterialVariant = "CypressWeathered"
            end
        end
        -- cross boards along the arc, a visible seam between each
        local span = (B - A).Magnitude
        local nBoards = math.max(2, math.floor(span / BOARD_PITCH + 0.5))
        local omit = {}
        for _, i in (cfg.omitBoards or {}) :: { number } do
            omit[i] = true
        end
        for i = 0, nBoards - 1 do
            if omit[i] then
                continue
            end
            local t = (i + 0.5) / nBoards
            local p = curve(t)
            local ahead = curve(math.min(1, t + 0.02))
            local behind = curve(math.max(0, t - 0.02))
            local xA = (ahead - behind).Unit
            local yA = xA:Cross(zAxis).Unit
            local board = part(
                sub,
                "Board_" .. i,
                Vector3.new(BOARD_W, BOARD_T, WIDTH),
                CFrame.fromMatrix(p - yA * (BOARD_T / 2), xA, yA),
                CYPRESS,
                Enum.Material.Wood
            )
            board.MaterialVariant = "CypressWeathered"
        end
    else
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
    end

    -- rustic: a single round log handrail on posts, both sides -- the falls-steps
    -- vocabulary stretched across water. No koran, no balusters, no dark cap.
    if rustic then
        for _, s in { 1, -1 } do
            local sfx = if s > 0 then "P" else "N"
            local off = zAxis * (s * OFF)
            for i = 0, N - 1 do
                local c0 = curve(i / N) + off + Vector3.new(0, RUSTIC_RAIL_H, 0)
                local c1 = curve((i + 1) / N) + off + Vector3.new(0, RUSTIC_RAIL_H, 0)
                local cx = (c1 - c0).Unit
                -- the rail runs PAST the end posts (a couple of inches beyond the
                -- far face), not into their centres -- user-gated
                if i == 0 then
                    c0 -= cx * RUSTIC_RAIL_OVERHANG
                end
                if i == N - 1 then
                    c1 += cx * RUSTIC_RAIL_OVERHANG
                end
                local seg = part(
                    sub,
                    "LogRail" .. sfx .. "_" .. i,
                    Vector3.new((c1 - c0).Magnitude + 0.08, RUSTIC_RAIL_D, RUSTIC_RAIL_D),
                    CFrame.fromMatrix((c0 + c1) / 2, cx, cx:Cross(zAxis).Unit),
                    CYPRESS,
                    Enum.Material.Wood
                )
                seg.Shape = Enum.PartType.Cylinder
                seg.MaterialVariant = "CypressWeathered"
            end
            -- invisible guard panels riding the same curve as the rail
            for i = 0, N - 1 do
                local g0 = curve(i / N) + off + Vector3.new(0, RUSTIC_GUARD_H / 2, 0)
                local g1 = curve((i + 1) / N) + off + Vector3.new(0, RUSTIC_GUARD_H / 2, 0)
                local gx = (g1 - g0).Unit
                local guard = part(
                    sub,
                    "Guard" .. sfx .. "_" .. i,
                    Vector3.new((g1 - g0).Magnitude + 0.05, RUSTIC_GUARD_H, 0.2),
                    CFrame.fromMatrix((g0 + g1) / 2, gx, Vector3.yAxis),
                    CYPRESS,
                    Enum.Material.Wood
                )
                guard.Transparency = 1
                guard.CanQuery = false
                guard.CanTouch = false
            end
            -- round posts: ends + thirds
            for _, t in { 0, 1 / 3, 2 / 3, 1 } do
                local base = curve(t) + off
                local post = part(
                    sub,
                    ("LogPost%s_%d"):format(sfx, math.floor(t * 3 + 0.5)),
                    Vector3.new(RUSTIC_RAIL_H + 0.4, RUSTIC_POST_D, RUSTIC_POST_D),
                    CFrame.fromMatrix(
                        base + Vector3.new(0, (RUSTIC_RAIL_H + 0.4) / 2 - 0.4, 0),
                        zAxis,
                        Vector3.yAxis
                    ) * CFrame.Angles(0, 0, math.rad(90)),
                    CYPRESS,
                    Enum.Material.Wood
                )
                post.Shape = Enum.PartType.Cylinder
                post.MaterialVariant = "CypressWeathered"
            end
        end
    end

    -- curved KŌRAN railing, both sides
    for _, s in { 1, -1 } do
        if rustic then
            break
        end
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

-- Convention (2026-07-09): shipped hand-built geometry lives UNDER CanyonWorld, never as a stray
-- top-level model. A top-level `workspace.Bridges` is exactly what the CanyonWorld/Sandbox cleanup
-- sweeps — Bridge3 was lost that way once and had to be regenerated. Build into
-- CanyonWorld/Structures/Bridges (see the roblox-rojo-vs-place-state memory / verifyWorkspaceConvention).
local canyon = ws:FindFirstChild("CanyonWorld")
assert(canyon, "CanyonWorld missing — run in the canonical place, not a bare/rojo-built place")
local structures = canyon:FindFirstChild("Structures")
assert(structures, "CanyonWorld.Structures missing — workspace convention not established")
local parent = structures:FindFirstChild("Bridges")
if not parent then
    parent = Instance.new("Model")
    parent.Name = "Bridges"
    parent.Parent = structures
end
local report = {}
for _, cfg in BRIDGES do
    report[#report + 1] = buildOne(parent, cfg)
end
return table.concat(report, "\n")
