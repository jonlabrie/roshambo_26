--!strict
-- Pure list editor for a player's ordered perch preference (padPreferences).
-- Favoriting appends a siteId (deduped, capped); un-favoriting removes it. No Roblox
-- types -> Lune-tested. The server persists the result via NetworkClient:setPreferences.
local PreferenceEditor = {}

-- Returns (newList, favorited). siteId present -> removed (favorited=false).
-- siteId absent -> appended, deduped (favorited=true), unless already at maxEntries
-- (then the original list is returned unchanged, favorited=false).
function PreferenceEditor.togglePreference(
    list: { string },
    siteId: string,
    maxEntries: number
): ({ string }, boolean)
    local out: { string } = {}
    local found = false
    for _, id in list do
        if id == siteId then
            found = true
        else
            table.insert(out, id)
        end
    end
    if found then
        return out, false
    end
    if #out >= maxEntries then
        return list, false
    end
    table.insert(out, siteId)
    return out, true
end

return PreferenceEditor
