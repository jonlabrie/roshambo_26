--!strict
-- MCP/Edit: park the fringe trees nobody can see, and tag the rest by what stands
-- BEHIND them. PARKS to ServerStorage — never deletes — so every cut is reversible.
--
-- RUN THIS AFTER EVERY FringeNorth/FringeSouth BAKE. A bake owns its zone folders and
-- rebuilds them wholesale, so hand-curation inside one does not survive. Rather than
-- defend the curation, this REPRODUCES it: same world in, same decision out. The tags
-- are derived data, regenerated on demand, not state anyone has to protect.
--
-- Mirrors tools/builders/OffstageCull.luau (Lune-tested). Studio cannot require from
-- disk, so the classify logic is duplicated below — keep the two in step.
--
-- ⚠️ TWO MEASUREMENT TRAPS, both of which gave me wrong answers on 2026-08-02:
--  1. STRAY PARTS AT THE WORLD ORIGIN. Paths/Flags_7 sits at (0,0,0), underground. A
--     Roblox raycast STARTING INSIDE terrain reports NO HIT, so such a "viewpoint" sees
--     every tree in the canyon through solid rock. The offstage count came out 19
--     instead of 72. Viewpoints are filtered by Position.Magnitude > ORIGIN_EXCLUSION.
--  2. AN OVER-TIGHT WALKABLE FILTER found 3 usable surfaces out of 9,000 parts, which
--     silently made almost everything "invisible". The report prints the viewpoint count
--     and its elevation spread — if either looks thin, the result is not trustworthy.

local CONFIG = {
    dryRun = true, -- set false to actually park and tag
    -- every zone whose planting is judged against the canyon view. The east walls join
    -- here from the start (2026-08-02) rather than being planted full-detail and clawed
    -- back afterwards, which is what happened to the west.
    zones = { "FringeNorth", "FringeSouth", "EastFringeNorth", "EastFringeSouth" },

    -- viewpoints
    floorStepX = 30, -- sample the canyon floor every N studs of X
    floorX0 = -450, -- ...between these, which must span the WHOLE canyon or trees at
    floorX1 = 240, -- the far end get judged with no viewpoint near them
    floorZ = { -40, 0, 40 },
    eyeHeight = 5,
    originExclusion = 40, -- ignore "walkable" parts parked at the world origin
    minWalkable = 4, -- a standable surface is at least this big in X and Z
    levelDot = 0.85, -- ...and its up-vector points this much upward

    -- classification
    maxSight = 800,
    nearTrailRadius = 80, -- impostor planes betray themselves closer than this
    -- FRACTION OF TREE HEIGHT ABOVE THE BASE. 0.65 puts the aim point in the upper
    -- canopy, which is what a distant viewer actually sees over a rim. Aiming lower
    -- (0.15 = the trunk) triples the "invisible" count, because the trunk is occluded
    -- long before the crown is: measured 210 offstage vs the gated answer of 72.
    targetFrac = 0.65,
    hitTolerance = 6, -- a ray landing this close counts as reaching the tree
    behindDistance = 500, -- how far past the tree to look for rock

    -- SPECIES BARRED FROM THE SKYLINE. A skyline tree is seen small against sky, so an
    -- expensive one earns nothing there. XfSugi40 costs 18,125 tris and REFUSES to
    -- cheapen: a reduced-budget export came out 126 tris HEAVIER, because its 38,780
    -- tiny sprays need most of that budget just to avoid going bald. User's call
    -- 2026-08-02: "why bother with Sugi if it's larger? Let's just remove Sugi from the
    -- skyline entirely." Parked like any offstage tree so a re-bake cannot reintroduce
    -- them. They stay fine ANYWHERE ELSE — this bars them from the skyline only.
    skylineExclude = { XfSugi40 = true },

    -- CHEAP GEOMETRY FOR THE SKYLINE. A skyline tree is never seen closer than
    -- nearTrailRadius, so it does not need the canopy a walked-past tree needs. These
    -- are the same species re-exported at a lower budget (export_forest_kit style,
    -- foliage 3500 / wood 3000, spray sqrt(total/kept)), user-gated 2026-08-02 at
    -- 38-40% of full cost. The full-detail template keeps its own name and is what a
    -- bake still plants; this step swaps only the tagged skyline instances afterwards,
    -- which is what makes the whole arrangement survive a re-bake.
    skylineSwap = {
        XfHinokiM = "XfHinokiM_sky",
        XfSpruceM = "XfSpruceM_sky",
        XfFirM = "XfFirM_sky",
    },

    parkFolder = "OffstagePlateau", -- a date suffix is appended
    tagSkyline = "SkylineImpostorCandidate",
    tagNearTrail = "SkylineNearTrail",
}

