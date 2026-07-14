--!strict
-- Runtime `ops` adapter for B's PadBuilder (injected in main.server.luau). Factory:
-- raycastGround needs the datum-plane Y (from mountCF) as its ray origin and buildPost
-- needs a parent, so both are baked at construction. Productionized verbatim from the
-- throwaway tools/studio/buildPadDemo.luau. Roblox datatypes -> not Lune-testable.
local CollectionService = game:GetService("CollectionService")

local PadOps = {}

local BLACK = Color3.fromRGB(45, 48, 56)
local DECK_WOOD = Color3.fromRGB(150, 120, 85)
-- Engawa railing (koran) palette — matched to the tuned teahouse-1story prefab so the deck
-- rail reads continuous with the building's engawa: wood members dark warm brown, cap charcoal.
local RAIL_WOOD = Color3.fromRGB(74, 55, 38)
local CAP_COLOR = Color3.fromRGB(45, 48, 56)
local BEAM_WOOD = Color3.fromRGB(92, 66, 42)

-- Deck geometry constants. Deck top sits on the y=0 datum plane. Railing dims are FIXED
-- (avatar ergonomics) — they do NOT scale with deckSize; only the footprint scales. Rail
-- dims/heights mirror the tuned teahouse-1story koran (measured 2026-07-12).
local DECK_THK = 0.5 -- slab thickness; top at y=0 => center at -0.25
local BEAM_H, BEAM_W = 0.9, 0.7 -- beam depth (Y) / width; top flush under the slab bottom
-- posts stop at the BEAM UNDERSIDE (the beams rest on them), not at the deck datum. The planner
-- sizes each stilt foot->datum; drop its top by deck+beam thickness, less a 0.1 overlap so the
-- post head buries into the beam bottom (no coplanar z-fight with the beam OR the deck slab).
local POST_HEAD_INSET = DECK_THK + BEAM_H - 0.1
-- 2026-07-13: whole railing raised +0.5 (was too low) and made COLLIDABLE (was pure decoration
-- — no fall-prevention). Now 0.5 taller than the teahouse-1story koran it was matched to.
local CAP_TOP, CAP_H, CAP_W = 2.75, 0.3, 0.45 -- charcoal top rail: top 2.75 above deck, 0.45 wide
local MID_Y, MID_H, MID_W = 1.75, 0.2, 0.15 -- mid rail: 1.75 above deck, thin
local NEWEL_H, NEWEL_W = 2.75, 0.45 -- corner posts rise from the deck to the cap top (flush, no projection)
local BAL_H, BAL_W, BAL_CY = 2.8, 0.15, 1.2 -- balusters; center 1.2 above deck (top ~2.60), bottom ~-0.2
-- invisible continuous fall-guard behind the visible railing: a SMOOTH vertical wall the avatar
-- can't mantle. The spaced bars alone let it auto-climb up and over; a flat wall stops it. 3.5
-- clears the auto-step (~2.5) with margin and stays well under the ~7-stud jump (leaping out still works).
local BARRIER_H, BARRIER_T = 3.5, 0.3
local BAL_GAP = 3.6 -- target clear spacing => ~3.76 center-to-center, matching the koran

