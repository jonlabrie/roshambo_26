--!strict
-- ONE PHYSICAL SPLIT-FLAP, built from real parts and hinged in 3D.
--
-- WHY PARTS AND NOT A GUI. Roblox GUI cannot foreshorten: `Rotation` on a GuiObject is 2D about
-- Z, there is no non-uniform text scaling, and there are no back faces. Four attempts at faking
-- a fold in GUI produced a wipe, then a uniform shrink -- the owner's word was "unreadable", and
-- it was a fair one. A part rotating about a hinge foreshortens because it genuinely is rotating.
--
-- IT COSTS PARTS, SO IT IS FOR THE FEW. Four parts per flap: the round display's three digits and
-- one glyph come to sixteen, which is nothing. The wall boards' 1,050 cells would not, and keep
-- the GUI approximation.
--
-- ===== TWO LEAVES, NOT ONE, AND THAT IS THE WHOLE DESIGN =====
-- A real card carries the outgoing top half on its front and the incoming bottom half on its
-- back. Modelling that with ONE part means showing its BACK face at the end of the fall -- and a
-- part rotated 180 degrees has its local +Y pointing down, so back-face content renders upside
-- down and needs compensating rotation that is fiddly to get right and impossible to check
-- without eyes on it.
--
-- So the card is split in two, and each leaf uses only its FRONT face:
--   * LeafTop    falls from upright to edge-on:  0 -> -90 degrees, carrying the OUTGOING top half.
--   * LeafBottom continues edge-on to flat:    +90 ->   0 degrees, carrying the INCOMING bottom.
-- Both are edge-on -- and so invisible -- at the same instant and in the same place, which is
-- what makes the handover impossible to see.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local FlapUnit = {}
FlapUnit.__index = FlapUnit

-- Paints one face and hands back a setter. Injected because a digit flap paints text and a throw
-- flap paints the shared Glyphs images, and this module should know about neither.
--   `anchorY` 1 = content centred on the panel's BOTTOM edge (shows a character's TOP half)
--   `anchorY` 0 = content centred on the panel's TOP edge    (shows its BOTTOM half)
export type Painter = (part: BasePart, canvasW: number, canvasH: number, anchorY: number) -> (string?) -> ()

export type Config = {
    board: BasePart,
    localX: number, -- column centre, in the board's own X
    width: number, -- cell width in studs
    height: number, -- cell height in studs
    paint: Painter,
    halfSeconds: number?,
}

local PANEL_T = 0.06 -- static half-panel thickness
local LEAF_T = 0.05 -- the moving card; thinner, so it clears the panels it sweeps over
local GAP = 0.012
local BOARD_T = 0.4 -- StatsRoomLayout.THICKNESS; the board's own depth
local FACE = Color3.fromRGB(244, 238, 222)
local CARD = Color3.fromRGB(232, 225, 208) -- the moving card, a shade under the static faces
local DEFAULT_HALF = 0.055

-- 80 canvas px per HALF panel, so a full character is 160 and a 96px glyph is 0.6 of it -- just
-- under the engine's hard 100px TextSize cap, which is the constraint that sets this number.
local HALF_CANVAS = 80
local GLYPH_PX = 96

local function makePart(name: string, parent: Instance, size: Vector3, color: Color3): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Color = color
    p.Material = Enum.Material.SmoothPlastic
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

function FlapUnit.new(cfg: Config)
    local halfH = cfg.height / 2
    local canvasW = math.floor(HALF_CANVAS * (cfg.width / halfH))
    -- Depths measured forward from the board's front face (local -Z), each clearing the last.
    local panelZ = -(BOARD_T / 2 + PANEL_T / 2 + GAP)
    local leafZ = panelZ - (PANEL_T / 2 + LEAF_T / 2 + GAP)

    local upper = makePart("Upper", cfg.board, Vector3.new(cfg.width, halfH, PANEL_T), FACE)
    local lower = makePart("Lower", cfg.board, Vector3.new(cfg.width, halfH, PANEL_T), FACE)
    local leafTop = makePart("LeafTop", cfg.board, Vector3.new(cfg.width, halfH, LEAF_T), CARD)
    local leafBottom = makePart("LeafBottom", cfg.board, Vector3.new(cfg.width, halfH, LEAF_T), CARD)

    local self = setmetatable({
        _cfg = cfg,
        _parts = { upper, lower, leafTop, leafBottom },
        -- The hinge: the cell's centre line, standing off the board face. Both leaves pivot here.
        _pivot = CFrame.new(cfg.localX, 0, leafZ),
        _halfH = halfH,
        _half = cfg.halfSeconds or DEFAULT_HALF,
        _value = nil :: string?,
        _token = 0,
        _dead = false,
        -- Static halves sit at +/- a quarter cell either side of the hinge.
        _upperCF = CFrame.new(cfg.localX, halfH / 2, panelZ),
        _lowerCF = CFrame.new(cfg.localX, -halfH / 2, panelZ),
        setUpper = cfg.paint(upper, canvasW, HALF_CANVAS, 1),
        setLower = cfg.paint(lower, canvasW, HALF_CANVAS, 0),
        setLeafTop = cfg.paint(leafTop, canvasW, HALF_CANVAS, 1),
        setLeafBottom = cfg.paint(leafBottom, canvasW, HALF_CANVAS, 0),
    }, FlapUnit)

    self:_place()
    -- The board is place-only geometry an owner may nudge; re-seat on any move rather than
    -- baking a world CFrame once and drifting away from the frame the flaps belong to.
    self._moved = cfg.board:GetPropertyChangedSignal("CFrame"):Connect(function()
        if not self._dead then
            self:_place()
        end
    end)
    return self
