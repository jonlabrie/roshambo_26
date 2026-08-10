-- tagLaunchSites.luau — the public firework launch sites (2026-08-05)
--
-- HOW TO RUN: paste into the Studio command bar (View -> Command Bar) in EDIT mode, press Enter,
-- then SAVE AND PUBLISH the place. Re-running is idempotent: it destroys its own folder and clears
-- every existing FireworkLaunchSite tag before rebuilding, so it can never leave two sets behind.
--
-- WHY THIS FILE EXISTS. The markers are place-only content — Rojo owns none of it, and nothing in
-- git records where the launch sites are. Without this script the sites live in exactly one place
-- file on one machine, and rebuilding them means re-deriving four coordinates by eye.
--
-- WHY DEDICATED MARKERS RATHER THAN TAGGING EXISTING GEOMETRY. Decks and teahouses are DESTROYED
-- AND REBUILT on upgrade, display change and buy-to-claim. A tag on a deck plank disappears with
-- the plank, silently — the site simply stops existing and the picker stops appearing, with no
-- error to trace. An invisible marker in its own folder is touched by nothing.
--
-- WHAT THE SERVER DOES WITH THESE: main.server.luau's referee reads
-- CollectionService:GetTagged("FireworkLaunchSite") on every launch request and admits a player
-- within SITE_RADIUS. HudController polls the same tag at 2Hz to decide whether to offer the
-- picker at all. The radius is measured HORIZONTALLY ONLY (see LaunchSites.luau), so each marker
-- covers a vertical column and a deck above its marker still counts.
--
-- A player's own deck is a site for that player alone, added server-side. These four are the
-- PUBLIC sites — the difference matters for a new player, who owns no deck and would otherwise
-- have nowhere at all to launch from.

local CollectionService = game:GetService("CollectionService")

local TAG = "FireworkLaunchSite"
local SITE_RADIUS = 24 -- documentation only; the authority is SITE_RADIUS in main.server.luau

-- The three viewing perches the canyon was designed around. Launching is somewhere you WALK TO.
--
-- A fourth marker at the arena spawn was added and then removed on the owner's gate (2026-08-05):
-- it put a player inside a launch site the instant they loaded in, which made the HUD's firework
-- button near-permanent rather than a reward for reaching a perch. Do not re-add it without
-- deciding that question again — it is a design call about where fireworks belong, not an
-- oversight.
local SITES = {
    { name = "Site_FallsDock", pos = Vector3.new(-345, 188, -15), note = "the falls dock" },
    { name = "Site_SuspensionBridge", pos = Vector3.new(-246, 222, 0), note = "the high mid-canyon bridge" },
    { name = "Site_Overlook", pos = Vector3.new(73, 110, 19), note = "the downcanyon viewing platform" },
}

local canyonWorld = workspace:FindFirstChild("CanyonWorld")
assert(canyonWorld, "Workspace.CanyonWorld is missing — is this the right place?")

local old = canyonWorld:FindFirstChild("LaunchSites")
if old then
    old:Destroy()
end
local strays = 0
for _, inst in CollectionService:GetTagged(TAG) do
    CollectionService:RemoveTag(inst, TAG)
    strays += 1
end

local folder = Instance.new("Folder")
folder.Name = "LaunchSites"
folder.Parent = canyonWorld

for _, s in SITES do
    local p = Instance.new("Part")
    p.Name = s.name
    p.Size = Vector3.new(2, 2, 2)
    p.Position = s.pos
    p.Anchored = true
    p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
    p.CastShadow = false
    p.Transparency = 1
    p:SetAttribute("Note", s.note)
    p.Parent = folder
    CollectionService:AddTag(p, TAG)
end

print(
    ("[LaunchSites] %d markers under Workspace.CanyonWorld.LaunchSites, radius %d. Cleared %d stray tag(s). NOW SAVE AND PUBLISH — none of this is in git."):format(
        #SITES,
        SITE_RADIUS,
        strays
    )
)
