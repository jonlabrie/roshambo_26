--!strict
-- WHERE A SHELL MAY BE LAUNCHED FROM. Pure and Roblox-free (positions are plain {x,y,z} tables) so
-- it runs under Lune like everything else in src/shared — the game server converts Vector3s at the
-- boundary.
--
-- Two kinds of site. A site with no `ownerUserId` is public and admits anyone; a site with one is
-- somebody's deck and admits only them. GEAR IS PERSONAL and sites do not lend tubes: standing on a
-- public site never grants a mortar you did not buy.
--
-- This is a GATE, not a hint. The client uses the same answer to decide whether to offer the
-- button, but the game server re-runs it on every request — a client that could authorise its own
-- launch is a client that can be argued with.
local LaunchSites = {}

export type Vec = { x: number, y: number, z: number }
export type Site = { pos: Vec, radius: number, ownerUserId: string? }

-- Horizontal distance only. A deck sits well above the site marker it belongs to, and a canyon
-- this vertical would otherwise reject a player standing directly on the spot.
local function withinXZ(a: Vec, b: Vec, r: number): boolean
    local dx, dz = a.x - b.x, a.z - b.z
    return dx * dx + dz * dz <= r * r
end

-- ANY admitting site wins. Sites overlap freely — a public plaza can sit inside somebody's deck —
-- so this must not stop at the first site it touches, only at the first site that ADMITS.
function LaunchSites.isValid(playerPos: Vec, sites: { Site }, userId: string): boolean
    for _, site in sites do
        if
            (site.ownerUserId == nil or site.ownerUserId == userId)
            and withinXZ(playerPos, site.pos, site.radius)
        then
            return true
        end
    end
    return false
end

return LaunchSites
