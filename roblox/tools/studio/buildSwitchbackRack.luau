-- buildSwitchbackRack.luau — the Switchback Deck's public launch rack (2026-09-03)
--
-- HOW TO RUN: paste into the Studio command bar in EDIT mode, press Enter, eyeball the mount
-- plates on the deck (the TUBES appear only at runtime — the public battery in
-- main.server.luau stands a real L tube on every FireworkTubeMount part at boot), then SAVE
-- AND PUBLISH. Idempotent: destroys its own folder before rebuilding.
--
-- WHY PLACE-ONLY, IN ITS OWN FOLDER. The deck model itself is Rojo-managed
-- (RoshamboStage.SwitchbackDeck), so parts added inside it in Studio can be dropped by a
-- rojo build/serve. These mounts float in their own place-only folder positioned OVER the
-- deck, like the rest of the switchback works (PathExtension, DescentPath — place-only by
-- the 2026-06-27 decision).
--
-- Owner direction (2026-09-03): a launch rack tied to the deck — guests fire their first
-- firework here on the onboarding tour. "Rack as shop" (buying at the rack) is banked for
-- after the F&F demo; the hanabiya stays the tour's shop stop.
--
-- Placement: three plates along the East (downcanyon, +X) railing edge of the 18x15 walking
-- surface (centre 159.7/−66.6, top 138.46 — docs/wiki/world/switchback-deck.md), inset 1.5
-- studs, 5 studs apart, mirroring the hanabiya rooftop's TubeMount_1..3 plate dimensions.

local CollectionService = game:GetService("CollectionService")

local TAG = "FireworkTubeMount"
local DECK_TOP = 138.46
local MOUNT_X = 159.7 + 9 - 1.5 -- east edge, inset
-- one mount per tier (owner, 2026-09-03: the three identical L tubes "look like they're
-- all the same?" — a public rack shows the full range, and the battery boot in
-- main.server.luau reads the Tier attribute to stand the matching tube + muzzle height)
local MOUNTS = {
    { z = -71.6, tier = "mortar:S" },
    { z = -66.6, tier = "mortar:M" },
    { z = -61.6, tier = "mortar:L" },
}

local canyonWorld = workspace:FindFirstChild("CanyonWorld")
assert(canyonWorld, "Workspace.CanyonWorld is missing — is this the right place?")

local old = canyonWorld:FindFirstChild("SwitchbackRack")
if old then
    old:Destroy()
end

local folder = Instance.new("Folder")
folder.Name = "SwitchbackRack"
folder.Parent = canyonWorld

for i, m in MOUNTS do
    local p = Instance.new("Part")
    p.Name = "TubeMount_" .. i
    p.Size = Vector3.new(1.4, 0.3, 1.4)
    p.Position = Vector3.new(MOUNT_X, DECK_TOP + 0.15, m.z)
    p:SetAttribute("Tier", m.tier)
    p.Anchored = true
    p.CanCollide = false
    p.CastShadow = false
    p.Material = Enum.Material.Metal
    p.Color = Color3.fromRGB(45, 48, 56) -- the deck family's black understructure tone
    p.Parent = folder
    CollectionService:AddTag(p, TAG)
end

print(
    ("[SwitchbackRack] %d tube mounts (S/M/L) under Workspace.CanyonWorld.SwitchbackRack at deck top %.2f. Tubes appear at runtime. NOW SAVE AND PUBLISH."):format(
        #MOUNTS,
        DECK_TOP
    )
)
