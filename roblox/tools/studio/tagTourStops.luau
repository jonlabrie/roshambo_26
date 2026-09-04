-- tagTourStops.luau — the onboarding tour's beam markers (2026-09-03)
--
-- HOW TO RUN: paste into the Studio command bar in EDIT mode, press Enter, then SAVE AND
-- PUBLISH. Idempotent: destroys its own folder and clears its own tags before rebuilding.
--
-- WHAT THESE ARE. TourBeamController.client.luau raises one beam over the tour's next stop,
-- resolved by CollectionService tag (TourGuide.beamTag). Two of the three stops are marked
-- here as place-only invisible parts, per tagLaunchSites.luau's standing rule: never tag
-- rebuilt geometry, and never tag Rojo-managed models (a `rojo build`/serve can drop a tag
-- added only in the place). The THIRD stop, TourStop_Model, is deliberately ABSENT here —
-- teahouse sites are runtime-built, so main.server.luau tags the model pad's deck itself at
-- boot (see the TourModelPadId block).
--
-- Route (owner, 2026-09-03): arena -> hanabiya (buy the firecracker; "rack as shop" at the
-- deck is banked for after the F&F demo) -> Switchback Deck (first launch, same marker
-- position as Site_SwitchbackDeck in tagLaunchSites.luau) -> up the path to the model
-- teahouse at pad T13.

local CollectionService = game:GetService("CollectionService")

local STOPS = {
    {
        tag = "TourStop_Shop",
        pos = Vector3.new(7.3, 122, 43.2),
        note = "the hanabiya — buy the first firecracker",
    },
    {
        tag = "TourStop_Launch",
        pos = Vector3.new(159.7, 138.5, -66.6),
        note = "the FW11 switchback deck — first launch",
    },
}

local canyonWorld = workspace:FindFirstChild("CanyonWorld")
assert(canyonWorld, "Workspace.CanyonWorld is missing — is this the right place?")

local old = canyonWorld:FindFirstChild("TourStops")
if old then
    old:Destroy()
end
local strays = 0
for _, s in STOPS do
    for _, inst in CollectionService:GetTagged(s.tag) do
        CollectionService:RemoveTag(inst, s.tag)
        strays += 1
    end
end

local folder = Instance.new("Folder")
folder.Name = "TourStops"
folder.Parent = canyonWorld

for _, s in STOPS do
    local p = Instance.new("Part")
    p.Name = s.tag
    p.Size = Vector3.new(2, 2, 2)
    p.Position = s.pos
    p.Anchored = true
    p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
    p.CastShadow = false
    p.Transparency = 1
    p:SetAttribute("Note", s.note)
    p.Parent = folder
    CollectionService:AddTag(p, s.tag)
end

print(
    ("[TourStops] %d markers under Workspace.CanyonWorld.TourStops. Cleared %d stray tag(s). TourStop_Model is server-tagged at boot from TourModelPadId. NOW SAVE AND PUBLISH — none of this is in git."):format(
        #STOPS,
        strays
    )
)
