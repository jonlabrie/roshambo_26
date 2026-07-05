--!strict
-- Maps a pad's occupancy + class to the visual treatment for the pad. Pure (Lune-tested).
-- Vacant cliff pads show a dark base-form teahouse (scheme.dormant) with unlit shoji;
-- vacant valley pads show a pocket-garden mask (marker only here — applier deferred);
-- a claimed pad shows the owner's loadout, lit. `occupant` comes from PadRegistry:get(id),
-- `vacantForm` from the PadSpec; both are parameters so this stays decoupled from the registry.
local VacantState = {}

export type Treatment =
	{ kind: "structure", loadout: any, lit: boolean }
	| { kind: "garden" }

local VACANT_BASE = "teahouse-1story"

local function dormant(): { baseStyle: string, colorScheme: string }
	return { baseStyle = VACANT_BASE, colorScheme = "scheme.dormant" }
end

function VacantState.resolve(occupant: string?, ownerLoadout: any?, vacantForm: string?): Treatment
	if occupant ~= nil then
		-- claimed: the owner's structure, lit (dormant fallback if a loadout is missing)
		return { kind = "structure", loadout = ownerLoadout or dormant(), lit = true }
	end
	if vacantForm == "pocket-garden" then
		-- valley: a garden mask (applier deferred to a later increment)
		return { kind = "garden" }
	end
	-- cliff (dormant-structure, or omitted): dark base form, shoji unlit
	return { kind = "structure", loadout = dormant(), lit = false }
end

return VacantState
