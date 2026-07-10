--!nocheck
-- buildDeckBalustrade.luau — timber post-and-baluster railing on a deck edge, in the LOCKED
-- FallsLanding style (newel posts + hanji result-lanterns + dark caps, top rail cap, mid rail +
-- balusters, invisible fall barrier). Run in Studio (Edit; command bar / MCP execute_luau).
-- Parts-only, idempotent per run. Distinct from the bamboo PATH railing (buildBambooRailing.luau) —
-- this is the formal DECK railing used on landings/overlooks.
--
-- Dims/colours EXTRACTED 2026-07-09 from CanyonWorld/Arena/FallsLanding (user-approved on the
-- JunctionLanding SE edge). Newel lanterns are tagged "BlockLantern" so LanternController drives
-- them (folder-agnostic; see LanternController.client.luau). Geometry is PLACE-ONLY — SAVE THE PLACE.
local CollectionService = game:GetService("CollectionService")
local ws = workspace

local CONFIG = {
    -- one entry per railed edge. `model` = the deck Model (under CanyonWorld); `deckPart` = its slab.
    -- `edgeDir` = world {x, z} outward direction of the edge to rail (the builder picks the deck face
    -- whose outward normal best matches — e.g. SE ≈ {0.707, 0.707}). `inset` = how far the rail
    -- centreline sits inboard of the deck edge so outer faces read flush. `name` labels the sub-model.
    runs = {
        {
            model = ws.CanyonWorld.Structures.JunctionLanding,
            deckPart = "DeckSlab",
            edgeDir = { 0.707, 0.707 }, -- SE
            name = "SE",
            inset = 0.4,
        },
    },
    -- locked style (FallsLanding):
    deckWood = Color3.fromRGB(107, 79, 51),
    ink = Color3.fromRGB(30, 26, 19),
    slate = Color3.fromRGB(45, 48, 56),
    paper = Color3.fromRGB(149, 127, 107),
    lightColor = Color3.fromRGB(255, 190, 120),
    newel = { sq = 0.62, h = 3.70, capY = 1.85 }, -- capY = centre height above deck top
    lantern = { w = 1.0, h = 1.5, ctrY = 4.45 },
    lanternCap = { w = 1.20, h = 0.18, ctrY = 5.29 },
    railCap = { thick = 0.60, h = 0.30, ctrY = 3.20 },
    railMid = { thick = 0.42, h = 0.25, ctrY = 1.60 },
    baluster = { sq = 0.34, h = 3.20, ctrY = 1.60 },
    balusterPitch = 2.6,
    newelInset = 0.31, -- newels sit this far in from the corners (flush)
    barrier = { thick = 0.40, h = 15 },
}

