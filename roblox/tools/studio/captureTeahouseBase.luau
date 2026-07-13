--!strict
-- Capture the perfected canyon TeahousePrototype into the portable base prefab
-- `ServerStorage.StructurePrefabs.teahouse-1story` used by the Structure builder
-- (StructureBuilder / StructurePlanner in src/shared). Run via MCP execute_luau
-- (datamodel Edit) or paste into a Studio command bar. Idempotent: re-running
-- rebuilds the prefab from the current TeahousePrototype.
--
-- Source: bring an up-to-date teahouse into Workspace as `TeahousePrototype` (e.g.
-- clone one of ServerStorage.RetiredLegacyTeahouses.CanyonTeahouses.*, which carry the
-- current chochin lantern).
--
-- BUILDING-ONLY (pad/deck separation, Piece A, 2026-07-12): the DECK is now the PAD's
-- job (PadBuilder builds the slab + engawa railings + beams + posts procedurally). This
-- capture therefore strips ALL deck/veranda geometry and floors the prefab at the building
-- floor so it seats on the procedural deck top (y = 0):
--   * strips deck understructure + veranda: EngawaPost, CrossBeam, Girder, Joist*, Perim*,
--     Deck slab, EngawaF/EngawaS boards, and the koran railing (Newel/Baluster/RailCap/RailMid)
--   * KEEPS the invisible EngawaBarrier/Barrier collision (fall protection) for now — moving
--     it to the pad is a later concern
--   * datum = the building floor = the wall base (SideWall/BackWall underside); only WallPost
--     dips below it (~0.5), embedding into the deck slab. pivot set there, front = veranda (-Z)
--   * Role_timber/wall/roof tags for recolor (building parts only; the deck's Role_cap parts
--     are gone)
--   * MirrorX tags on the building parts that negate-X for a left-hand build (SideWall, side
--     shoji+glow+mull) — the left-hand shoji/SideWall set. (Phase 3 replaces mirror with an
--     openSide shoji-wrap; kept here until then.)
--   * MirrorXRigid tag on the ChochinSwing sub-assembly (a grouped lantern) so the mirror
--     rigid-relocates it rather than reflecting it internally
--   * ShojiBay tag + Bay attribute (1..3) on the front shoji panels
--   * Tatami tag on the mat; FlagMount_1/FlagMount_2 attachments (rehomed to a WallPost, at
--     the preserved eave height — their old PerimF host is now stripped)
-- Prefab is place-only (save the place after); committing a .rbxmx is a follow-up.

local SS = game:GetService("ServerStorage")

-- deck / veranda geometry the pad now owns (prefix match; EngawaBarrier is NOT matched)
local function isDeckPart(name: string): boolean
    return name == "Deck"
        or name == "EngawaF"
        or name == "EngawaS"
        or name:match("^EngawaPost") ~= nil
        or name:match("^EngawaSupport") ~= nil
        or name:match("^Perim") ~= nil
        or name:match("^Joist") ~= nil
        or name:match("^Girder") ~= nil
        or name:match("^CrossBeam") ~= nil
        or name:match("^Newel") ~= nil
        or name:match("^Baluster") ~= nil
        or name:match("^RailCap") ~= nil
        or name:match("^RailMid") ~= nil
end

