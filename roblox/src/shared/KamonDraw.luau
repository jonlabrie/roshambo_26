--!strict
-- Draws a Kamon crest into a SurfaceGui, from the three primitives the catalog is built on.
--
-- ⚠ THIS IS A SEPARATE MODULE BECAUSE `Kamon` MUST STAY PURE. Kamon is Lune-tested, and Lune has
-- no `Color3` — putting the ink colour or this renderer in Kamon breaks the whole test run at
-- require time, which is exactly what happened on the first attempt (2026-08-22). Same rule
-- DoomEscalation and BirdFlight follow: a pure module names no Roblox type, and anything that
-- does lives beside it rather than inside it.
--
-- It was local to TreatmentApplier until the sashimono became a second surface — which the note
-- there had predicted. Two copies of a catalog renderer is how a catalog drifts from itself.
local KamonDraw = {}

-- One ink and one cloth, so a crest on a banner, a noren and a sashimono read as the same house
-- mark rather than three unrelated marks.
KamonDraw.INK = Color3.fromRGB(28, 26, 24)
KamonDraw.CLOTH = Color3.fromRGB(228, 220, 202)

function KamonDraw.draw(gui: Instance, crest: any, cellPx: number)
    for _, sh in crest.shapes or {} do
        local f = Instance.new("Frame")
        f.BorderSizePixel = 0
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.fromOffset(cellPx / 2 + (sh.x or 0) * cellPx, cellPx / 2 + (sh.y or 0) * cellPx)
        if sh.kind == "bar" then
            f.Size = UDim2.fromOffset(math.max(1, sh.w * cellPx), math.max(1, sh.h * cellPx))
            f.BackgroundColor3 = KamonDraw.INK
            f.Rotation = sh.rot or 0
        else
            local d = math.max(2, sh.r * 2 * cellPx)
            f.Size = UDim2.fromOffset(d, d)
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0.5, 0)
            corner.Parent = f
            if sh.kind == "disc" then
                f.BackgroundColor3 = KamonDraw.INK
            else
                f.BackgroundTransparency = 1
                local stroke = Instance.new("UIStroke")
                stroke.Thickness = math.max(1, sh.t * cellPx)
                stroke.Color = KamonDraw.INK
                stroke.Parent = f
            end
        end
        f.Parent = gui
    end
end

return KamonDraw