local ws = workspace
local ss = game:GetService("ServerStorage")
local cs = game:GetService("CollectionService")

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { ws.CanyonWorld.Foliage }
params.IgnoreWater = true

-- ── viewpoints: everywhere a player can stand, at eye height ──────────────────────────
local function collectViewpoints(): ({ Vector3 }, { [number]: number })
    local views: { Vector3 } = {}
    local elevations: { [number]: number } = {}

    for x = CONFIG.floorX0, CONFIG.floorX1, CONFIG.floorStepX do
        for _, z in CONFIG.floorZ do
            local hit = ws:Raycast(Vector3.new(x, 520, z), Vector3.new(0, -700, 0), params)
            if hit then
                table.insert(views, hit.Position + Vector3.new(0, CONFIG.eyeHeight, 0))
            end
        end
    end

    for _, name in { "Paths", "Structures" } do
        local folder = ws.CanyonWorld:FindFirstChild(name)
        if folder then
            for _, d in folder:GetDescendants() do
                if
                    d:IsA("BasePart")
                    and d.Size.X >= CONFIG.minWalkable
                    and d.Size.Z >= CONFIG.minWalkable
                    and d.CFrame.UpVector.Y > CONFIG.levelDot
                    and d.Position.Magnitude > CONFIG.originExclusion -- trap 1
                then
                    table.insert(views, d.Position + Vector3.new(0, d.Size.Y / 2 + CONFIG.eyeHeight, 0))
                    local band = math.floor(d.Position.Y / 40) * 40
                    elevations[band] = (elevations[band] or 0) + 1
                end
            end
        end
    end
    return views, elevations
end

-- ── the trees under consideration ─────────────────────────────────────────────────────
type Tree = { inst: Instance, id: string, base: Vector3, target: Vector3, height: number }

local function collectTrees(): { Tree }
    local trees: { Tree } = {}
    local preserve = ws.CanyonWorld.Foliage:FindFirstChild("Preserve")
    if preserve == nil then
        return trees
    end
    for _, zoneName in CONFIG.zones do
        local zone = preserve:FindFirstChild(zoneName)
        if zone then
            for i, inst in zone:GetChildren() do
                if inst:IsA("Model") or inst:IsA("BasePart") then
                    local cf, size = (inst :: any):GetBoundingBox()
                    local base = Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)
                    table.insert(trees, {
                        inst = inst,
                        -- id must be STABLE across runs and unique: name alone is not
                        id = `{zoneName}#{i}#{inst.Name}#{math.floor(base.X)},{math.floor(base.Z)}`,
                        base = base,
                        target = base + Vector3.new(0, size.Y * CONFIG.targetFrac, 0),
                        height = size.Y,
                    })
                end
            end
        end
    end
    return trees
end

-- ── classification (mirror of OffstageCull.classify) ──────────────────────────────────
type Result = {
    tree: Tree,
    class: string,
    nearestApproach: number,
    angular: number,
    nearTrail: boolean,
    seenFrom: number,
}