function PadOps.new(mountCF: CFrame, parent: Instance)
    -- one anchored wood box at LOCAL (lx,ly,lz), size (sx,sy,sz). Non-colliding by default
    -- (deck slab/beams are decorative here); pass canCollide=true for railing members so they
    -- physically block walk-off. CanQuery stays false either way (collision is physics, not raycast).
    local function box(
        name: string,
        lx: number,
        ly: number,
        lz: number,
        sx: number,
        sy: number,
        sz: number,
        color: Color3,
        material: Enum.Material,
        canCollide: boolean?
    )
        local p = Instance.new("Part")
        p.Name, p.Anchored, p.CanCollide, p.CastShadow, p.CanQuery, p.CanTouch =
            name, true, canCollide == true, false, false, false
        p.Size = Vector3.new(sx, sy, sz)
        p.Color = color
        p.Material = material
        p.CFrame = mountCF * CFrame.new(lx, ly, lz)
        p.Parent = parent
        return p
    end
    return {
        raycastGround = function(x: number, z: number): number?
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Include
            rp.FilterDescendantsInstances = { workspace.Terrain }
            local hit =
                workspace:Raycast(Vector3.new(x, mountCF.Position.Y + 250, z), Vector3.new(0, -350, 0), rp)
            return hit and hit.Position.Y or nil
        end,
        -- a post lands on a path if any AccessKeepOut-tagged part sits in its column
        -- (between the deck top and terrain); omit it and cantilever the deck over the path.
        blockedByPath = function(x: number, z: number, topY: number, groundY: number): boolean
            local tagged = CollectionService:GetTagged("AccessKeepOut")
            local span = topY - groundY
            if #tagged == 0 or span <= 0 then
                return false
            end
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Include
            rp.FilterDescendantsInstances = tagged
            local hit = workspace:Raycast(Vector3.new(x, topY + 1, z), Vector3.new(0, -(span + 2), 0), rp)
            return hit ~= nil
        end,
        buildPost = function(pos: { number }, height: number)
            local p = Instance.new("Part")
            p.Name, p.Anchored, p.CanCollide, p.CastShadow = "PadPost", true, false, false
            -- shorten the planner's foot->datum stilt so its TOP sits at the beam underside, and
            -- lower the centre by half the drop so the FOOT (in the terrain) stays put.
            p.Size = Vector3.new(1.2, math.max(0, height - POST_HEAD_INSET), 1.2)
            p.Color = BLACK
            p.Material = Enum.Material.Wood
            -- world position (planner-projected) with the mount's yaw, so the square post is
            -- square to the deck/beams above it rather than world-axis-aligned
            p.CFrame = CFrame.new(pos[1], pos[2] - POST_HEAD_INSET / 2, pos[3]) * mountCF.Rotation
            p.Parent = parent
        end,
        -- symmetric slab, top on the y=0 datum
        buildDeckSlab = function(fp: { minX: number, maxX: number, minZ: number, maxZ: number })
            local cx, cz = (fp.minX + fp.maxX) / 2, (fp.minZ + fp.maxZ) / 2
            box(
                "PadDeck",
                cx,
                -DECK_THK / 2,
                cz,
                fp.maxX - fp.minX,
                DECK_THK,
                fp.maxZ - fp.minZ,
                DECK_WOOD,
                Enum.Material.WoodPlanks,
                true -- collidable: you stand ON the deck (esp. the cantilevered portion over the drop)
            )
        end,
        -- one beam between two (inset) frame nodes, hung just under the slab bottom. Axis-aligned.
        buildBeam = function(
            a: { id: string, x: number, z: number },
            b: { id: string, x: number, z: number }
        )
            local mx, mz = (a.x + b.x) / 2, (a.z + b.z) / 2
            local cy = -DECK_THK - BEAM_H / 2
            local dx, dz = math.abs(b.x - a.x), math.abs(b.z - a.z)
            if dx >= dz then
                box("PadBeam_" .. a.id .. b.id, mx, cy, mz, dx, BEAM_H, BEAM_W, BEAM_WOOD, Enum.Material.Wood)
            else
                box("PadBeam_" .. a.id .. b.id, mx, cy, mz, BEAM_W, BEAM_H, dz, BEAM_WOOD, Enum.Material.Wood)
            end
        end,
        -- railing along one deck edge: cap rail + mid rail + balusters, outer face flush to the
        -- edge (inset inward by half-width). Side edges (nx~=0, running along Z) own the 4 corner
        -- newels; front/back edges skip end newels so corners aren't doubled.
        buildRailing = function(
            edge: { x1: number, z1: number, x2: number, z2: number, nx: number, nz: number }
        )
            local length = math.sqrt((edge.x2 - edge.x1) ^ 2 + (edge.z2 - edge.z1) ^ 2)
            local mx, mz = (edge.x1 + edge.x2) / 2, (edge.z1 + edge.z2) / 2
            local alongX = math.abs(edge.x2 - edge.x1) >= math.abs(edge.z2 - edge.z1)
            -- unit vector ALONG the edge
            local ux, uz = (edge.x2 - edge.x1) / length, (edge.z2 - edge.z1) / length

            -- cap/mid rails butt BETWEEN the corner newels (span shrunk by a newel at each end)
            -- so they meet the posts flush instead of piercing through them
            local function member(name: string, cy: number, w: number, h: number, color: Color3)
                local ox, oz = mx + edge.nx * (w / 2), mz + edge.nz * (w / 2) -- inset so outer face is flush
                local span = math.max(0, length - 2 * NEWEL_W)
                if alongX then
                    box(name, ox, cy, oz, span, h, w, color, Enum.Material.Wood, true)
                else
                    box(name, ox, cy, oz, w, h, span, color, Enum.Material.Wood, true)
                end
            end
            member("RailCap", CAP_TOP - CAP_H / 2, CAP_W, CAP_H, CAP_COLOR)
            member("RailMid", MID_Y, MID_W, MID_H, RAIL_WOOD)

            local isSide = edge.nx ~= 0 -- left/right edges own the corners
            local function upright(name: string, along: number, w: number, h: number, cy: number)
                local px = edge.x1 + ux * along + edge.nx * (w / 2)
                local pz = edge.z1 + uz * along + edge.nz * (w / 2)
                box(name, px, cy, pz, w, h, w, RAIL_WOOD, Enum.Material.Wood, true)
            end
            if isSide then
                upright("Newel", NEWEL_W / 2, NEWEL_W, NEWEL_H, CAP_TOP - NEWEL_H / 2)
                upright("Newel", length - NEWEL_W / 2, NEWEL_W, NEWEL_H, CAP_TOP - NEWEL_H / 2)
            end
            -- balusters evenly across the span between the corner newels, ~3.76 c/c like the koran
            local usable = length - 2 * NEWEL_W
            local count = math.max(0, math.floor(usable / (BAL_GAP + BAL_W)))
            if count > 0 then
                local step = usable / (count + 1)
                for i = 1, count do
                    upright("Baluster", NEWEL_W + step * i, BAL_W, BAL_H, BAL_CY)
                end
            end

            -- invisible continuous fall-guard: full edge length (covers the corners), outer face
            -- flush to the deck edge, deck to BARRIER_H. Collidable + invisible; the visible koran
            -- still does the looks. A flat wall = nothing for the avatar to step onto.
            local bx, bz = mx + edge.nx * (BARRIER_T / 2), mz + edge.nz * (BARRIER_T / 2)
            local barrier
            if alongX then
                barrier = box(
                    "RailBarrier",
                    bx,
                    BARRIER_H / 2,
                    bz,
                    length,
                    BARRIER_H,
                    BARRIER_T,
                    CAP_COLOR,
                    Enum.Material.Wood,
                    true
                )
            else
                barrier = box(
                    "RailBarrier",
                    bx,
                    BARRIER_H / 2,
                    bz,
                    BARRIER_T,
                    BARRIER_H,
                    length,
                    CAP_COLOR,
                    Enum.Material.Wood,
                    true
                )
            end
            barrier.Transparency = 1
        end,
    }
end

return PadOps
