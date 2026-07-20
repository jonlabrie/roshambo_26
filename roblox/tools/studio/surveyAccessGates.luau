-- Draggable-slab survey for tunnel-mouth access gates (feeds src/server/PadSites.luau's optional
-- `accessGates = { { cframe, size } }` per pad; Task 5's `gatesForPad` already reads this field, so
-- no server logic changes are needed once it's authored). Run in Studio via MCP execute_luau
-- (datamodel Edit) or the command bar. Two modes, toggled by `MODE`:
--
--   MODE = "place": for each pad listed in PAD_IDS, spawns one translucent red slab at that pad's
--     deck placement (its `deckPlacements[deckSize or maxSize]` pivot), raised 4 studs, into
--     workspace.AccessGateSurvey. Drag/rotate/scale each slab to fill its tunnel mouth.
--
--   MODE = "bake": reads every workspace.AccessGateSurvey slab's CFrame + Size and prints one
--     `accessGates = { { cframe = {...}, size = {...} } },` line per pad, labeled with the pad id,
--     to paste into that pad's entry in PadSites.luau.
--
-- PAD_IDS is a human-edited placeholder — set it to the actual tunnel-accessed pads before running
-- MODE="place" (pads reached only by open paths need no accessGates; the derived deck-back gate +
-- backstop already cover them).
--
-- Mirrors tools/studio/surveyDeckPlacements.luau (same findPadSites datamodel-scan pattern, since
-- Rojo maps src/server to ServerScriptService.Roshambo, not ServerScriptService.Server). Place-only
-- (never required by runtime code); the slabs are throwaway and the surveyed values live in git
-- PadSites.

local MODE = "place" -- "place" | "bake"

-- EDIT THESE for the run: the pads whose access is a tunnel (author "where appropriate").
local PAD_IDS = { "T03", "T14" }

local FOLDER_NAME = "AccessGateSurvey"

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
    local old = workspace:FindFirstChild(FOLDER_NAME)
    if old then
        old:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = FOLDER_NAME
    folder.Parent = workspace
    local placed = 0
    for _, padId in PAD_IDS do
        local spec = sites[padId]
        if spec == nil then
            warn(`[survey] unknown pad {padId}`)
            continue
        end
        local place12 = spec.deckPlacements[spec.deckSize] or spec.deckPlacements[spec.maxSize]
        local P = CFrame.new(table.unpack(place12))
        local slab = Instance.new("Part")
        slab.Name = padId
        slab.Anchored = true
        slab.CanCollide = false
        slab.Color = Color3.fromRGB(200, 60, 60)
        slab.Material = Enum.Material.SmoothPlastic
        slab.Transparency = 0.4
        slab.Size = Vector3.new(8, 8, 1)
        slab.CFrame = P + Vector3.new(0, 4, 0)
        slab.Parent = folder
        placed += 1
    end
    return `placed {placed} draggable slabs under workspace.{FOLDER_NAME}; drag each into its tunnel mouth, then set MODE="bake"`
end

local function fmt(v: number): string
    local r = string.format("%.4f", v):gsub("(%..-)0+$", "%1"):gsub("%.$", "")
    if r == "-0" then
        r = "0"
    end
    return r
end

local function arr(nums: { number }): string
    local t = {}
    for i, v in nums do
        t[i] = fmt(v)
    end
    return "{ " .. table.concat(t, ", ") .. " }"
end

local function bake()
    local folder = workspace:FindFirstChild(FOLDER_NAME)
    assert(folder, `no workspace.{FOLDER_NAME} (run MODE="place" first)`)
    local slabs = {}
    for _, child in folder:GetChildren() do
        if child:IsA("BasePart") then
            table.insert(slabs, child)
        end
    end
    table.sort(slabs, function(a, b)
        return a.Name < b.Name
    end)
    local out = {}
    for _, slab in slabs do
        local cf = arr({ slab.CFrame:GetComponents() })
        local sz = arr({ slab.Size.X, slab.Size.Y, slab.Size.Z })
        local line = '["'
            .. slab.Name
            .. '"] accessGates = { { cframe = '
            .. cf
            .. ", size = "
            .. sz
            .. " } },"
        print(line)
        table.insert(out, line)
    end
    print("[survey] paste each printed accessGates line into the matching PadSites entry")
    return table.concat(out, "\n")
end

if MODE == "place" then
    return place()
elseif MODE == "bake" then
    return bake()
else
    error(`surveyAccessGates: unknown MODE '{MODE}'`)
end
