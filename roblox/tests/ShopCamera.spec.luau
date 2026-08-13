--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ShopCamera = require("../src/shared/ShopCamera")

describe("ShopCamera", function()
    test("the grip clears first person", function()
        -- Roblox's first person IS zoom distance 0.5. Anything at or below it locks the mouse to
        -- screen centre, and a locked cursor cannot press a button.
        expect(ShopCamera.FREE_ZOOM > 0.5).toBe(true)
    end)

    test("a first-person shopper is pushed out to arm's length", function()
        expect(ShopCamera.gripMinZoom(0.5, 400)).toBe(ShopCamera.FREE_ZOOM)
    end)

    test("THE GRIP NEVER EXCEEDS THE PLACE'S MAX ZOOM", function()
        -- CameraMinZoomDistance above CameraMaxZoomDistance is an error, and an erroring open is
        -- worse than a locked cursor: the panel would not paint at all.
        expect(ShopCamera.gripMinZoom(0.5, 4)).toBe(4)
    end)

    test("a place that pins the camera to first person is left alone", function()
        -- Nothing can be freed here, so write nothing. Returning 0.5 would be a no-op write that
        -- still has to be restored, and the restore is where state gets lost.
        expect(ShopCamera.gripMinZoom(0.5, 0.5)).toBe(nil)
    end)

    test("a player already held out past the grip is left alone", function()
        expect(ShopCamera.gripMinZoom(20, 400)).toBe(nil)
    end)

    test("the grip is a nudge, not a shove", function()
        -- It sets a FLOOR, so a player at the default 12.5 keeps their own distance; only someone
        -- below the floor moves. If FREE_ZOOM crept up past the default zoom, every shopper would
        -- be yanked backwards on walking in.
        expect(ShopCamera.FREE_ZOOM < 12.5).toBe(true)
    end)
end)
