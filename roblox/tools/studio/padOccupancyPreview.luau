--!strict
-- padOccupancyPreview.luau — materialize a LIT, LARGE deck + teahouse on every cliff
-- pad in EDIT mode, so composition work (bamboo, planting, decoration) can see the
-- real occupancy instead of bare terrain slots. Run via MCP execute_luau (Edit).
--
--   local run = require(game.ServerStorage.PadOccupancyPreviewTool)
--   return run({ mode = "on" })    -- build previews (default size L; override size="S"/"M")
--   return run({ mode = "off" })   -- remove them
--
-- NO LOGIC IS MIRRORED HERE: unlike the scatter tools, this requires the REAL
-- Rojo-synced modules living in the place (ReplicatedStorage.RoshamboShared +
-- ServerScriptService.Roshambo) and drives the same TreatmentApplier the runtime
-- uses, with the same deps main.server.luau wires. What players see is what you get.
--
-- The previews live under Workspace.Sandbox.PadOccupancyPreview (Sandbox = throwaway
-- by convention). Turn the mode OFF before publishing; if it ever ships by accident
-- it is visually identical to vacant-pad starter structures, but it does not belong
-- in the place.

local function find(name: string): ModuleScript
    for _, root in { game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService") } do
        for _, d in root:GetDescendants() do
            if d.Name == name and d:IsA("ModuleScript") then
                return d
            end
        end
    end
    error(`padOccupancyPreview: module '{name}' not found in the place — is Rojo synced?`)
end

local PREVIEW_NAME = "PadOccupancyPreview"

local function previewFolder(create: boolean): Folder?
    local sandbox = workspace:FindFirstChild("Sandbox")
    if not sandbox then
        sandbox = Instance.new("Folder")
        sandbox.Name = "Sandbox"
        sandbox.Parent = workspace
    end
    local f = (sandbox :: Instance):FindFirstChild(PREVIEW_NAME)
    if not f and create then
        f = Instance.new("Folder")
        f.Name = PREVIEW_NAME
        f.Parent = sandbox
    end
    return f :: Folder?
end

return function(opts: { mode: string?, size: string? }?): string
    local mode = (opts and opts.mode) or "on"
    if mode == "off" then
        local f = previewFolder(false)
        if f then
            f:Destroy()
            return "[padPreview] off — previews removed"
        end
        return "[padPreview] off — nothing to remove"
    end

    local size = (opts and opts.size) or "L"
    local TreatmentApplier = require(find("TreatmentApplier")) :: any
    local PadSites = require(find("PadSites")) :: any

    local old = previewFolder(false)
    if old then
        old:Destroy()
    end
    local container = previewFolder(true) :: Folder

    local applier = TreatmentApplier.new({
        container = container,
        padBuilder = require(find("PadBuilder")),
        structureBuilder = require(find("StructureBuilder")),
        catalog = require(find("StructureCatalog")),
        structureOps = require(find("StructureOps")),
        padOpsNew = (require(find("PadOps")) :: any).new,
        buildingPlacer = require(find("BuildingPlacer")),
        sizeClasses = require(find("SizeClasses")),
        deckPlacement = require(find("DeckPlacement")),
        decorationLayout = require(find("DecorationLayout")),
        decorationCatalog = require(find("DecorationCatalog")),
    })

    -- a lit, undecorated owner treatment; centered placement is the runtime default
    local CENTERED = { offset = { 0, 0 }, facing = "N" }
    local built, failed = 0, {}
    for padId, spec in PadSites do
        -- respect each perch's cap rather than forcing L onto an S-only site
        local wanted = size
        if spec.maxSize == "S" or (spec.maxSize == "M" and size == "L") then
            wanted = spec.maxSize
        end
        local ok, err = pcall(function()
            applier:apply(padId, spec, {
                kind = "structure",
                loadout = nil,
                lit = true,
                portalOwned = false,
                deckDecorations = nil,
            }, wanted, { size = wanted, loadout = nil, placement = CENTERED })
        end)
        if ok then
            built += 1
        else
            table.insert(failed, padId .. ": " .. tostring(err))
        end
    end
    local msg =
        `[padPreview] on — {built} pads materialized at size {size} under Workspace.Sandbox.{PREVIEW_NAME}`
    if #failed > 0 then
        msg ..= "\nFAILED: " .. table.concat(failed, " | ")
    end
    return msg .. "\nTurn OFF before publishing."
end