local function buildRun(run)
    local deck = run.model:FindFirstChild(run.deckPart)
    assert(deck, "deckPart not found: " .. run.deckPart)
    local cf = deck.CFrame
    local dirR = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z).Unit
    local dirL = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit
    local target = Vector3.new(run.edgeDir[1], 0, run.edgeDir[2]).Unit
    -- the four candidate faces: outward normal, edge direction, half-length along edge, half-extent outward
    local faces = {
        { nrm = dirR, dir = dirL, halfLen = deck.Size.Z / 2, halfOut = deck.Size.X / 2 },
        { nrm = -dirR, dir = dirL, halfLen = deck.Size.Z / 2, halfOut = deck.Size.X / 2 },
        { nrm = dirL, dir = dirR, halfLen = deck.Size.X / 2, halfOut = deck.Size.Z / 2 },
        { nrm = -dirL, dir = dirR, halfLen = deck.Size.X / 2, halfOut = deck.Size.Z / 2 },
    }
    local best, bestDot = faces[1], -1e9
    for _, f in faces do
        local d = f.nrm:Dot(target)
        if d > bestDot then
            best, bestDot = f, d
        end
    end
    local nrm, dir, halfLen, halfOut = best.nrm, best.dir, best.halfLen, best.halfOut
    local deckTop = deck.Position.Y + deck.Size.Y / 2
    local C = Vector3.new(deck.Position.X, 0, deck.Position.Z) + nrm * (halfOut - run.inset)

    local parent = run.model:FindFirstChild("Railing_" .. run.name)
    if parent then
        parent:Destroy()
    end
    parent = Instance.new("Model")
    parent.Name = "Railing_" .. run.name
    parent.Parent = run.model

    -- length axis = dir; the part's Size.Z runs along dir (CFrame.lookAt Look = dir)
    local function frameAt(x, y, z)
        local p = Vector3.new(x, y, z)
        return CFrame.lookAt(p, p + dir, Vector3.yAxis)
    end
    local function block(name, size, ctr, color, mat)
        local q = Instance.new("Part")
        q.Name = name
        q.Anchored = true
        q.CanCollide = mat ~= nil
        q.Size = size
        q.CFrame = frameAt(ctr.X, ctr.Y, ctr.Z)
        q.Color = color
        q.Material = mat or Enum.Material.Wood
        q.TopSurface = Enum.SurfaceType.Smooth
        q.BottomSurface = Enum.SurfaceType.Smooth
        q.Parent = parent
        return q
    end

    local railLen = 2 * halfLen
    -- top rail cap + mid rail (full edge, centred on C)
    block(
        "RailCap",
        Vector3.new(CONFIG.railCap.thick, CONFIG.railCap.h, railLen),
        Vector3.new(C.X, deckTop + CONFIG.railCap.ctrY, C.Z),
        CONFIG.ink
    )
    block(
        "RailMid",
        Vector3.new(CONFIG.railMid.thick, CONFIG.railMid.h, railLen),
        Vector3.new(C.X, deckTop + CONFIG.railMid.ctrY, C.Z),
        CONFIG.deckWood
    )

    -- balusters between the newels (~balusterPitch spacing)
    local span = 2 * (halfLen - CONFIG.newelInset)
    local nBal = math.max(1, math.floor(span / CONFIG.balusterPitch + 0.5) - 1)
    for k = 1, nBal do
        local t = -1 + 2 * k / (nBal + 1)
        local pos = C + dir * ((halfLen - CONFIG.newelInset) * t)
        block(
            "Baluster" .. k,
            Vector3.new(CONFIG.baluster.sq, CONFIG.baluster.h, CONFIG.baluster.sq),
            Vector3.new(pos.X, deckTop + CONFIG.baluster.ctrY, pos.Z),
            CONFIG.deckWood
        )
    end

    -- newels at both corners: post + hanji lantern (tagged BlockLantern) + dark cap + warm light
    for _, sgn in { 1, -1 } do
        local nm = sgn > 0 and "A" or "B"
        local base = C + dir * ((halfLen - CONFIG.newelInset) * sgn)
        block(
            "Newel" .. nm,
            Vector3.new(CONFIG.newel.sq, CONFIG.newel.h, CONFIG.newel.sq),
            Vector3.new(base.X, deckTop + CONFIG.newel.capY, base.Z),
            CONFIG.deckWood
        )
        local lantern = block(
            "Newel" .. nm .. "Lantern",
            Vector3.new(CONFIG.lantern.w, CONFIG.lantern.h, CONFIG.lantern.w),
            Vector3.new(base.X, deckTop + CONFIG.lantern.ctrY, base.Z),
            CONFIG.paper,
            nil
        )
        lantern.Material = Enum.Material.Neon
        lantern.Transparency = 0.42
        CollectionService:AddTag(lantern, "BlockLantern")
        local light = Instance.new("PointLight")
        light.Name = "Newel" .. nm .. "Light"
        light.Color = CONFIG.lightColor
        light.Brightness = 1.1
        light.Range = 11
        light.Shadows = false
        light.Parent = lantern
        block(
            "Newel" .. nm .. "Cap",
            Vector3.new(CONFIG.lanternCap.w, CONFIG.lanternCap.h, CONFIG.lanternCap.w),
            Vector3.new(base.X, deckTop + CONFIG.lanternCap.ctrY, base.Z),
            CONFIG.slate
        )
    end

    -- invisible fall barrier
    local bar = block(
        "Barrier",
        Vector3.new(CONFIG.barrier.thick, CONFIG.barrier.h, railLen),
        Vector3.new(C.X, deckTop + CONFIG.barrier.h / 2, C.Z),
        CONFIG.deckWood,
        Enum.Material.SmoothPlastic
    )
    bar.Transparency = 1
    bar.CastShadow = false

    return string.format(
        "Railing_%s on %s: railLen=%.1f, %d balusters, 2 newel-lanterns (BlockLantern), inset %.2f",
        run.name,
        run.model.Name,
        railLen,
        nBal,
        run.inset
    )
end

local report = {}
for _, run in CONFIG.runs do
    report[#report + 1] = buildRun(run)
end
return table.concat(report, "\n")
