--!strict
-- Builds `workspace.RanmaCarvings` — the 8 pierced dragon-king ranma carvings that fill the
-- mawari-dōrō lantern's framed openings (ThrowDrum FrameL/R/T/B). Each is a flat DOUBLE-SIDED
-- quad MeshPart (one reusable uploaded quad, aspect 0.756) wearing that dragon's SurfaceAppearance
-- (ColorMap = pierced-albedo with alpha voids, NormalMap = Marigold normal, AlphaMode.Transparency).
-- The sukashibori voids open to the interior so the lit inner drum reads through at night.
--
-- Why a committed .rbxm (not emitted through the ThrowDrum builder): a MeshPart's geometry +
-- SurfaceAppearance can't ride a Rojo .model.json (MeshId-in-JSON renders native/blank). Like the
-- bell + roof, ship it as a binary .rbxm sibling under RoshamboStage. The carvings are STATIC
-- (they hang on the fixed shade, not the spinning drum), so a world-positioned sibling is correct.
--
-- Geometry is anchored to the lantern's vertical axis (drum centre −2,144,0) + the shade radius;
-- if L.throwDrum.pos / radius change, re-read the placed ThrowDrum and update `center`/`carvingR`.
-- Assets come from src/shared/DragonKings.luau (baked below; keep in sync). Pierce = T=45.
--
-- RUN IN STUDIO (Edit) → `workspace.RanmaCarvings` → right-click → Save to File →
-- roblox/assets/meshes/RanmaCarvings.rbxm  (rename .rbxmx→.rbxm). SurfaceAppearance is Play-only,
-- so the shapes show in Edit but the carving/texture only renders in Play.
local AS = game:GetService("AssetService")

local QUAD = "rbxassetid://94915629195429" -- flat double-sided quad, aspect 0.756 (RanmaPanelQuad)
local center = Vector3.new(-2, 144, 0) -- lantern vertical axis (drum centre)
local carvingR = 11.86 -- recessed 0.24 behind the frame outer face (frame centre 11.8, thick 0.6)
local Wc, Hc = 5.494, 7.268 -- carving size (aspect 0.756, fit ~90%×0.95 of the 6.27×7.65 panel)

-- ShadePanel index (1..8) → {facet dir°, dragon, pierced-albedo id, normal id}. Order per
-- DragonKings.DRAGON_FOR_PANEL: Nanda/Upananda on panels 4 & 5 (flank the +Z throw window).
local D = {
    { 30, "Anavatapta", "96668720693029", "120396529915065" },
    { 60, "Manasvin", "117439303532703", "84953931626839" }, -- v2 (head regen)
    { 120, "Utpalaka", "105426174736333", "133499635292704" },
    { 150, "Nanda", "94938052156081", "138076733705219" },
    { 210, "Upananda", "103147334577833", "92424286688223" },
    { 240, "Sagara", "126874855515512", "82854469289249" }, -- v2 (head regen)
    { 300, "Vasuki", "115092310989766", "102918673625575" },
    { 330, "Takshaka", "128096975924524", "121735697769309" },
}

local old = workspace:FindFirstChild("RanmaCarvings")
if old then
    old:Destroy()
end
local model = Instance.new("Model")
model.Name = "RanmaCarvings"
for i, dr in D do
    local adeg, name, pierced, normal = dr[1], dr[2], dr[3], dr[4]
    local a = math.rad(adeg)
    local outward = Vector3.new(-math.sin(a), 0, -math.cos(a))
    local pos = center + outward * carvingR
    local p = AS:CreateMeshPartAsync(Content.fromUri(QUAD), {
        CollisionFidelity = Enum.CollisionFidelity.Box,
        RenderFidelity = Enum.RenderFidelity.Automatic,
    })
    p.Name = "Carving" .. i .. "_" .. name
    p.Anchored = true
    p.DoubleSided = true
    p.TextureID = ""
    p.Material = Enum.Material.Wood
    p.Color = Color3.new(1, 1, 1) -- cypress tone is baked into the albedo; don't double-tint
    p.Size = Vector3.new(Wc, Hc, 0.05)
    p.CFrame = CFrame.lookAt(pos, center, Vector3.yAxis) -- +Z (carving front) faces outward
    local sa = Instance.new("SurfaceAppearance")
    sa.ColorMap = "rbxassetid://" .. pierced
    sa.NormalMap = "rbxassetid://" .. normal
    sa.AlphaMode = Enum.AlphaMode.Transparency
    sa.Parent = p
    p.Parent = model
end
model.Parent = workspace
return "RanmaCarvings built (8 dragons) — Save to File → assets/meshes/RanmaCarvings.rbxm"