local function classify(trees: { Tree }, views: { Vector3 }): { Result }
    local out: { Result } = {}
    for _, tree in trees do
        local nearest, bestSeeing = math.huge, math.huge
        local bestView: Vector3? = nil
        local seenFrom = 0

        for _, view in views do
            local d = (view - tree.base).Magnitude
            if d < nearest then
                nearest = d
            end
            if d <= CONFIG.maxSight then
                local ray = tree.target - view
                local hit = ws:Raycast(view, ray, params)
                local clear = hit == nil or (hit.Position - tree.target).Magnitude < CONFIG.hitTolerance
                if clear then
                    seenFrom += 1
                    if d < bestSeeing then
                        bestSeeing, bestView = d, view
                    end
                end
            end
        end

        local class, angular = "OFFSTAGE", 0
        if bestView ~= nil then
            angular = tree.height / math.max(bestSeeing, 1e-6)
            -- continue PAST the tree: rock behind = wall texture, sky behind = horizon
            local dir = (tree.target - bestView).Unit
            local behind = ws:Raycast(tree.target + dir * 3, dir * CONFIG.behindDistance, params)
            class = if behind ~= nil then "AGAINST_ROCK" else "SKYLINE"
        end

        table.insert(out, {
            tree = tree,
            class = class,
            nearestApproach = nearest,
            angular = angular,
            nearTrail = nearest < CONFIG.nearTrailRadius,
            seenFrom = seenFrom,
        })
    end
    table.sort(out, function(a, b)
        return a.tree.id < b.tree.id
    end)
    return out
end