local function capture()
    local src = workspace:FindFirstChild("TeahousePrototype")
    assert(src, "TeahousePrototype not found in workspace")
    local folder = SS:FindFirstChild("StructurePrefabs") or Instance.new("Folder")
    folder.Name = "StructurePrefabs"
    folder.Parent = SS
    local existing = folder:FindFirstChild("teahouse-1story")
    if existing then
        existing:Destroy()
    end

    local m = src:Clone()
    m.Name = "teahouse-1story"

    -- record the OLD frame-underside datum (Perim underside) in WORLD Y before stripping, so
    -- the flag mounts keep their eave-front world height after the datum moves up to the floor.
    -- World Y (not pivot-local) so it stays comparable to the post-strip datum even though the
    -- default pivot (bbox centre) shifts when the deck parts are removed.
    local oldFrameYWorld = math.huge
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") and p.Name:match("^Perim") then
            oldFrameYWorld = math.min(oldFrameYWorld, p.Position.Y - p.Size.Y / 2)
        end
    end
    assert(oldFrameYWorld < math.huge, "no Perim frame found in the source (unexpected prototype shape)")

    -- 1) strip the pad's job: deck slab, veranda boards, understructure frame, koran railing, posts
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") and isDeckPart(p.Name) then
            p:Destroy()
        end
    end
    m.Parent = folder

    -- 2) datum = building floor = the wall base (SideWall/BackWall underside); author the model
    --    pivot there, facing the veranda (-Z). Only WallPost may dip below (embeds into the slab).
    local piv = m:GetPivot()
    local y0 = math.huge
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") and (p.Name == "SideWall" or p.Name == "BackWall") then
            y0 = math.min(y0, piv:ToObjectSpace(p.CFrame).Position.Y - p.Size.Y / 2)
        end
    end
    assert(y0 < math.huge, "no wall base (SideWall/BackWall) found for the floor datum")

    local BELOW_TOL = 0.6 -- wall posts embed into the deck slab; nothing else may sit below the floor
    local below = {}
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") then
            local lb = piv:ToObjectSpace(p.CFrame).Position.Y - p.Size.Y / 2
            if lb < y0 - 0.01 and not (p.Name == "WallPost" and lb >= y0 - BELOW_TOL) then
                table.insert(below, string.format("%s(%.2f)", p.Name, lb - y0))
            end
        end
    end
    assert(
        #below == 0,
        "parts below the building floor (not a wall-post embed): " .. table.concat(below, ",")
    )

    local posW = piv:PointToWorldSpace(Vector3.new(0, y0, 0))
    local frontW = piv:VectorToWorldSpace(Vector3.new(0, 0, -1))
    m.WorldPivot = CFrame.lookAt(posW, posW + frontW, Vector3.yAxis)
    piv = m:GetPivot()

    -- 3) manifest tags (building parts only — the deck's Role_cap/timber members are stripped)
    local ROLE = {
        RafterTail = "timber",
        BackWall = "wall",
        SideWall = "wall",
        Shoji = "wall",
        RoofF = "roof",
        RoofB = "roof",
        GableA = "roof",
        GableB = "roof",
    }
    local MIRROR = {
        SideWall = true, -- the left-hand SideWall; side shoji handled below. (Phase 3 -> openSide)
    }
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") then
            if ROLE[p.Name] then
                p:AddTag("Role_" .. ROLE[p.Name])
            end
            local sideShoji = (p.Name == "Shoji" or p.Name == "ShojiGlow" or p.Name == "Mull")
                and p.Size.Z > p.Size.X
            if MIRROR[p.Name] or sideShoji then
                p:AddTag("MirrorX")
            end
            if p.Name == "Shoji" and p.Size.X > p.Size.Z then
                local lx = piv:ToObjectSpace(p.CFrame).Position.X
                local bay = ({ [-6] = 1, [0] = 2, [6] = 3 })[math.floor(lx + 0.5)] or 0
                p:AddTag("ShojiBay")
                p:SetAttribute("Bay", bay)
            end
            if p.Name == "Tatami" then
                p:AddTag("Tatami")
            end
        end
    end

    -- 3b) the chochin is a grouped sub-assembly (ChochinSwing) whose part names are not in
    -- the MIRROR set; tag the whole model MirrorXRigid so the mirror relocates it rigidly
    -- to the opposite corner (no internal reflection — a lantern must not be left/right flipped)
    for _, d in m:GetDescendants() do
        if d:IsA("Model") and d.Name == "ChochinSwing" then
            d:AddTag("MirrorXRigid")
        end
    end

    -- 4) flag-mount attachments. Their old host PerimF is stripped; rehome to a WallPost and
    -- preserve the eave-front world height (the datum rose from the frame underside to the floor,
    -- so drop the local Y by that shift).
    local host
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") and p.Name == "WallPost" then
            host = p
        end
    end
    assert(host, "no WallPost host for flag mounts")
    -- posW.Y is the new datum (wall base) in WORLD Y; oldFrameYWorld is the old datum in world Y.
    -- Their difference is the datum rise, frame-independent, so the flag keeps its eave height.
    local flagY = 12 - (posW.Y - oldFrameYWorld)
    for name, lp in { FlagMount_1 = Vector3.new(-9, flagY, -13), FlagMount_2 = Vector3.new(15, flagY, -13) } do
        local a = Instance.new("Attachment")
        a.Name = name
        a.WorldCFrame = piv * CFrame.new(lp)
        a.Parent = host
    end

    return m
end

return capture()
