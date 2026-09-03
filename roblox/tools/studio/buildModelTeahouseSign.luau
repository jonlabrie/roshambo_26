-- buildModelTeahouseSign.luau — the "Model Teahouse" wayfinding sign (2026-09-03)
--
-- HOW TO RUN: paste into the Studio command bar in EDIT mode, press Enter, eyeball it at the
-- tunnel branch, then SAVE AND PUBLISH. Idempotent: destroys its own model before rebuilding.
--
-- Owner direction (2026-09-03, standing at the spot in Play): a sign on the wall at the
-- tunnel branch below T13, reading "Model Teahouse" with an arrow pointing right — the
-- right-hand branch is the climb from the Switchback Deck up to the model pad. The mount
-- point was captured live: wall hit (−62.5, 179.1, −85.4), surface normal ≈ (0.97, 0, 0.05)
-- (flattened to horizontal — the terrain wall leans), player at (−60.8, 176.6, −84.6).
--
-- Place-only, own folder (terrain walls are as untaggable/unrebuildable as decks — same
-- placement rules as the other place-only works). Palette: the deck family's black
-- understructure (45, 48, 56) board with INK_CREAM copy (240, 234, 216) — the HUD/lantern
-- text tone — and the arrow drawn as GUI frames, not a unicode glyph (font coverage for
-- arrows is unreliable on device).

local WALL_HIT = Vector3.new(-62.5, 179.1, -85.4)
local NORMAL = Vector3.new(0.97, 0, 0.05).Unit -- flattened: sign hangs plumb
local SIGN_SIZE = Vector3.new(5.2, 1.4, 0.2)
local BOARD = Color3.fromRGB(45, 48, 56)
local COPY = Color3.fromRGB(240, 234, 216)

local canyonWorld = workspace:FindFirstChild("CanyonWorld")
assert(canyonWorld, "Workspace.CanyonWorld is missing — is this the right place?")

local old = canyonWorld:FindFirstChild("ModelTeahouseSign")
if old then
    old:Destroy()
end

local board = Instance.new("Part")
board.Name = "ModelTeahouseSign"
board.Size = SIGN_SIZE
-- centre a half-thickness proud of the wall, at head height, front face toward the path
local pos = WALL_HIT + NORMAL * (SIGN_SIZE.Z / 2 + 0.05) + Vector3.new(0, 0.5, 0)
board.CFrame = CFrame.lookAt(pos, pos + NORMAL)
board.Anchored = true
board.CanCollide = false
board.CastShadow = false
board.Material = Enum.Material.Wood
board.Color = BOARD
board.Parent = canyonWorld

local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Front
gui.CanvasSize = Vector2.new(520, 140)
gui.LightInfluence = 0.4
gui.Brightness = 1.5
gui.Parent = board

local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(0.78, 1)
label.Position = UDim2.new(0, 0, 0, 0)
label.Font = Enum.Font.GothamBold
label.TextColor3 = COPY
label.TextScaled = true
label.Text = "Model Teahouse"
label.Parent = gui

-- the arrow: shaft + two chevron strokes, viewer's right
local shaft = Instance.new("Frame")
shaft.BackgroundColor3 = COPY
shaft.BorderSizePixel = 0
shaft.Size = UDim2.fromOffset(70, 12)
shaft.AnchorPoint = Vector2.new(0, 0.5)
shaft.Position = UDim2.fromScale(0.8, 0.5)
shaft.Parent = gui
for _, rot in { -40, 40 } do
    local stroke = Instance.new("Frame")
    stroke.BackgroundColor3 = COPY
    stroke.BorderSizePixel = 0
    stroke.Size = UDim2.fromOffset(34, 12)
    stroke.AnchorPoint = Vector2.new(1, 0.5)
    stroke.Position = UDim2.new(0.8, 78, 0.5, rot < 0 and -9 or 9)
    stroke.Rotation = rot
    stroke.Parent = gui
end

print("[ModelTeahouseSign] placed at the tunnel branch. Eyeball it, then SAVE AND PUBLISH.")
