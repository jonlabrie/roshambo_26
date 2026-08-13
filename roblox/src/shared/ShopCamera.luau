--!strict
-- LET THE SHOPPER OUT. The shop panel is a ScreenGui, and a player who walks in while zoomed all
-- the way in has their mouse LOCKED TO SCREEN CENTRE — which is exactly where the panel sits. The
-- close button cannot be pressed, and the scroll that would normally zoom back out lands on the
-- panel under the pinned cursor instead of the camera. Walking out is the only escape, and a
-- player who does not know that is simply stuck.
--
-- The fix is not to fight the mouse. Roblox's own camera module re-asserts MouseBehavior every
-- frame in first person, so anything written there is overwritten before it can be clicked. What
-- IS respected is `Player.CameraMinZoomDistance`: raise the floor and the camera walks itself out
-- to third person, where the cursor is free by default. One supported property, no per-frame war.
--
-- Pure and Roblox-free so it runs under Lune — the controller reads and writes the Player
-- properties at the boundary. The arithmetic lives here because the clamp below is the kind of
-- thing that looks obviously right and throws in production.
local ShopCamera = {}

-- Far enough out that the camera is unambiguously third person and the cursor unlocks; close
-- enough that it stays under a default zoom, so it reads as a FLOOR and not as a shove. See the
-- tests: both bounds are asserted, because a drift in either direction is invisible in Studio
-- until someone walks in at the wrong zoom.
ShopCamera.FREE_ZOOM = 8

-- The CameraMinZoomDistance to write while the panel is open, or nil for "leave it alone".
--
-- nil is not an error case. It means the write would change nothing — either the player is
-- already held out past the grip, or the place pins the camera so tightly that there is no room
-- to move. Returning a no-op value instead would still oblige the caller to save and restore it,
-- and the restore is exactly where saved state gets lost.
function ShopCamera.gripMinZoom(currentMin: number, currentMax: number): number?
    -- A minimum above the maximum ERRORS. An erroring open is worse than a pinned cursor: the
    -- panel never paints and the shop looks dead rather than awkward.
    local want = math.min(ShopCamera.FREE_ZOOM, currentMax)
    if want <= currentMin then
        return nil
    end
    return want
end

return ShopCamera