-- ── run ───────────────────────────────────────────────────────────────────────────────
return function(opts: { dryRun: boolean?, stamp: string? }?): string
    local dryRun = if opts and opts.dryRun ~= nil then opts.dryRun else CONFIG.dryRun
    local stamp = (opts and opts.stamp) or "undated"

    local views, elevations = collectViewpoints()
    local trees = collectTrees()
    if #trees == 0 then
        return "[offstage] no trees in " .. table.concat(CONFIG.zones, ", ")
    end

    local results = classify(trees, views)

    local offstage, skyline, rock, held = {}, {}, 0, {}
    local barred = 0
    for _, r in results do
        local species = (r.tree.inst.Name:gsub("_%d+$", ""))
        if r.class == "SKYLINE" and CONFIG.skylineExclude[species] then
            -- too expensive to earn its place on the skyline: park it with the offstage set
            barred += 1
            table.insert(offstage, r)
        elseif r.class == "OFFSTAGE" then
            table.insert(offstage, r)
        elseif r.class == "SKYLINE" then
            if r.nearTrail then
                table.insert(held, r)
            else
                table.insert(skyline, r)
            end
        else
            rock += 1
        end
    end

    local lines = {}
    local function say(s: string)
        table.insert(lines, s)
    end
    say(`[offstage] {if dryRun then "DRY RUN — nothing changed" else "APPLYING"}`)
    say(`  viewpoints {#views} (origin strays excluded), trees {#trees}`)
    local bands = {}
    for band, n in elevations do
        table.insert(bands, `y{band}:{n}`)
    end
    table.sort(bands)
    say(`  walkable viewpoint elevations — {table.concat(bands, " ")}`)
    say(
        `  OFFSTAGE {#offstage} (of which {barred} barred from the skyline by species)`
            .. ` | SKYLINE {#skyline} (+{#held} held near a trail) | AGAINST ROCK {rock}`
    )

    if dryRun then
        say("  re-run with dryRun = false to park and tag")
        return table.concat(lines, "\n")
    end

    -- park the offstage trees, preserving where they stood
    local parkRoot = ss:FindFirstChild("ParkedFoliage") or ss
    local dest = parkRoot:FindFirstChild(CONFIG.parkFolder .. "_" .. stamp)
    if dest == nil then
        local f = Instance.new("Folder")
        f.Name = CONFIG.parkFolder .. "_" .. stamp
        f.Parent = parkRoot
        dest = f
    end
    for _, r in offstage do
        local zoneName = r.tree.inst.Parent and r.tree.inst.Parent.Name or "Unknown"
        local sub = (dest :: Instance):FindFirstChild(zoneName)
        if sub == nil then
            local f = Instance.new("Folder")
            f.Name = zoneName
            f.Parent = dest
            sub = f
        end
        r.tree.inst:SetAttribute("ParkedFromZone", zoneName)
        r.tree.inst:SetAttribute("ParkedPivot", tostring(r.tree.base))
        r.tree.inst.Parent = sub
    end

    -- tags are DERIVED: clear them all, then re-apply from this run
    for _, r in results do
        if r.class ~= "OFFSTAGE" then
            cs:RemoveTag(r.tree.inst, CONFIG.tagSkyline)
            cs:RemoveTag(r.tree.inst, CONFIG.tagNearTrail)
            r.tree.inst:SetAttribute(CONFIG.tagSkyline, nil)
            r.tree.inst:SetAttribute(CONFIG.tagNearTrail, nil)
        end
    end
    for _, r in skyline do
        cs:AddTag(r.tree.inst, CONFIG.tagSkyline)
        r.tree.inst:SetAttribute(CONFIG.tagSkyline, true)
    end
    for _, r in held do
        cs:AddTag(r.tree.inst, CONFIG.tagNearTrail)
        r.tree.inst:SetAttribute(CONFIG.tagNearTrail, true)
    end

    -- swap the tagged skyline trees onto their cheap variant, aligned by BOUNDING BOX
    -- (an FBX round-trip moves the model origin, so pivot alignment drifts)
    local kit = ss:FindFirstChild("FoliageKit")
    local swapped = 0
    for _, r in skyline do
        local species = (r.tree.inst.Name:gsub("_%d+$", ""))
        local wanted = CONFIG.skylineSwap[species]
        local tmpl = wanted ~= nil and kit ~= nil and kit:FindFirstChild(wanted) or nil
        if tmpl ~= nil and r.tree.inst:GetAttribute("SkylineVariant") ~= true then
            local inst = r.tree.inst
            local hcf, hsize = (inst :: any):GetBoundingBox()
            local hbase = hcf.Position.Y - hsize.Y / 2
            local yaw = select(2, inst:GetPivot():ToOrientation())
            local c = tmpl:Clone()
            c.Name = inst.Name -- keep the species name stable for every other tool
            local _, s0 = c:GetBoundingBox()
            c:ScaleTo(c:GetScale() * (hsize.Y / s0.Y)) -- ScaleTo is ABSOLUTE
            c.Parent = inst.Parent
            c:PivotTo(CFrame.new(hcf.Position) * CFrame.Angles(0, yaw, 0))
            local c1, s1 = c:GetBoundingBox()
            c:PivotTo(
                c:GetPivot()
                    + Vector3.new(
                        hcf.Position.X - c1.Position.X,
                        hbase - (c1.Position.Y - s1.Y / 2),
                        hcf.Position.Z - c1.Position.Z
                    )
            )
            for k, v in pairs(inst:GetAttributes()) do
                if not k:match("^RBX_") then
                    pcall(function()
                        c:SetAttribute(k, v)
                    end)
                end
            end
            for _, tag in ipairs(cs:GetTags(inst)) do
                pcall(function()
                    cs:AddTag(c, tag)
                end)
            end
            c:SetAttribute("SkylineVariant", true)
            for _, d in c:GetDescendants() do
                if d:IsA("BasePart") then
                    local isFol = d.Name:lower():find("foliage") ~= nil
                    d.DoubleSided = isFol
                    d.CastShadow, d.CanCollide, d.CanQuery, d.CanTouch = false, false, false, false
                    if d:IsA("MeshPart") then
                        d.RenderFidelity = Enum.RenderFidelity.Automatic
                    end
                end
            end
            inst:Destroy()
            r.tree.inst = c
            swapped += 1
        end
    end

    say(`  parked {#offstage} to ServerStorage.ParkedFoliage.{CONFIG.parkFolder}_{stamp}`)
    say(`  swapped {swapped} skyline trees onto their cheap variant`)
    say(`  tagged {#skyline} {CONFIG.tagSkyline}, {#held} {CONFIG.tagNearTrail}`)
    return table.concat(lines, "\n")
end
