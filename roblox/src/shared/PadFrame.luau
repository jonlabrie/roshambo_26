--!strict
-- Pure layout of a pad's beam frame and post nodes from a deck footprint. IDs match PadPlanner.
-- 2 long beams (front FL-FR, back BL-BR), 3 short (left FL-BL, right FR-BR, middle MF-MB);
-- posts drop from the 6 nodes (PadPlanner owns the terrain raycast). Pure (Lune-tested).
local PadFrame = {}
local PH = 0.6 -- post half-width; outer face flush to the deck corner

export type FP = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Node = { id: string, x: number, z: number }

function PadFrame.nodes(fp: FP): { Node }
    local cx = (fp.minX + fp.maxX) / 2
    return {
        { id = "FL", x = fp.minX + PH, z = fp.minZ + PH },
        { id = "FR", x = fp.maxX - PH, z = fp.minZ + PH },
        { id = "BL", x = fp.minX + PH, z = fp.maxZ - PH },
        { id = "BR", x = fp.maxX - PH, z = fp.maxZ - PH },
        { id = "MF", x = cx, z = fp.minZ + PH },
        { id = "MB", x = cx, z = fp.maxZ - PH },
    }
end

function PadFrame.beams(_fp: FP)
    return {
        { id = "Long_F", from = "FL", to = "FR" },
        { id = "Long_B", from = "BL", to = "BR" },
        { id = "Short_L", from = "FL", to = "BL" },
        { id = "Short_R", from = "FR", to = "BR" },
        { id = "Short_M", from = "MF", to = "MB" },
    }
end

return PadFrame
