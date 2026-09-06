--!strict
-- The pure half of the shoji hold-to-slide machinery, lifted verbatim out of main.server.luau
-- (server-file split, phase one, task 2). No Roblox globals and no Instances, so it runs under
-- Lune and every rule below is tested without a place open. The Instance-touching half -- the
-- bay walk, the reach lookup, the loop, the persists -- lives in
-- src/server/ShojiSlideController.luau.
--
-- The run arithmetic proper (clamp/resolve/quantize/ordinalOf/directionFrom/isSlidable) is
-- ShojiRun's, not this module's; what is here is only the bookkeeping the server entry file
-- used to carry inline.
local ShojiSlideMath = {}

-- The debounce key for ONE slide: uid + pad + side + index, not just uid (2026-08-18 review fix
-- -- a shared per-uid counter let sliding screen B cancel screen A's still-pending write). \1 is
-- the separator because no component of it can contain one.
function ShojiSlideMath.slideKey(uid: string, padId: string, side: string, index: number): string
    return `{uid}\1{padId}\1{side}\1{index}`
end

-- The ordering half of collectShojiRun: the caller lists the side's `Shoji`-bearing
-- Bay_<side>_<n> models (that walk needs Instances, so it stays in the adapter) and this puts
-- them in ascending Bay number order. THE ORDER IS THE ORDINAL -- a screen's persisted
-- `shojiOpen` index is its position in this list, not its raw bay number, which is why the
-- numbers need not be contiguous and why ShojiRun.ordinalOf exists. Sorts in place and returns
-- the same list, exactly as collectShojiRun did.
function ShojiSlideMath.collectRun(
    bays: { { bayIndex: number, bay: any } }
): { { bayIndex: number, bay: any } }
    table.sort(bays, function(a, b)
        return a.bayIndex < b.bayIndex
    end)
    return bays
end

-- The reach test's arithmetic: FULL 3-D distance, inclusive at the reach -- verbatim
-- `(root.Position - pos).Magnitude <= SHOJI_REACH`. Height counts, deliberately unchanged by
-- this extraction: a bay on an upper floor is out of reach from the ground below it.
function ShojiSlideMath.withinReach(
    playerPos: { x: number, y: number, z: number },
    bayPos: { x: number, y: number, z: number },
    reach: number
): boolean
    local dx = playerPos.x - bayPos.x
    local dy = playerPos.y - bayPos.y
    local dz = playerPos.z - bayPos.z
    return math.sqrt(dx * dx + dy * dy + dz * dz) <= reach
end

return ShojiSlideMath
