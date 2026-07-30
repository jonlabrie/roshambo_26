--!strict
-- Re-point the moss scatter at SINGLE-SIDED meshes and set MeshPart.DoubleSided instead.
--
-- WHY: the moss library was prepped by doubling its geometry — duplicate the shell, reverse
-- the copy — on the false belief that Roblox had no double-sided flag. It does. The place was
-- already relying on it: all 800 MeshParts under CanyonWorld.Foliage.WaterFoliage have
-- DoubleSided set, while MossScatter's 825 clumps carry duplicated shells and not one has the
-- flag. Two approaches to the same problem, and the wasteful one shipped.
--
-- Measured: the kit is 4,521 faces across 49 meshes, doubled to 9,042. Across 825 clumps that
-- is roughly 76,000 triangles of pure duplication.
--
-- ⚠️ SAFE BECAUSE DOUBLING DOES NOT CHANGE A MESH'S BOUNDING BOX. The single-sided mesh has
-- identical extents, so swapping MeshId on a clump that keeps its own Size is visually
-- seamless — no rescaling, no reseating. Each clump also keeps its existing SurfaceAppearance
-- child, since only MeshId changes.
--
-- BEFORE RUNNING:
--   1. Import  Moss Asset Kit/prepped/Moss_ScatterElements_singlesided.fbx  into Studio
--      (geometry import is GUI-only). Leave the result at Workspace root.
--   2. Set NEW_ROOT below to whatever the importer named it.
--   3. Run with DRY_RUN = true first and read the report.
--
-- The old ServerStorage.MossLibrary must still be present: it is what maps an old MeshId back
-- to a mesh NAME, which is the only link between a placed clump and its replacement.
local ServerStorage = game:GetService("ServerStorage")

local NEW_ROOT = "Moss_ScatterElements_singlesided" -- whatever the importer called it
local DRY_RUN = true

local lib = ServerStorage:FindFirstChild("MossLibrary")
local scatter = workspace.CanyonWorld.Foliage:FindFirstChild("MossScatter")
local incoming = workspace:FindFirstChild(NEW_ROOT)

if not lib then
    return "REFUSED: ServerStorage.MossLibrary is missing — it is the old MeshId -> name map"
end
if not scatter then
    return "REFUSED: CanyonWorld.Foliage.MossScatter is missing"
end
if not incoming then
    return ("REFUSED: Workspace.%s not found — import the single-sided FBX first"):format(NEW_ROOT)
end

-- old MeshId -> name, from the library still holding the doubled meshes
local oldIdToName: { [string]: string } = {}
for _, m in ipairs(lib:GetChildren()) do
    if m:IsA("MeshPart") and m.MeshId ~= "" then
        oldIdToName[m.MeshId] = m.Name
    end
end

-- name -> new MeshId, from the freshly imported single-sided set
local nameToNewId: { [string]: string } = {}
local incomingCount = 0
for _, m in ipairs(incoming:GetDescendants()) do
    if m:IsA("MeshPart") and m.MeshId ~= "" then
        nameToNewId[m.Name] = m.MeshId
        incomingCount += 1
    end
end

local swapped, flagged, unmatched = 0, 0, {}
local missingName: { [string]: boolean } = {}

local function convert(p: MeshPart)
    local name = oldIdToName[p.MeshId]
    if not name then
        missingName[p.MeshId] = true
        return
    end
    local newId = nameToNewId[name]
    if not newId then
        if not table.find(unmatched, name) then
            table.insert(unmatched, name)
        end
        return
    end
    if not DRY_RUN then
        p.MeshId = newId
        p.DoubleSided = true
    end
    swapped += 1
    flagged += 1
end

for _, d in ipairs(scatter:GetDescendants()) do
    if d:IsA("MeshPart") then
        convert(d)
    end
end
-- keep the library in step, so a future re-scatter uses the light meshes too
local libSwapped = 0
if not DRY_RUN then
    for _, m in ipairs(lib:GetChildren()) do
        if m:IsA("MeshPart") then
            local newId = nameToNewId[m.Name]
            if newId then
                m.MeshId = newId
                m.DoubleSided = true
                libSwapped += 1
            end
        end
    end
end

local out = {}
table.insert(out, DRY_RUN and "=== DRY RUN — nothing changed ===" or "=== APPLIED ===")
table.insert(out, ("library (old, doubled): %d meshes"):format(#lib:GetChildren()))
table.insert(out, ("incoming (single-sided): %d meshes"):format(incomingCount))
table.insert(out, ("clumps to swap: %d   to flag DoubleSided: %d"):format(swapped, flagged))
if not DRY_RUN then
    table.insert(out, ("library entries updated: %d"):format(libSwapped))
end
local nMissing = 0
for _ in pairs(missingName) do
    nMissing += 1
end
if nMissing > 0 then
    table.insert(out, ("⚠️ %d clump MeshIds are not in MossLibrary — left untouched"):format(nMissing))
end
if #unmatched > 0 then
    table.insert(
        out,
        ("⚠️ %d names had no incoming replacement: %s"):format(#unmatched, table.concat(unmatched, ", "))
    )
end
table.insert(out, "")
table.insert(out, "Set DRY_RUN = false to apply, then SAVE THE PLACE (all of this is place-only).")
return table.concat(out, "\n")
