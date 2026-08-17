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
    -- Draw a divider bar on this unit's far side (towards the NEXT column, which is at lower
    -- local X). The controller sets it where two flap columns meet and nothing else separates
    -- them -- the two seconds digits had no divider at all and ran together (owner, 2026-08-17).
    dividerAfter: boolean?,
    -- The character's height as a share of the cell. See halfCanvasFor.
    charFraction: number?,
}

local PANEL_T = 0.06 -- static half-panel thickness
local LEAF_T = 0.05 -- the moving card; thinner, so it clears the panels it sweeps over
-- CLEARANCE BETWEEN THE STATIC FACES AND THE CARDS THAT SWEEP OVER THEM, and the hinge rod has
-- to fit inside it. At 0.012 the rod's back edge came within 0.0012 studs of the panel face, so
-- it z-fought with the glyph painted there and flickered as the camera moved (owner, 2026-08-17).
-- 0.03 leaves the rod ~0.011 clear on both sides, which is a real gap rather than a rounding
-- error. Nothing else depends on this number; it is pure standoff.
local GAP = 0.03
-- THE HINGE HAS TO BE A THING YOU CAN SEE. The static halves used to simply touch at y=0 with
-- nothing between them, so there was no seam at all -- "the hinge is nearly invisible on the
-- round display and completely invisible on the clock" (owner, 2026-08-17). A real board shows a
-- dark line there: the gap between the two faces and the rod they hang from. So the halves are
-- inset to open a gap, and a dark bar sits in it, standing slightly proud so it catches light as
-- a rod rather than reading as a painted stripe.
local SEAM_FRACTION = 0.0175 -- of cell height; halved at the owner's look -- the first rod was heavy
local SEAM_COLOR = Color3.fromRGB(52, 46, 38)
local BOARD_T = 0.4 -- StatsRoomLayout.THICKNESS; the board's own depth
local FACE = Color3.fromRGB(244, 238, 222)
local CARD = Color3.fromRGB(232, 225, 208) -- the moving card, a shade under the static faces
local DEFAULT_HALF = 0.055

-- THE CHARACTER'S SHARE OF THE CELL, and the canvas size falls out of it. TextSize is hard-capped
-- at 100px, so a bigger character cannot be had by asking for more pixels -- only by making the
-- CANVAS smaller, the same small-canvas-stretched-large trick the wall boards use.
--
--   halfCanvas = GLYPH_PX / (2 * fraction)      -- a full character spans two half-panels
--
-- ⚠ THIS IS TEXTSIZE'S SHARE, NOT THE INK'S. A digit's drawn height is only about 0.72 of its
-- TextSize -- the rest of the em is leading and space for ascenders and descenders that a numeral
-- does not use. So `fraction` 0.9 draws a digit at roughly 0.65 of the cell, which is why the
-- clock still read small after being asked for 50% more and getting it. Multiply by ~0.72 to
-- predict what the eye will see, or set this above 1.0 without alarm: a numeral has no descender
-- to clip.
local GLYPH_PX = 96
local DEFAULT_CHAR_FRACTION = 0.6

function FlapUnit.halfCanvasFor(fraction: number?): number
    return math.floor(GLYPH_PX / (2 * (fraction or DEFAULT_CHAR_FRACTION)))
end

-- A PARKED LEAF MUST BE HIDDEN, NOT MERELY EDGE-ON. These are real parts a twentieth of a stud
-- thick and over a stud tall; rotated to 90 degrees they stand straight out of the wall like a
-- fin, plainly visible from anywhere but dead ahead -- and with a face painted on each, showing
-- last round's top half and this round's bottom. "Edge-on is invisible" is true of a
-- zero-thickness plane viewed exactly on axis and of nothing else. The owner saw the fins
-- (2026-08-17). Transparency alone is not enough either: a SurfaceGui on an invisible part still
-- renders, so the face is disabled with it.
local function setShown(part: BasePart, shown: boolean)
    part.Transparency = if shown then 0 else 1
    for _, child in part:GetChildren() do
        if child:IsA("SurfaceGui") then
            child.Enabled = shown
        end
    end
