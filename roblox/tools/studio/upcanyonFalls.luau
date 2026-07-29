--!strict
-- ZenDojo UP-CANYON FALLS + GREENING — run via MCP execute_luau in EDIT mode.
-- RECOVERY/CHECKPOINT artifact (baked 2026-06-20 from the live RoshamboStage.UpcanyonVFX).
-- The SAVED STUDIO PLACE is the source of truth (it also holds the hand-sculpted pools +
-- ServerStorage terrain backups, which this script does NOT recreate). This script
-- reconstructs the VFX + material tint so they survive even if the place save is lost.
--
-- The watercourse: hero infall plunges from the head cleft into a chain of 8 hand-sculpted
-- sea-level pools stepping down to the clearing, linked by these dual-beam cascades.
--
-- FALL RECIPE (matches the tuned down-canyon DowncanyonVFX): each fall = two FaceCamera
-- Beams on 0.5-stud transparent _TOP/_BOT nodes, in a Persistent Model so they render
-- under StreamingEnabled — a crisp `Cascade` (water tex, Len1) over a wider faint
-- `CascadeSlow` (Len2), white, LightEmission 0.20 — plus a foam mist emitter at the base.
-- GREENING: the cliffs are tinted green by recolouring the Basalt/Rock MATERIAL (keeps the
-- faceted render — repainting rock->grass material would smooth it into a blob). No foliage.

local Terrain = workspace.Terrain
local WTEX, FOAM = "rbxassetid://16808804567", "rbxassetid://16808075391"
local WHITE = Color3.new(1, 1, 1)
local FOAM_COLOR = Color3.fromRGB(225, 232, 236)

-- ===== greening: faceted green cliffs via material tint (global Basalt/Rock) =====
-- revert with Basalt (75,74,74) / Rock (99,100,102) if needed.
Terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(36, 52, 30))
Terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(36, 52, 30))

-- ===== falls VFX =====
local stage = workspace.RoshamboStage
local old = stage:FindFirstChild("UpcanyonVFX")
if old then
    old:Destroy()
end
local vfx = Instance.new("Model")
vfx.Name = "UpcanyonVFX"
vfx.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
vfx.Parent = stage

local function node(x, y, z, nm)
    local p = Instance.new("Part")
    p.Anchored, p.CanCollide, p.Transparency = true, false, 1
    p.Size = Vector3.new(0.5, 0.5, 0.5)
    p.CFrame = CFrame.new(x, y, z)
    p.Name = nm
    p.Parent = vfx
    local a = Instance.new("Attachment")
    a.Parent = p
    return a
end

local CASCADE_TR = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.12, 0.06),
    NumberSequenceKeypoint.new(0.80, 0.12),
    NumberSequenceKeypoint.new(1, 0.40),
})
local SLOW_TR = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.18, 0.50),
    NumberSequenceKeypoint.new(1, 0.70),
})

-- {name, tx,ty,tz, bx,by,bz, cW0,cW1, sW0,sW1, spdC,spdS, mistSize,mistRate}
local FALLS = {
    { "W01_HeroFall", -431, 273, -27, -412, 212, -24, 6, 10, 8, 13, 0.55, 0.35, 10, 20 },
    { "W02_DockFall", -374, 208, -5, -370, 187, -5, 6, 9, 8.4, 12.6, 0.55, 0.35, 7, 12 },
    { "OutfallToMicro", -338, 190, -4, -326, 184, -1, 8, 12, 11.2, 16.8, 0.385, 0.245, 7, 12 },
    { "W04_MicroFall", -306, 184, 4, -296, 176, 4, 4, 6, 5.6, 8.4, 0.55, 0.35, 5, 10 },
    { "W05_LargestFall", -224, 175, 18, -214, 160, 17, 6, 9, 8.4, 12.6, 0.55, 0.35, 8, 16 },
    { "W07_UpperStep", -188, 159, 5, -168, 152, -8, 4, 6, 5.6, 8.4, 0.55, 0.35, 5, 10 },
    { "W08_MidStep", -150, 150, -6, -141, 149, -3, 4, 6, 5.6, 8.4, 0.55, 0.35, 5, 10 },
    { "W10_LowerStep", -132, 148, -3, -126, 143, -3, 3, 4.5, 4, 6, 0.55, 0.35, 4, 8 },
    { "W12_ClearingFall", -83, 133, -11, -74, 111, -10, 6, 9, 8.4, 12.6, 0.55, 0.35, 9, 18 },
}

for _, f in FALLS do
    local a0 = node(f[2], f[3], f[4], f[1] .. "_TOP")
    local a1 = node(f[5], f[6], f[7], f[1] .. "_BOT")
    local function beam(nm, len, spd, w0, w1, tr)
        local b = Instance.new("Beam")
        b.Name, b.Attachment0, b.Attachment1 = nm, a0, a1
        b.Texture, b.TextureMode, b.TextureLength, b.TextureSpeed = WTEX, Enum.TextureMode.Stretch, len, spd
        b.Width0, b.Width1, b.CurveSize0, b.CurveSize1 = w0, w1, 2, -1
        b.Segments, b.FaceCamera = 12, true
        b.Color, b.LightEmission, b.LightInfluence = ColorSequence.new(WHITE), 0.20, 0
        b.Transparency = tr
        b.Parent = a0.Parent
    end
    beam("Cascade", 1, f[12], f[8], f[9], CASCADE_TR)
    beam("CascadeSlow", 2, f[13], f[10], f[11], SLOW_TR)
    -- foam mist at the base
    local mp = Instance.new("Part")
    mp.Name, mp.Anchored, mp.CanCollide, mp.Transparency = f[1] .. "_Mist", true, false, 1
    mp.Size = Vector3.new(1, 1, 1)
    mp.CFrame = CFrame.new(f[5], f[6] + 1, f[7])
    mp.Parent = vfx
    local ma = Instance.new("Attachment")
    ma.Parent = mp
    local e = Instance.new("ParticleEmitter")
    e.Color, e.Texture = ColorSequence.new(FOAM_COLOR), FOAM
    e.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.4, 0.82),
        NumberSequenceKeypoint.new(1, 1),
    })
    e.Size, e.Lifetime, e.Rate = NumberSequence.new(f[14]), NumberRange.new(2.5, 5), f[15]
    e.Speed, e.SpreadAngle, e.Acceleration = NumberRange.new(1, 3), Vector2.new(55, 55), Vector3.new(0, 2, 0)
    e.Rotation, e.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-10, 10)
    e.Parent = ma
end

return ("up-canyon: %d falls rebuilt + cliffs tinted green"):format(#FALLS)