end

function FlapUnit._place(self: any)
    local base = self._cfg.board.CFrame
    self._parts[1].CFrame = base * self._upperCF
    self._parts[2].CFrame = base * self._lowerCF
    -- At rest both leaves are edge-on and invisible; the static halves carry the character.
    self:_poseTop(-math.pi / 2)
    self:_poseBottom(math.pi / 2)
end

-- LeafTop hinges at the seam and swings its centre from a quarter-cell ABOVE it to edge-on.
function FlapUnit._poseTop(self: any, angle: number)
    self._parts[3].CFrame = self._cfg.board.CFrame
        * self._pivot
        * CFrame.Angles(angle, 0, 0)
        * CFrame.new(0, self._halfH / 2, 0)
end

-- LeafBottom hinges at the same seam and swings from edge-on down to a quarter-cell BELOW it.
function FlapUnit._poseBottom(self: any, angle: number)
    self._parts[4].CFrame = self._cfg.board.CFrame
        * self._pivot
        * CFrame.Angles(angle, 0, 0)
        * CFrame.new(0, -self._halfH / 2, 0)
end

local function tweenAngle(
    from: number,
    to: number,
    seconds: number,
    style: Enum.EasingStyle,
    dir: Enum.EasingDirection,
    apply: (number) -> ()
)
    local v = Instance.new("NumberValue")
    v.Value = from
    -- A NumberValue rather than tweening CFrame directly: a CFrame tween interpolates along the
    -- CHORD between two poses, so a card hinged off its own centre would visibly cut through the
    -- panel it is sweeping over. Tweening the ANGLE and rebuilding the CFrame keeps it on its arc.
    local conn = v.Changed:Connect(apply)
    local t = TweenService:Create(v, TweenInfo.new(seconds, style, dir), { Value = to })
    t:Play()
    return t, function()
        conn:Disconnect()
        v:Destroy()
    end
end

function FlapUnit.set(self: any, value: string?)
    if self._dead or self._value == value then
        return
    end
    local outgoing = self._value
    self._value = value
    self._token += 1
    local token = self._token

    -- FALLING. The upper half commits to the incoming character at once, so it is revealed from
    -- under a descending card. The lower half holds the OUTGOING one for the whole fall -- that is
    -- what the card lands on, and leaving it to the end of the turn is what left it blank when a
    -- fast reel interrupted every flip.
    self.setUpper(value)
    self.setLower(outgoing)
    self.setLeafTop(outgoing)
    self.setLeafBottom(value)

    local fall, cleanFall = tweenAngle(
        0,
        -math.pi / 2,
        self._half,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.In,
        function(a)
            self:_poseTop(a)
        end
    )
    fall.Completed:Once(function()
        cleanFall()
        if self._dead or self._token ~= token then
            return
        end
        self:_poseTop(-math.pi / 2) -- park it edge-on; LeafBottom takes over from the same place
        -- LANDING. Linear, not eased: the card is already at speed when it passes edge-on, and a
        -- decelerating second half reads as the flap being lowered rather than falling.
        local land, cleanLand = tweenAngle(
            math.pi / 2,
            0,
            self._half,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.InOut,
            function(a)
                self:_poseBottom(a)
            end
        )
        land.Completed:Once(function()
            cleanLand()
            if self._dead or self._token ~= token then
                return
            end
            self.setLower(value)
            self:_poseBottom(math.pi / 2) -- back to edge-on; the static half has the character now
        end)
    end)
end

function FlapUnit.destroy(self: any)
    self._dead = true
    if self._moved then
        self._moved:Disconnect()
    end
    for _, p in self._parts do
        p:Destroy()
    end
    table.clear(self._parts)
end

FlapUnit.HALF_CANVAS = HALF_CANVAS
FlapUnit.GLYPH_PX = GLYPH_PX
FlapUnit.RunService = RunService

return FlapUnit