end

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
    local halfCanvas = FlapUnit.halfCanvasFor(cfg.charFraction)
    local canvasW = math.floor(halfCanvas * (cfg.width / halfH))
    -- Depths measured forward from the board's front face (local -Z), each clearing the last.
    local panelZ = -(BOARD_T / 2 + PANEL_T / 2 + GAP)
    local leafZ = panelZ - (PANEL_T / 2 + LEAF_T / 2 + GAP)

    -- THE HALVES STAY FULL HEIGHT and the rod lies OVER their join. Insetting them to open a gap
    -- was the obvious move and it silently breaks the painters: they size a full character from
    -- the panel's height, so shortening the panel shrinks the character and pushes its centre off
    -- the hinge. The rod covers the join instead, which is what a hinge does anyway.
    local seam = math.max(0.02, cfg.height * SEAM_FRACTION)
    local upper = makePart("Upper", cfg.board, Vector3.new(cfg.width, halfH, PANEL_T), FACE)
    local lower = makePart("Lower", cfg.board, Vector3.new(cfg.width, halfH, PANEL_T), FACE)
    -- The rod lives in the 0.012 studs between the panel faces and the cards that sweep over
    -- them, so its DEPTH is set by that clearance, not chosen. Thin in Z costs nothing: what
    -- makes a hinge read from across the room is its height and its darkness, not its thickness.
    local rodT = GAP * 0.35
    local hinge = makePart("Hinge", cfg.board, Vector3.new(cfg.width, seam, rodT), SEAM_COLOR)
    -- The vertical divider is the hinge rod's twin: same colour, same depth, same clearance, so
    -- the two read as one piece of ironmongery framing the cell rather than two decisions.
    local divider = if cfg.dividerAfter
        then makePart("Divider", cfg.board, Vector3.new(seam, cfg.height, rodT), SEAM_COLOR)
        else nil
    local leafTop = makePart("LeafTop", cfg.board, Vector3.new(cfg.width, halfH, LEAF_T), CARD)
    local leafBottom = makePart("LeafBottom", cfg.board, Vector3.new(cfg.width, halfH, LEAF_T), CARD)

    local self = setmetatable({
        _cfg = cfg,
        _parts = { upper, lower, leafTop, leafBottom, hinge },
        _divider = divider,
        _dividerCF = CFrame.new(cfg.localX - cfg.width / 2, 0, panelZ - PANEL_T / 2 - GAP / 2),
        -- The hinge: the cell's centre line, standing off the board face. Both leaves pivot here.
        _pivot = CFrame.new(cfg.localX, 0, leafZ),
        _halfH = halfH,
        _half = cfg.halfSeconds or DEFAULT_HALF,
        _value = nil :: string?,
        _token = 0,
        _dead = false,
        -- Static halves sit at +/- a quarter cell either side of the hinge, touching.
        _upperCF = CFrame.new(cfg.localX, halfH / 2, panelZ),
        _lowerCF = CFrame.new(cfg.localX, -halfH / 2, panelZ),
        -- On the hinge line, in front of the panel faces and behind the leaves: dead centre of
        -- the clearance between them. Proud enough to catch light as a rod rather than read as a
        -- painted stripe, and never intersecting a card mid-turn.
        _hingeCF = CFrame.new(cfg.localX, 0, panelZ - PANEL_T / 2 - GAP / 2),
        setUpper = cfg.paint(upper, canvasW, halfCanvas, 1),
        setLower = cfg.paint(lower, canvasW, halfCanvas, 0),
        setLeafTop = cfg.paint(leafTop, canvasW, halfCanvas, 1),
        setLeafBottom = cfg.paint(leafBottom, canvasW, halfCanvas, 0),
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
    self._parts[5].CFrame = base * self._hingeCF
    if self._divider then
        self._divider.CFrame = base * self._dividerCF
    end
    -- At rest the static halves carry the character and BOTH leaves are hidden outright.
    self:_poseTop(-math.pi / 2)
    self:_poseBottom(math.pi / 2)
    setShown(self._parts[3], false)
    setShown(self._parts[4], false)
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

    -- Only the card actually in flight is shown. The other is hidden, or it stands out of the
    -- wall as a fin for the whole turn.
    self:_poseTop(0)
    setShown(self._parts[3], true)
    setShown(self._parts[4], false)

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
        -- Hand over: the falling card goes away entirely and the landing card appears in the
        -- same place, so the swap happens where neither is showing any face to the room.
        setShown(self._parts[3], false)
        self:_poseTop(-math.pi / 2)
        self:_poseBottom(math.pi / 2)
        setShown(self._parts[4], true)
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
            -- The static half owns the character now, so the card leaves the scene completely.
            self.setLower(value)
            setShown(self._parts[4], false)
            self:_poseBottom(math.pi / 2)
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
    if self._divider then
        self._divider:Destroy()
    end
    table.clear(self._parts)
end

FlapUnit.GLYPH_PX = GLYPH_PX
FlapUnit.DEFAULT_CHAR_FRACTION = DEFAULT_CHAR_FRACTION

return FlapUnit
