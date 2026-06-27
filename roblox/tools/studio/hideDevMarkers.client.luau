--!strict
-- Hides anything tagged "DevMarker" on the CLIENT (Play only). Install under
-- StarterPlayer.StarterPlayerScripts. Build aids (draft markers, etc.) stay visible
-- in Edit but vanish when testing in Play.
--
-- Uses LocalTransparencyModifier so the real Transparency is never changed (nothing
-- serializes), and disables any BillboardGui/SurfaceGui labels client-side.
-- GetInstanceAddedSignal covers markers added/replicated after start.

local CollectionService = game:GetService("CollectionService")
local TAG = "DevMarker"

local function hide(inst: Instance)
	if inst:IsA("BasePart") then
		inst.LocalTransparencyModifier = 1
	end
	if inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") then
		inst.Enabled = false
	end
	for _, g in inst:GetDescendants() do
		if g:IsA("BillboardGui") or g:IsA("SurfaceGui") then
			g.Enabled = false
		end
	end
end

for _, i in CollectionService:GetTagged(TAG) do
	task.spawn(hide, i)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(i)
	task.spawn(hide, i)
end)
