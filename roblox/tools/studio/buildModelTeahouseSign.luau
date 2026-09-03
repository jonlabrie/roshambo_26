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
-- text tone. Face + arrow are the signage identity (docs/wiki/world/visual-identity.md
-- § Signage & wayfinding): Josefin Sans SemiBold, caret glyph rotated as the arrow.

local WALL_HIT = Vector3.new(-62.5, 179.1, -85.4)
local NORMAL = Vector3.new(0.97, 0, 0.05).Unit -- flattened: sign hangs plumb
-- 1.4 -> 1.8 tall (owner gate 2026-09-03: "make wood a little higher, the text is
-- currently right up at the top of the board") -- the board grows UPWARD (bottom edge
-- kept, centre +0.2), and the label below is padded to 62% height so Josefin Sans's
-- high-riding metrics sit centred instead of kissing the top edge.
local SIGN_SIZE = Vector3.new(5.2, 1.8, 0.2)
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
-- was +0.5, then -0.5 ("drop a stud"); -0.3 keeps that bottom edge as the board grew taller
local pos = WALL_HIT + NORMAL * (SIGN_SIZE.Z / 2 + 0.05) + Vector3.new(0, -0.3, 0)
board.CFrame = CFrame.lookAt(pos, pos + NORMAL)
board.Anchored = true
board.CanCollide = false
board.CastShadow = false
board.Material = Enum.Material.Wood
board.Color = BOARD
board.Parent = canyonWorld

local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Front
gui.CanvasSize = Vector2.new(520, 180)
gui.LightInfluence = 0.4
gui.Brightness = 1.5
gui.Parent = board

local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(0.78, 0.62)
label.AnchorPoint = Vector2.new(0, 0.5)
label.Position = UDim2.fromScale(0, 0.5)
-- Josefin Sans (owner direction 2026-09-03: "a sans that's a little less modern...
-- part of the 'resort-ish' identity"): gated same day ("font is good"), recorded as
-- the signage face in docs/wiki/world/visual-identity.md.
label.FontFace = Font.new("rbxasset://fonts/families/JosefinSans.json", Enum.FontWeight.SemiBold)
label.TextColor3 = COPY
label.TextScaled = true
label.Text = "Model Teahouse"
label.Parent = gui

-- The arrow IS the identity (owner, 2026-09-03, replacing two hand-drawn chevron strokes
-- the gate called ugly): the scissors caret from shared/Glyphs, rotated 90° clockwise so
-- ∧ points right. (The owner said "paper glyph", but paper is the horizontal BAR — rotated
-- it stands vertical; the mark that becomes a right arrow is the caret.) Rendered from the
-- real glyph assets — identity stroke weight, round caps — tinted monochrome cream on the
-- dark board. Requires RoshamboShared synced (rojo serve connected), like
-- verifyWorkspaceConvention.
local Glyphs = require(game:GetService("ReplicatedStorage").RoshamboShared.Glyphs)
local arrowBox = Instance.new("Frame")
arrowBox.Name = "Arrow"
arrowBox.BackgroundTransparency = 1
arrowBox.Size = UDim2.fromOffset(84, 84)
arrowBox.AnchorPoint = Vector2.new(0.5, 0.5)
arrowBox.Position = UDim2.fromOffset(455, 90) -- canvas is 520 x 180
arrowBox.Rotation = 90 -- clockwise: caret's apex swings to the right
arrowBox.Parent = gui
Glyphs.render(arrowBox, "S", COPY, COPY)

print("[ModelTeahouseSign] placed at the tunnel branch. Eyeball it, then SAVE AND PUBLISH.")
