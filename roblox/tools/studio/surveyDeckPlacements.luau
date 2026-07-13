--!strict
-- Draggable-slab survey for per-size deck placements (feeds src/server/PadSites.luau's
-- `deckPlacements = { S, M, L }`). Run in Studio via MCP execute_luau (datamodel Edit) or the
-- command bar. Two modes, toggled by `MODE`:
--
--   MODE = "place": builds a translucent footprint slab per size (S green, M blue, L orange) for
--     every perch at its current `deckPlacements.L` pivot, into workspace.DeckSurvey. Each slab is
--     a Model (PrimaryPart = Slab) with a gold neon `ViewEdge` strip marking the view side
--     (local -Z). Drag each slab so its footprint touches that perch's access (tunnel/path) and
--     extends toward the view. Rotation + height do not matter — bake locks them (see below).
--
--   MODE = "bake": reads every workspace.DeckSurvey.Deck_<id>_<size> pivot and prints the complete
--     PadSites.luau text (paste it over the file). Per perch, ROTATION and deck-top Y are locked to
--     that perch's L slab (all sizes share the perch's view orientation + deck level); only each
--     slab's dragged X/Z is used. A smaller deck therefore sits further back (toward access) than a
--     larger one, which reaches further toward the view.
--
-- Place-only (the slabs are throwaway; the surveyed values live in git PadSites). Delete
-- workspace.DeckSurvey when done.

local MODE = "place" -- "place" | "bake"

local DECK_BASE_W, DECK_BASE_D = 26, 20 -- S deck footprint (X x Z); scaled by sqrt(area)
local SCALE = { S = 1.0, M = math.sqrt(1.3), L = math.sqrt(1.6) }
local COLOR = {
    S = Color3.fromRGB(85, 205, 120),
    M = Color3.fromRGB(90, 150, 235),
    L = Color3.fromRGB(255, 140, 40),
}
local SIZES = { "S", "M", "L" }

local function findPadSites(): { [string]: any }
    for _, d in game:GetDescendants() do
        if d:IsA("ModuleScript") and d.Name == "PadSites" then
            return require(d) :: any
        end
    end
    error("PadSites ModuleScript not found in the datamodel (is Rojo synced?)")
end

local function place()
    local sites = findPadSites()
    local old = workspace:FindFirstChild("DeckSurvey")
    if old then
        old:Destroy()
    end
    local root = Instance.new("Folder")
    root.Name = "DeckSurvey"
    root.Parent = workspace
    for id, site in sites do
        local lArr = site.deckPlacements.L or site.deckPlacements[site.maxSize]
        local P = CFrame.new(table.unpack(lArr))
        for _, size in SIZES do
            local s = SCALE[size]
            local w, d = DECK_BASE_W * s, DECK_BASE_D * s
            local m = Instance.new("Model")
            m.Name = `Deck_{id}_{size}`
            m.Parent = root
            local slab = Instance.new("Part")
            slab.Name = "Slab"
            slab.Anchored = true
            slab.CanCollide = false
            slab.Size = Vector3.new(w, 0.4, d)
            slab.CFrame = P
            slab.Color = COLOR[size]
            slab.Material = Enum.Material.SmoothPlastic
            slab.Transparency = 0.45
            slab.Parent = m
            local v = Instance.new("Part")
            v.Name = "ViewEdge"
            v.Anchored = true
            v.CanCollide = false
            v.Size = Vector3.new(w, 0.9, 0.6)
            v.CFrame = P * CFrame.new(0, 0.4, -d / 2)
            v.Color = Color3.fromRGB(255, 215, 0)
            v.Material = Enum.Material.Neon
            v.Parent = m
            m.PrimaryPart = slab
        end
    end
    return "placed survey slabs in workspace.DeckSurvey"
end

local function fmt(v: number): string
    local r = string.format("%.4f", v):gsub("(%..-)0+$", "%1"):gsub("%.$", "")
    if r == "-0" then
        r = "0"
    end
    return r
end

local function arr(cf: CFrame): string
    local t = {}
    for i, v in { cf:GetComponents() } do
        t[i] = fmt(v)
    end
    return "{ " .. table.concat(t, ", ") .. " }"
end

local function bake()
    local root = workspace:FindFirstChild("DeckSurvey")
    assert(root, "no workspace.DeckSurvey (run MODE='place' first)")
    local sites = findPadSites()
    local ids = {}
    for id in sites do
        table.insert(ids, id)
    end
    table.sort(ids)
    local out = {}
    for _, id in ids do
        local site = sites[id]
        local lm = root:FindFirstChild(`Deck_{id}_L`)
        assert(lm, `no Deck_{id}_L`)
        local piv = lm:GetPivot()
        local R, ly = piv.Rotation, piv.Position.Y
        local function cfFor(size: string): CFrame
            local m = root:FindFirstChild(`Deck_{id}_{size}`)
            assert(m, `no Deck_{id}_{size}`)
            local p = m:GetPivot().Position
            return CFrame.new(p.X, ly, p.Z) * R
        end
        table.insert(
            out,
            string.format(
                '    ["%s"] = {\n        id = "%s",\n        displayName = "%s",\n        deckPlacements = {\n'
                    .. "            S = %s,\n            M = %s,\n            L = %s,\n        },\n"
                    .. '        maxSize = "%s",\n        deckSize = "%s",\n        vacantForm = "%s",\n    },',
                id,
                id,
                site.displayName,
                arr(cfFor("S")),
                arr(cfFor("M")),
                arr(cfFor("L")),
                site.maxSize,
                site.deckSize,
                site.vacantForm
            )
        )
    end
    return "return {\n" .. table.concat(out, "\n") .. "\n}\n"
end

if MODE == "place" then
    return place()
elseif MODE == "bake" then
    return bake()
else
    error(`surveyDeckPlacements: unknown MODE '{MODE}'`)
end
