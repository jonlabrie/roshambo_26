--!strict
-- 花火屋 — the firework shop, and the merchant row's first machiya.
--
-- A MACHIYA IS NOT A TEAHOUSE. Every enclosed structure in this canyon so far is a dwelling; a
-- shop has to read differently at a glance. What does that here: an OPEN frontage (no wall on
-- the street side, just posts and a raised timber floor), a deep eave over it, and a closed
-- upper storey of kōshi lattice carrying the sign high enough to read from the bridge.
--
-- EVERY DIMENSION BELOW IS THE OWNER'S. A holdout block was placed in Studio at the proposed
-- footprint and they moved and resized it; these are its measured extents, read back
-- 2026-08-05. The study block survives at Workspace.Sandbox.HanabiyaStudy. Do not re-derive
-- them from anything — see docs/superpowers/specs/2026-08-05-hanabiya-shop-design.md §1.
local Spec = require("./Spec")
local L = require("./ArenaLayout")
local Chochin = require("./Chochin")

local Machiya = {}

-- ===== per-character lettering (owner's signage pass, 2026-08-15) =====
-- ONE TextLabel PER CHARACTER, each centred in its own equal cell along the
-- reading axis. Two reasons this beats the single label it replaces:
--   * spacing — NO Roblox font carries CJK glyphs: all 53 Enum.Font values
--     return identical metrics for 花火屋 (99x48 px at size 48, measured), i.e.
--     they all fall through to one system fallback whose run is PACKED. The
--     cells are the only spacing control that exists for kanji.
--   * orientation — a vertical (tategaki) sign is the same cells stacked
--     top-to-bottom; a single label cannot render one at all.
-- The SurfaceGui carries 花火屋's proven canvas configuration: SizingMode =
-- PixelsPerStud (the default FixedSize IGNORES PixelsPerStud and renders the
-- glyphs as specks), a SMALL canvas with a fixed TextSize — TextScaled is
-- unreliable and TextSize caps near 100px, so big lettering always needs a
-- small canvas, never a big canvas with big text.
-- SHARED by 花火屋's inline sign and every identity-kit sign kind, so the
-- letterforms can never drift apart between the full-interior path and the kit.
-- The one label recipe every sign shares — kanjiFace's cells and the mon's
-- ringed character are the same TextLabel, so the letterforms cannot fork.
local function kanjiLabel(
    name: string,
    ch: string,
    position: any,
    size: any,
    inkColour: { number },
    textSize: number
): any
    return {
        name = name,
        className = "TextLabel",
        properties = {
            Position = position,
            Size = size,
            BackgroundTransparency = 1,
            Text = ch,
            TextColor3 = inkColour,
            TextSize = textSize,
            -- moot for kanji (the system fallback ignores it) but pins any
            -- Latin/kana a future sign mixes in to the sign face we tested
            Font = "GothamBold",
        },
    }
end

-- Shironuki — resist-dyed white, the colour of lettering and crests on dyed
-- shop cloth (the nobori's characters, every noren's mon).
local SHIRO = { 0.92, 0.9, 0.85 }

local function kanjiFace(
    name: string,
    text: string,
    face: string,
    inkColour: { number },
    textSize: number,
    pixelsPerStud: number,
    vertical: boolean
): any
    local chars: { string } = {}
    for _, code in utf8.codes(text) do
        table.insert(chars, utf8.char(code))
    end
    local n = #chars
    local labels: { any } = {}
    for i, ch in chars do
        local position, size
        if vertical then
            position = { UDim2 = { { 0, 0 }, { (i - 1) / n, 0 } } }
            size = { UDim2 = { { 1, 0 }, { 1 / n, 0 } } }
        else
            position = { UDim2 = { { (i - 1) / n, 0 }, { 0, 0 } } }
            size = { UDim2 = { { 1 / n, 0 }, { 1, 0 } } }
        end
        table.insert(labels, kanjiLabel(`Char{i}`, ch, position, size, inkColour, textSize))
    end
    return {
        name = name,
        className = "SurfaceGui",
        properties = {
            Face = face,
            SizingMode = "PixelsPerStud",
            PixelsPerStud = pixelsPerStud,
            AlwaysOnTop = false,
            ZIndexBehavior = "Sibling",
        },
        children = labels,
    }
end

-- ===== 丸に文字 — the shop mon (owner's ruling, 2026-08-15 round 3) =====
-- A ring enclosing one kanji, arguably the era's PRIMARY shop identifier,
-- resist-dyed white on the noren. It is built as the host segment's own
-- SurfaceGui — a circular Frame (UICorner) with a stroked rim (UIStroke) and
-- one kanjiLabel — and NOT as a part pinned in world space, for a mechanical
-- reason: NorenSway CFrames the tagged segments every frame, and in Roblox a
-- part does not inherit its parent's CFrame, while a committed .model.json
-- cannot express the WeldConstraint refs that would bind one. A SurfaceGui
-- renders in its part's own frame, so the animated segment's transform IS the
-- mon's transform — it rides the cloth by construction. No image uploads: the
-- ring is a corner-rounded frame, the character is the shared label recipe.
local function monFace(char: string, panelW: number, segH: number): any
    local PPS = 128 -- a small crest wants a dense canvas to stay crisp
    -- read from the promenade without covering the panel: within 60% of the
    -- panel's width, and inside the host segment's own face
    local dia = math.min(0.6 * panelW, 0.9 * segH)
    -- WHOLE pixels: a UDim2 offset is Int32 in rbx-dom, and rojo REFUSES a float
    -- there (found the hard way: `[0, 89.9175]` fails the whole model's parse).
    -- FLOOR, not round: rounding up can push the ring past the sizing cap above.
    local diaPx = math.floor(dia * PPS)
    return {
        name = "Mon",
        className = "SurfaceGui",
        properties = {
            Face = "Front", -- onto the street, like the cloth it rides
            SizingMode = "PixelsPerStud",
            PixelsPerStud = PPS,
            AlwaysOnTop = false,
            ZIndexBehavior = "Sibling",
        },
        children = {
            {
                name = "Ring",
                className = "Frame",
                properties = {
                    AnchorPoint = { Vector2 = { 0.5, 0.5 } },
                    Position = { UDim2 = { { 0.5, 0 }, { 0.5, 0 } } },
                    Size = { UDim2 = { { 0, diaPx }, { 0, diaPx } } },
                    BackgroundTransparency = 1,
                },
                children = {
                    -- full corner radius turns the frame into a circle; the
                    -- stroke follows it, so the rim IS the ring
                    {
                        name = "Circle",
                        className = "UICorner",
                        properties = { CornerRadius = { UDim = { 0.5, 0 } } },
                    },
                    {
                        name = "Rim",
                        className = "UIStroke",
                        properties = {
                            Thickness = math.max(3, diaPx * 0.09),
                            Color = SHIRO,
                        },
                    },
                    kanjiLabel(
                        "Char1",
                        char,
                        { UDim2 = { { 0, 0 }, { 0, 0 } } },
                        { UDim2 = { { 1, 0 }, { 1, 0 } } },
                        SHIRO,
                        math.floor(diaPx * 0.6)
                    ),
                },
            },
        },
    }
end

function Machiya.build(palette: any, _layout: any, shop: any): any
    -- A KOSHI FRONTAGE CANNOT CARRY THE FULL INTERIOR. The counter and the noren register to
    -- the OPEN bays (postX), and a kōshi frontage has none — without this gate the combination
    -- dies later as bare nil arithmetic at the counter's postX lookup, which names nothing.
    -- No shop uses the combination; if one ever should, the counter needs a new registration.
    assert(
        not (shop.frontage == "koshi" and shop.interior == "full"),
        "a koshi frontage cannot carry the full interior: the counter and stair register to the open bays"
    )

    -- ===== the owner's envelope =====
    local X0, X1 = shop.envelope.x0, shop.envelope.x1 -- west, east
    -- DEEPENED 2026-08-13, front edge only: z44 -> z36. The shop held about three people, because a
    -- counter 4.6 studs in left barely three studs of floor to stand on. The back is fixed — it is the
    -- terrain cut — so the depth had to come off the front, and it does so at the owner's direction:
    -- the karesansui is to be reduced to the shōrō's own footprint, which gives the promenade back
    -- more than this takes. Until that lands the street is narrower here; the eave's encroachment is
    -- still aerial and still clears an avatar, which the tests hold.
    local Z0, Z1 = shop.envelope.z0, shop.envelope.z1 -- frontage (north, onto the promenade), back (south, into the cut)
    local FLOOR = shop.envelope.floorY -- finished floor, = the karesansui datum

    -- THE HOLDOUT'S TOP IS RETIRED (owner: "approximate, and can be safely ignored"). The height now
    -- comes from the storeys, and the REAL constraint is the one that always mattered: the shop must
    -- stay clearly subordinate to the bell tower. TOP is derived at the bottom of this block and
    -- checked against these two numbers, so growing a storey can never quietly close the gap.
    --
    -- THE TOWER IS A STACK, AND THIS USED TO BE A LITERAL HERE THAT NAMED ITS MIDDLE. It was 136.5 —
    -- the top of the Shoro MODEL — while the tower is seven models and the drum storey stands on the
    -- shōrō's roof and carries on up. The error was 17 studs and it ran the wrong way: it made the
    -- shop look like it was crowding a tower it cleared easily.
    --
    -- So it is no longer a literal here at all. ArenaLayout.towerTopY is the one authority, and a test
    -- rebuilds the tower and checks it — which matters, because the drum's roof was pitched up and
    -- given a sōrin on 2026-08-14 and the number moved again, from 153.54 to 168.67.
    local SHORO_TOP = L.towerTopY
    -- The OWNER'S number, from the spec: the shop tops "9 studs subordinate to the bell tower, which
    -- is the relationship the square depends on." This used to be 5.0 — a floor I invented when the
    -- holdout's top was retired, and then quoted back as though it were a gate they had set.
    local MIN_SHORO_GAP = 9.0

    local W = X1 - X0
    local D = Z1 - Z0
    local CX, CZ = (X0 + X1) / 2, (Z0 + Z1) / 2

    -- ===== storey heights, derived from the envelope so they cannot drift out of it =====
    local SLAB_T = 0.6 -- the raised timber floor, recipe §2's deck slab
    local STOREY_H = (shop.storeys and shop.storeys.ground) or 9.0 -- ground storey (owner's gate: +3; the shop read squat under its own upper floor)
    -- 5.0, up a stud at the owner's gate: at 4.0 a player climbing the stair put their head through
    -- the roof, and in first person you could see sky through the ceiling. The attic was simply
    -- shorter than a person and nothing measured it. The stud comes from HERE rather than from a
    -- lower attic floor because lowering the floor means shortening the ground storey (dropping it
    -- alone drops the eave with it and gains nothing) — and at STOREY_H 8.0 the shopfront's shoji
    -- transom collapses to zero height, the kamoi being fixed at 6.8 for avatar clearance.
    local UPPER_H = (shop.storeys and shop.storeys.upper) or 5.0 -- the closed lattice storey
    local EAVE_Y = FLOOR + STOREY_H + UPPER_H -- where the roof springs
    local ROOF_T = 0.25 -- roof and eave both halved at the owner's gate: a kawara edge, not a slab
    local EAVE_T = 0.25
    -- Less the slab thickness. A tilted slab meeting at the ridge puts its upper CORNER above the
    -- ridge line by roughly cos(pitch) * thickness/2, so a rise of exactly TOP - EAVE_Y overshoots the
    -- owner's top by ~0.1 studs. Trivial against the 9-stud gap to the shōrō, but TOP should mean the
    -- top — otherwise the envelope test has to tolerate a fudge, and a tolerated fudge grows.
    local ROOF_RISE = 4.01 -- the pitch, now an input rather than whatever was left under a fixed top
    local TOP = EAVE_Y + ROOF_RISE + ROOF_T -- derived; the slab's corner at the ridge is the true top
    -- NOT A CLEARANCE — the two buildings stand 15.9 studs apart in z and nothing overhangs anything.
    -- This is about the SKYLINE: the bell tower is meant to read as the tallest thing in the square.
    -- The shop tops at 131.36 and clears the tower comfortably. There is no tension here, and the old
    -- message said "crowds", which read as a collision and sent me chasing one that does not exist.
    assert(
        TOP <= SHORO_TOP - MIN_SHORO_GAP,
        `machiya top {TOP} reads too tall beside the bell tower's {SHORO_TOP}`
    )

    -- The eave overhangs the frontage by this much. THIS IS THE ONE DELIBERATE ENCROACHMENT on the
    -- reserved promenade, and it is aerial: its underside sits a full storey up, so nothing at
    -- ground level enters the corridor. Without it the building has no shopfront shadow and reads
    -- as a shed.
    local EAVE_OVERHANG = 2.5
    -- THE MAIN ROOF COVERS THE UPPER STOREY ONLY (owner's gate). It used to spring from the hisashi's
    -- outer edge, so one roof plane ran from the ridge all the way out over the shopfront — the
    -- building read as a single shed rather than as a two-storey machiya with a shop under a separate
    -- eave. Now it overhangs the WALLS by ROOF_EAVE and no further; the hisashi is its own roof.
    local ROOF_EAVE = 0.8
    local ROOF_RIDGE_Z = (Z0 + Z1) / 2

    -- 0.7, not the recipe's 1.125. Deck posts carry a platform over a drop and are sized for it;
    -- a shopfront post is a slender column standing on its own floor, and at 1.125 across a 19-stud
    -- frontage the bays read as a fence rather than an opening. (Owner's gate: "too thick".)
    local POST_W = 0.49 -- owner's gate: 70% of 0.7; six posts at deck weight read as a fence
    local GIRDER_H, GIRDER_W = 1.2, 0.825
    local WALL_T = 0.5
    -- Concrete carrying MachiyaPlaster (a clone of the unused ZenMortar1 at 1.5 studs/tile). Bare
    -- Sandstone renders at Roblox's own tile scale, which on a wall reads as boulders rather than
    -- render. The variant is the shop's OWN, so retuning its pitch cannot disturb the cement paths.
    local STUCCO_MAT = "Concrete"
    local STUCCO_VAR = "MachiyaPlaster"

    -- STUCCO SITS BACK; TIMBER STANDS PROUD. Everything was flush at the frontage plane, so the frame
    -- and the render were coplanar and the timber simply disappeared into the wall. A timber-framed
    -- building only reads if the frame is in front of the panel it holds.
    local STUCCO_SETBACK = 0.30

    -- THE STUCCO BOX. Every render plane is a face of ONE inset box, derived here, because deriving
    -- them separately is how the building came apart: the side walls were moved in by the setback
    -- while the front, the back and the gables still spanned the full envelope, so each panel was
    -- inset on its own axis and oversized on the others. A wall's IN-PLANE dimensions have to shrink
    -- with the box too, not just its own offset.
    --   SX0/SX1 — the render's west/east faces      SZ1 — its back face
    --   SZ0     — the upper storey's street face (the ground storey opens instead)
    local SX0, SX1 = X0 + STUCCO_SETBACK, X1 - STUCCO_SETBACK
    local SZ0, SZ1 = Z0 + STUCCO_SETBACK, Z1 - STUCCO_SETBACK
    local SW = SX1 - SX0 -- the box's width; NOT W
    -- Side walls run BETWEEN the box's front and back faces. Running them to Z0 put their front
    -- edge exactly on the corner post's front face — proud on one axis and flush on the other reads
    -- as flush.
    local SD = SZ1 - SZ0

    -- The posts wear CypressVertical and came out darker; the beams they carry were plain Wood and did
    -- not match. One variant for every piece of exterior frame.
    local FRAME_VAR = "CypressVertical"
    local KOSHI_T = 0.18
    local COUNTER_H = 3.0 -- ~3 ft. 1.1 was 13 inches: a step, not a counter
    local COUNTER_D = 2.0
    -- Back wall to the counter's CENTRE. Pulled a stud forward at the owner's gate so a shopkeeper
    -- can stand behind it: 1.6 studs of clearance is a shelf, 2.6 is a place to work.
    local COUNTER_STANDOFF = 4.4
    local COUNTER_Z = Z1 - COUNTER_STANDOFF
    local COUNTER_BACK_Z = COUNTER_Z + COUNTER_D / 2

    -- ===== the stair to the upper storey =====
    -- Along the EAST wall, climbing NORTH from the counter's back edge (the owner set its foot there,
    -- so it is derived from the counter and moves with it rather than being a second magic number).
    -- Deliberately steep and narrow — a machiya's stair is nearer a ladder than a staircase, and one
    -- body wide is the honest width for a shop this size.
    local UPPER_SURFACE = FLOOR + STOREY_H + SLAB_T -- what you stand on upstairs
    local STAIR_TREADS = 11
    -- The last riser is the upper floor itself, so TREADS+1 risers span the storey. Asserted rather
    -- than trusted: a rise that does not divide leaves a final step of the wrong height, which reads
    -- as a stumble in Play and as nothing at all in the explorer.
    local STAIR_RISE = (UPPER_SURFACE - FLOOR) / (STAIR_TREADS + 1)
    -- Only a FULL interior builds the stair, so only a full interior is held to its geometry —
    -- a shallow shell with custom storeys owes nothing to a stair it does not have.
    if shop.interior == "full" then
        assert(math.abs(STAIR_RISE - 0.8) < 1e-9, `stair rise {STAIR_RISE} is not the intended 0.8`)
    end
    local STAIR_RUN = 0.72 -- 48° — steep, which is the point
    local STAIR_W = 3.2 -- OUTER to outer, stringers included
    local STRINGER_T = 0.45
    local STRINGER_H = 0.60
    -- How deep a tread is let into its stringer. The treads used to run the full width, so their ends
    -- finished flush with the stringers' outer faces and the joint read as a butt rather than a
    -- housing. Now the stringer stands proud of the tread end by (STRINGER_T - TREAD_HOUSING) and you
    -- can see the tread go into it.
    local TREAD_HOUSING = 0.30
    assert(TREAD_HOUSING < STRINGER_T, "a tread housed the full thickness of its stringer cuts it in two")
    local TREAD_W = STAIR_W - 2 * (STRINGER_T - TREAD_HOUSING)
    local TREAD_T = 0.28
    -- NOT the frame's CypressVertical. That variant's maps are ROTATED 90° and it exists for flat
    -- VERTICAL members — on a tread, which is a horizontal board, the grain ran across the plank
    -- instead of along it. CypressWeathered is the unrotated timber the bridge decking wears.
    local STAIR_VAR = "CypressWeathered"

    -- The stairwell. Its south edge is set by HEADROOM, not by taste: a climber on tread k has their
    -- feet at FLOOR + k*RISE and wants a working avatar's 6 studs above that, against an underside at
    -- FLOOR + STOREY_H. Treads 1 and 2 pass under it comfortably; the third would clear by about half
    -- a stud, which is no clearance at all once a body has depth, so the cut opens at the third.
    local STAIR_HEAD_CLEAR = 2 -- treads that stay under the upper floor
    -- The invariant is that no COVERED tread traps a climber. Opening a tread earlier than strictly
    -- required is a margin and is fine; opening one later is a low beam you cannot see in the
    -- explorer. Strict headroom would allow three covered treads (the third clears by 0.6) — the
    -- third is given away on purpose, because 0.6 studs is not clearance once a body has depth.
    if shop.interior == "full" then
        assert(
            FLOOR + STAIR_HEAD_CLEAR * STAIR_RISE + 6.0 <= FLOOR + STOREY_H,
            "the stairwell opens too late — a climber meets the upper floor before the cut"
        )
    end
    local WELL_Z1 = COUNTER_BACK_Z - STAIR_HEAD_CLEAR * STAIR_RUN
    local WELL_Z0 = COUNTER_BACK_Z - STAIR_TREADS * STAIR_RUN
    -- Hard against the east wall's inner face, and the well is cut a little wider than the stair so a
    -- climber's shoulders are not clipping the floor edge on the way up.
    local STAIR_X1 = SX1 - WALL_T
    local STAIR_X0 = STAIR_X1 - STAIR_W
    local WELL_X0 = STAIR_X0 - 0.2

    -- inset a coordinate so a post's OUTER face sits flush with the slab edge (recipe standing rule)
    local function flushX(x: number): number
        if math.abs(x - X0) < 0.01 then
            return x + POST_W / 2
        elseif math.abs(x - X1) < 0.01 then
            return x - POST_W / 2
        end
        return x
    end

    -- row-major rotation about X, for the roof slopes
    -- Row-major rotation about X. SIGN CONVENTION, because getting it backwards builds a TROUGH
    -- instead of a ridge and the tests cannot see it: row 1 is (0, c, -s), so a point at the slab's
    -- +Z end maps to y' = -sin(deg) * L/2. POSITIVE deg therefore LOWERS the +Z end.
    -- So: the slope whose +Z end is the RIDGE takes a NEGATIVE angle; the slope whose +Z end is the
    -- EAVE takes a positive one. (Shipped inverted once, 2026-08-05 — caught by eye, not by test.)
    local function rotX(deg: number): { number }
        local r = math.rad(deg)
        local c, s = math.cos(r), math.sin(r)
        return { 1, 0, 0, 0, c, -s, 0, s, c }
    end

    local children = {}
    local timber = palette.timber
    -- STUCCO, not boards (owner's gate). Roblox has no plaster material; Sandstone over the
    -- palette's warm grey is the closest read, and quiet walls are what let the timber frame
    -- and the shoji do the talking.
    local stucco = palette.gravel
    local paper = palette.ivory
    local tile = palette.slateTile
    local ink = palette.ink

    local function add(
        name: string,
        size: { number },
        pos: { number },
        colour: { number },
        material: string,
        rot: { number }?,
        variant: string?
    )
        local props: { [string]: any } = {
            Size = size,
            CFrame = Spec.cframe(pos, rot),
            Color = colour,
            Material = material,
            CanCollide = true,
            CastShadow = false,
        }
        -- THE SHŌRŌ'S OWN ROOF TILE. Its RoofPanels are Material=Slate wearing the `SlateTile`
        -- variant (base Slate, the ambientCG kawara). Bare Slate reads as flat grey stone and made
        -- the shop look like a different building tradition standing in the same square.
        if variant then
            props.MaterialVariant = variant
        end
        -- A ROOF RIDGE IS A PERCH, and it is the one the owner asked for first: standing in the
        -- square you should see birds on the roofs. Emitted by the builder because Rojo owns every
        -- RoshamboStage prop — an attachment stamped on this in Studio dies at the next sync.
        -- Three along the ridge, so a roofline reads as occupied rather than as having one bird
        -- balanced in the middle of it.
        if name == "Ridge" then
            local kids = {}
            for i = 1, 3 do
                table.insert(kids, Spec.perch("ridge", { size[1] * ((i - 2) * 0.3), size[2] / 2, 0 }))
            end
            props.children = kids
        end
        table.insert(children, Spec.part(name, props))
    end

    -- ----- the raised timber floor -----
    -- "Wood" + the frame variant, matching the upper floor. WoodPlanks with no variant is the
    -- pale timber the building has been moving away from — and a variant set on a WoodPlanks part
    -- would be silently dropped anyway, which is how the upper floor stayed pale twice.
    add("FloorSlab", { W, SLAB_T, D }, { CX, FLOOR - SLAB_T / 2, CZ }, timber, "Wood", nil, FRAME_VAR)

    -- ===== frontage constants, shared by BOTH frontage branches =====
    -- THE KAMOI HAS TO CLEAR A PLAYER. The working avatar height is 6 studs (a bare R15 is ~5;
    -- hair adds a stud and players wear it), and this rail spans the whole frontage — at its old
    -- 3.9 you would have walked face-first into the doorway you were meant to enter.
    local HEAD_Y = FLOOR + 6.8
    local TRANSOM_TOP = FLOOR + STOREY_H - GIRDER_H
    -- BEHIND the closed bays' panels (which sit at STUCCO_SETBACK + 0.18, 0.36 thick), so a
    -- screen slid aside is genuinely occluded by the wall rather than poking through it.
    local DOOR_Z = Z0 + STUCCO_SETBACK + 0.62
    -- Timber front faces sit EXACTLY on the frontage plane: half the member's depth, no more. At
    -- 0.16 against a 0.34-deep member they poked 0.01 studs into the reserved promenade, which the
    -- clearance test correctly refused — a hair over the line is still over it.
    local FRAME_D2 = 0.34
    local FRAME_Z = Z0 + FRAME_D2 / 2
    local LAT_D = 0.2
    local LAT_Z = Z0 + LAT_D / 2 -- inboard of the posts, so the noren still hangs in front

    -- ----- the frontage: OPEN (posts and trading bays) or KOSHI (a closed lattice wall) -----
    -- Owner's gate: 3 centre posts + 2 corners, down from 4 + 2 — and PER-SHOP since the
    -- stats false front (2026-08-15): a 10-stud two-bay facade carries 3. The default is
    -- the row's 5, so every shop that doesn't set shop.frontPosts emits byte-identically
    -- (the committed model.json assets gate that).
    local FRONT_POSTS = shop.frontPosts or 5
    assert(FRONT_POSTS >= 3, `frontPosts {FRONT_POSTS} leaves no frontage: 3 posts (2 bays) is the floor`)
    local postX = {} -- kept so the sign boards register to the BAYS, not to the frontage
    -- Populated by the open branch only; a kōshi frontage has no bays to close or open, so the
    -- noren emitter (which walks these) naturally emits nothing there.
    local CLOSED: { [number]: boolean } = {}
    -- The OPEN span: the first open bay's west post to the last open bay's east post — the
    -- line the head rail and the counter register to. With the default closed end bays this
    -- is postX[2]..postX[FRONT_POSTS - 1], exactly what those members always spanned.
    local OPEN_X0, OPEN_X1 = 0, 0

    if shop.frontage == "open" then
        -- the OPEN frontage: six posts, no wall
        for i = 1, FRONT_POSTS do
            local t = (i - 1) / (FRONT_POSTS - 1)
            local x = flushX(X0 + (X1 - X0) * t)
            postX[i] = x
            -- CypressVertical, not plain Wood. Roblox's Wood grain runs along the part's X axis, so on
            -- a tall thin post it bands ACROSS the timber like a stack of planks. The place already
            -- carries a vertical-grain variant for exactly this — 20 parts wear it.
            add(
                `FrontPost{i}`,
                { POST_W, STOREY_H, POST_W },
                { x, FLOOR + STOREY_H / 2, Z0 + POST_W / 2 },
                timber,
                "Wood",
                nil,
                "CypressVertical"
            )
        end

        -- ----- the shopfront: SLIDING DOORS, STANDING OPEN, UNDER SHOJI TRANSOMS -----
        -- A machiya's shopfront is not a hole — it is a run of sliding doors that have been pushed
        -- aside for the day. Rendering them open is what says "this shop is trading", and it reads far
        -- better than an empty gap: you can see what closes.
        --
        -- Each bay gets a fixed shoji transom above the head rail (kamoi) and one door leaf slid to
        -- the bay's west jamb, leaving roughly two-thirds of the opening clear. Leaves alternate which
        -- jamb they park against, because a whole row stacked the same way reads mechanical.
        -- (HEAD_Y / TRANSOM_TOP / DOOR_Z / FRAME_* / LAT_* are declared with the shared frontage
        -- constants above — the kōshi branch builds from the same planes.)

        -- THE TWO OUTER BAYS ARE CLOSED (owner's gate, matching the reference). A machiya shopfront is
        -- not open end to end — the opening is the middle of the elevation with plastered wall either
        -- side. It also gives the counter something to sit against.
        -- ONLY when there are outer bays to close: a two-bay front (frontPosts 3) has no
        -- ends to wall off — closing them would close the whole elevation — so BOTH bays
        -- stay open (the owner's ruling on the stats false front).
        if FRONT_POSTS - 1 >= 3 then
            CLOSED[1] = true
            CLOSED[FRONT_POSTS - 1] = true
        end
        local firstOpen, lastOpen
        for i = 1, FRONT_POSTS - 1 do
            if not CLOSED[i] then
                firstOpen = firstOpen or i
                lastOpen = i
            end
        end
        OPEN_X0, OPEN_X1 = postX[firstOpen], postX[lastOpen + 1]

        -- spans the OPEN bays only; any closed ends carry their own head band
        add(
            "HeadRail",
            { OPEN_X1 - OPEN_X0, 0.3, 0.32 },
            { (OPEN_X0 + OPEN_X1) / 2, HEAD_Y + 0.15, FRAME_Z },
            timber,
            "Wood",
            nil,
            FRAME_VAR
        )

        for i = 1, FRONT_POSTS - 1 do
            local a, b = postX[i], postX[i + 1]
            local bayW = (b - a) - POST_W
            local bayC = (a + b) / 2

            if CLOSED[i] then
                -- render set BACK, so the frame in front of it is what you see
                local panelH = TRANSOM_TOP - FLOOR
                add(
                    `BayPanel{i}`,
                    { bayW, panelH, 0.36 },
                    { bayC, FLOOR + panelH / 2, Z0 + STUCCO_SETBACK + 0.18 },
                    stucco,
                    STUCCO_MAT,
                    nil,
                    STUCCO_VAR
                )
                -- the frame: sill, head and two jambs, all standing at the frontage plane
                local FR = 0.26
                add(
                    `BaySill{i}`,
                    { bayW + POST_W, FR, FRAME_D2 },
                    { bayC, FLOOR + FR / 2, FRAME_Z },
                    timber,
                    "Wood",
                    nil,
                    FRAME_VAR
                )
                add(
                    `BayHead{i}`,
                    { bayW + POST_W, FR, FRAME_D2 },
                    { bayC, TRANSOM_TOP - FR / 2, FRAME_Z },
                    timber,
                    "Wood",
                    nil,
                    FRAME_VAR
                )
                for k, jx in { bayC - bayW / 2, bayC + bayW / 2 } do
                    add(
                        `BayJamb{i}_{k}`,
                        { FR, panelH, FRAME_D2 },
                        { jx, FLOOR + panelH / 2, FRAME_Z },
                        timber,
                        "Wood",
                        nil,
                        FRAME_VAR
                    )
                end
                -- shoji-like lattice across the panel: a coarse grid, proud of the render
                local LAT = 0.1
                local latH = panelH - 2 * FR
                local latY = FLOOR + FR + latH / 2
                for k = 1, 4 do
                    add(
                        `BayLatV{i}_{k}`,
                        { LAT, latH, LAT_D },
                        { bayC - bayW / 2 + bayW * (k / 5), latY, LAT_Z },
                        timber,
                        "Wood",
                        nil,
                        FRAME_VAR
                    )
                end
                for k = 1, 3 do
                    add(
                        `BayLatH{i}_{k}`,
                        { bayW, LAT, LAT_D },
                        { bayC, latY - latH / 2 + latH * (k / 4), LAT_Z },
                        timber,
                        "Wood",
                        nil,
                        FRAME_VAR
                    )
                end
            else
                local tH = TRANSOM_TOP - HEAD_Y
                add(`Transom{i}`, { bayW, tH, 0.1 }, { bayC, HEAD_Y + tH / 2, DOOR_Z }, paper, "Fabric")
                for k = 1, 2 do
                    add(
                        `TransomBar{i}_{k}`,
                        { 0.09, tH, 0.14 },
                        { bayC - bayW / 4 + (bayW / 2) * (k - 1), HEAD_Y + tH / 2, DOOR_Z },
                        ink,
                        "Wood"
                    )
                end
                -- THE SCREEN IS FULL BAY WIDTH AND SLID TWO-THIRDS AWAY, so the opening is 2/3 clear
                -- and the hidden third-and-a-bit sits BEHIND the closed bay next to it. That is how a
                -- sliding screen actually works — it does not shrink, it goes somewhere. It parks
                -- toward whichever neighbouring bay is closed, which is what gives it somewhere to go.
                -- AND THAT IS THE CONDITION: with no closed bay on either side (the two-bay front,
                -- where nothing closes) a full-width leaf parked at either jamb would overhang the
                -- building's corner or the neighbouring doorway — there is nowhere for it to go. So
                -- such a bay ships its screens STORED (off-stage, the way amado live in a shutter
                -- box) and reads fully open; the transom above still says what the opening is.
                if CLOSED[i - 1] == true or CLOSED[i + 1] == true then
                    local leafW = bayW
                    local openW = bayW
                    local parkWest = CLOSED[i - 1] == true
                    local leafC = if parkWest
                        then (a + POST_W / 2 - openW / 6)
                        else (b - POST_W / 2 + openW / 6)
                    -- The screen RUNS IN A TRACK and closes with a rail top and bottom. Its stiles used
                    -- to end at floor level with no bottom member, so the frame terminated into the floor
                    -- instead of closing against it — which reads as buried, because nothing caps it.
                    local RAIL_T = 0.16
                    local leafY0 = FLOOR + 0.1 -- the track it slides in
                    local leafH = HEAD_Y - leafY0
                    local leafCY = leafY0 + leafH / 2
                    -- The paper is INSET inside its own frame. At full leaf size its edges landed exactly on
                    -- the stiles', so the sheet was visible edge-on — a pane the same size as its sash.
                    -- Real shoji paper is glued behind the frame and stops short of it on every side.
                    add(
                        `DoorLeaf{i}`,
                        { leafW - 2 * 0.16, leafH - 2 * RAIL_T, 0.05 },
                        { leafC, leafCY, DOOR_Z },
                        paper,
                        "Fabric"
                    )
                    -- stiles, rails and a proper kumiko grid, all in the frame's dark wood
                    for k, sx in { leafC - leafW / 2 + 0.07, leafC + leafW / 2 - 0.07 } do
                        add(
                            `DoorStile{i}_{k}`,
                            { 0.14, leafH, 0.15 },
                            { sx, leafCY, DOOR_Z },
                            timber,
                            "Wood",
                            nil,
                            FRAME_VAR
                        )
                    end
                    for k, ry in { leafY0 + RAIL_T / 2, HEAD_Y - RAIL_T / 2 } do
                        add(
                            `DoorRail{i}_{k}`,
                            { leafW, RAIL_T, 0.15 },
                            { leafC, ry, DOOR_Z },
                            timber,
                            "Wood",
                            nil,
                            FRAME_VAR
                        )
                    end
                    local LAT_N_V, LAT_N_H = 5, 7
                    for k = 1, LAT_N_V do
                        add(
                            `DoorLatV{i}_{k}`,
                            { 0.075, leafH, 0.13 },
                            { leafC - leafW / 2 + leafW * (k / (LAT_N_V + 1)), leafCY, DOOR_Z },
                            timber,
                            "Wood",
                            nil,
                            FRAME_VAR
                        )
                    end
                    for k = 1, LAT_N_H do
                        add(
                            `DoorLatH{i}_{k}`,
                            { leafW, 0.075, 0.13 },
                            { leafC, leafY0 + leafH * (k / (LAT_N_H + 1)), DOOR_Z },
                            timber,
                            "Wood",
                            nil,
                            FRAME_VAR
                        )
                    end
                end -- a leaf only where a closed neighbour gives it somewhere to park
            end
        end
    else
        -- ----- the KOSHI frontage: the street wall CLOSES, and nothing opens -----
        -- The sealed-shell pattern (design spec): no bays, no doors, no counter behind — a full
        -- run of floor-to-kamoi lattice standing in front of a rendered wall, the ground-storey
        -- cousin of the upper storey's mushiko-mado. Same grammar as everywhere else on this
        -- building: STUCCO SITS BACK, TIMBER STANDS PROUD, front faces exactly on the frontage
        -- plane and not a hair past it.
        add(
            "FrontWall",
            -- between the side walls, like WallBack — they run the full depth and close the corner
            { SW - 2 * WALL_T, STOREY_H, WALL_T },
            { CX, FLOOR + STOREY_H / 2, SZ0 + WALL_T / 2 },
            stucco,
            STUCCO_MAT,
            nil,
            STUCCO_VAR
        )
        -- corner posts, standing where FrontPost1/5 stand on the open frontage
        for _, cp in { { "West", flushX(X0) }, { "East", flushX(X1) } } do
            add(
                `KoshiPost{cp[1]}`,
                { POST_W, STOREY_H, POST_W },
                { cp[2] :: number, FLOOR + STOREY_H / 2, Z0 + POST_W / 2 },
                timber,
                "Wood",
                nil,
                "CypressVertical"
            )
        end
        -- the frame the lattice runs in: a sill at the floor, a head band at the kamoi line
        local FR = 0.26
        local frameW = (X1 - X0) - 2 * POST_W
        add(
            "KoshiSill",
            { frameW, FR, FRAME_D2 },
            { CX, FLOOR + FR / 2, FRAME_Z },
            timber,
            "Wood",
            nil,
            FRAME_VAR
        )
        add(
            "KoshiHead",
            { frameW, 0.3, FRAME_D2 },
            { CX, HEAD_Y + 0.15, FRAME_Z },
            timber,
            "Wood",
            nil,
            FRAME_VAR
        )
        -- The lattice: full width, sill to kamoi, at the upper storey's kōshi pitch — KOSHI_N
        -- is 18 bars over a 12-stud window, 1.5 bars per stud, and the count follows the width
        -- (integer-derived, so the emitted floats stay arch-stable).
        local latH = HEAD_Y - (FLOOR + FR)
        local nBars = math.max(6, math.round(frameW * 1.5))
        for i = 1, nBars do
            local t = (i - 0.5) / nBars
            add(
                `KoshiFront_{i}`,
                { KOSHI_T, latH, KOSHI_T },
                { X0 + POST_W + frameW * t, FLOOR + FR + latH / 2, Z0 + KOSHI_T / 2 },
                timber,
                "Wood",
                nil,
                FRAME_VAR
            )
        end
    end

    -- ----- side and back walls (ground storey) -----
    add(
        "WallWest",
        { WALL_T, STOREY_H, SD },
        { SX0 + WALL_T / 2, FLOOR + STOREY_H / 2, (SZ0 + SZ1) / 2 },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    add(
        "WallEast",
        { WALL_T, STOREY_H, SD },
        { SX1 - WALL_T / 2, FLOOR + STOREY_H / 2, (SZ0 + SZ1) / 2 },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    -- The REAR DOORWAY is a per-shop capability (identity.rearDoor), default OFF: every shop
    -- that doesn't set it emits the solid WallBack below byte-identically (the committed-asset
    -- gates hold that). Stats opens here into the cavern to be bored behind it: a framed
    -- opening, NO door leaf (owner's choice) — a noren hangs in it instead (see emitRearNoren).
    local rearDoor: any = if shop.identity then (shop.identity :: any).rearDoor else nil
    if rearDoor then
        -- ----- the rear doorway: the wall opens, the frame registers to the wall's own faces -----
        -- Clear width is the CALLER'S (the tunnel bore nets ~6 studs and the mouth must not
        -- pinch it), centred on the shell. Everything else derives from what it touches:
        --   * the head is the shop's own kamoi line, HEAD_Y — the number every doorway in
        --     this building clears;
        --   * the stucco flanks and header sit exactly where WallBack sat (outer face on SZ1,
        --     WALL_T thick, running to the side walls' inner faces so the corner stays closed);
        --   * the timber posts and lintel pass THROUGH the wall — outer face flush on the
        --     wall's outer face (the plane the bore will meet, flush-outside-edges), standing
        --     FRAME_D2 proud of the inner face into the vestibule, the building's own
        --     "stucco sits back, timber stands proud" rule;
        --   * the FLOOR CONTINUES at FLOOR through the opening — the slab already runs to Z1
        --     and nothing is added at the threshold, because the tunnel floor meets it there.
        local RD_W = rearDoor.width
        assert(type(RD_W) == "number" and RD_W > 0, `rearDoor.width {tostring(RD_W)} is not a width`)
        local RD_LINTEL_H = 0.5
        local sideW = ((SW - 2 * WALL_T) - (RD_W + 2 * POST_W)) / 2
        assert(sideW > 0, `rearDoor width {RD_W} + posts leaves no back wall on a {SW}-wide box`)
        local headH = FLOOR + STOREY_H - (HEAD_Y + RD_LINTEL_H)
        assert(headH > 0, "the rear lintel reaches the storey top — no header wall remains")
        local frameD = WALL_T + FRAME_D2 -- through the wall, plus the frame's proud stand
        local frameZ = SZ1 - frameD / 2 -- outer face flush on the wall's outer face
        local wallZ = SZ1 - WALL_T / 2 -- the stucco's own plane, = WallBack's
        for _, flank in
            {
                { "WallBackWest", SX0 + WALL_T + sideW / 2 },
                { "WallBackEast", SX1 - WALL_T - sideW / 2 },
            }
        do
            add(
                flank[1] :: string,
                { sideW, STOREY_H, WALL_T },
                { flank[2] :: number, FLOOR + STOREY_H / 2, wallZ },
                stucco,
                STUCCO_MAT,
                nil,
                STUCCO_VAR
            )
        end
        add(
            "WallBackHead",
            { RD_W + 2 * POST_W, headH, WALL_T },
            { CX, HEAD_Y + RD_LINTEL_H + headH / 2, wallZ },
            stucco,
            STUCCO_MAT,
            nil,
            STUCCO_VAR
        )
        for _, post in
            {
                { "RearDoorPostWest", CX - RD_W / 2 - POST_W / 2 },
                { "RearDoorPostEast", CX + RD_W / 2 + POST_W / 2 },
            }
        do
            add(
                post[1] :: string,
                { POST_W, HEAD_Y - FLOOR, frameD },
                { post[2] :: number, (FLOOR + HEAD_Y) / 2, frameZ },
                timber,
                "Wood",
                nil,
                FRAME_VAR
            )
        end
        -- The lintel BEARS on the posts — post outer edge to post outer edge, not floating
        -- across the opening. CypressWeathered, not the posts' CypressVertical: a horizontal
        -- member, the distinction the stair timber turned on.
        add(
            "RearDoorLintel",
            { RD_W + 2 * POST_W, RD_LINTEL_H, frameD },
            { CX, HEAD_Y + RD_LINTEL_H / 2, frameZ },
            timber,
            "Wood",
            nil,
            STAIR_VAR
        )
    else
        add(
            "WallBack",
            -- BETWEEN the side walls, not across them. At the full SW its end faces landed on exactly
            -- the same planes as the side walls' outer faces, which is the same coplanar-face defect
            -- the stairwell flickered from — found on the back corners while checking that fix. The
            -- side walls run the full depth, so they close the corner and nothing opens up.
            { SW - 2 * WALL_T, STOREY_H, WALL_T },
            { CX, FLOOR + STOREY_H / 2, SZ1 - WALL_T / 2 },
            stucco,
            STUCCO_MAT,
            nil,
            STUCCO_VAR
        )
    end

    -- ----- THE FRAME ON THE FLANKS -----
    -- From the side the building read as one plane of render with no structure in it — the posts
    -- and beams only ever existed on the street elevation. A machiya's flank shows its frame:
    -- corner posts, an intermediate one, and a nageshi band at the storey division. All stand
    -- proud of the wall behind them, which is the whole point.
    -- STUCCO FILLS, TIMBER DIVIDES. The reference's flank is mostly render, gridded by dark
    -- posts and horizontal bands, with a boarded skirt at the bottom where the street reaches it.
    -- The previous pass clad the whole flank in timber, which inverted the relationship: the frame
    -- is supposed to be the minority.
    -- THE BAY MODULE IS WHAT IS FIXED, not the bay count. The owner's gate here was against an
    -- IRREGULAR rhythm — four posts once gave bays of 2.2 / 2.6 / 1.9, which read as a mistake
    -- rather than as a frame — and three posts over an 8-deep flank happened to give two equal
    -- 4-stud bays. Doubling the depth with that count would have stretched them to 8 studs and
    -- coarsened the whole elevation, so the module holds at 4 and the count follows the depth.
    -- The bays are equal BY CONSTRUCTION, which is the property that was actually gated.
    --
    -- The GROUND storey shares its front corner with the street elevation (FrontPost1/5 stand
    -- there, and a SidePost at the same z would put a second post in the same cubic space). The
    -- UPPER storey does not — FrontPost stops at the upper floor — so upstairs the front corner
    -- had no post at all. Two lists, because the two storeys genuinely differ.
    local FLANK_BAYS = math.max(2, math.round(D / 4.0))
    local SIDE_POST_Z, UPPER_POST_Z = {}, {}
    for k = 0, FLANK_BAYS do
        -- End posts inset half a post so they sit inside the envelope; the span between those
        -- insets is what divides, which is why the middle post lands exactly on CZ.
        local pz = Z0 + POST_W / 2 + (k / FLANK_BAYS) * (D - POST_W)
        table.insert(UPPER_POST_Z, pz)
        if k > 0 then
            table.insert(SIDE_POST_Z, pz)
        end
    end
    local BAND_T = 0.3
    local SKIRT_H = 1.3
    for _, side in { { "West", X0 + POST_W / 2 }, { "East", X1 - POST_W / 2 } } do
        local nm, px = side[1] :: string, side[2] :: number
        -- vertical posts, ground storey AND upper, so the grid runs the full elevation
        for k, pz in SIDE_POST_Z do
            add(
                `SidePost{nm}{k}`,
                { POST_W, STOREY_H, POST_W },
                { px, FLOOR + STOREY_H / 2, pz },
                timber,
                "Wood",
                nil,
                FRAME_VAR
            )
        end
        -- The upper storey's own posts, including the front corner. No mid rail and no skirt —
        -- "similar but simpler": the grid carries up so the elevation reads as one frame, while
        -- the storey above stays quieter than the one at street level.
        for k, pz in UPPER_POST_Z do
            -- THE CENTRE POST IS A KING POST: it carries on past the eave line to the ridge,
            -- which is what the gable is hung on. The others stop at the eave, because that is
            -- where the wall stops.
            local isKing = math.abs(pz - CZ) < 0.001
            local topY = if isKing then TOP else EAVE_Y
            local h = topY - (FLOOR + STOREY_H)
            add(
                `SideUpperPost{nm}{k}`,
                { POST_W * 0.8, h, POST_W * 0.8 },
                { px, FLOOR + STOREY_H + h / 2, pz },
                timber,
                "Wood",
                nil,
                FRAME_VAR
            )
        end
        -- the beam at the eave line, where the roof edge meets the flank
        -- out to the ROOF EDGES, not the wall line: the beam at the eave belongs to the roof's
        -- span, and stopping it at the wall left the overhang unsupported to the eye.
        add(
            `SideEaveBeam{nm}`,
            { POST_W * 0.85, BAND_T, D + 2 * ROOF_EAVE },
            { px, EAVE_Y - BAND_T / 2, CZ },
            timber,
            "Wood",
            nil,
            FRAME_VAR
        )
        -- horizontal bands: the skirt head, a mid rail, and the nageshi at the storey division
        for k, by in { FLOOR + SKIRT_H, FLOOR + STOREY_H * 0.55, FLOOR + STOREY_H - BAND_T / 2 } do
            add(
                `SideBand{nm}{k}`,
                { POST_W * 0.85, BAND_T, D },
                { px, by, CZ },
                timber,
                "Wood",
                nil,
                FRAME_VAR
            )
        end
        -- the boarded skirt (shitami-ita) along the bottom
        add(
            `SideSkirt{nm}`,
            { POST_W * 0.7, SKIRT_H, D },
            { px, FLOOR + SKIRT_H / 2, CZ },
            timber,
            "Wood",
            nil,
            FRAME_VAR
        )
    end

    -- ----- girders + the upper floor -----
    add(
        "GirderFront",
        { W, GIRDER_H, GIRDER_W },
        { CX, FLOOR + STOREY_H - GIRDER_H / 2, Z0 + GIRDER_W / 2 },
        timber,
        "Wood",
        nil,
        FRAME_VAR
    )
    add(
        "GirderBack",
        { W, GIRDER_H, GIRDER_W },
        { CX, FLOOR + STOREY_H - GIRDER_H / 2, Z1 - GIRDER_W / 2 },
        timber,
        "Wood",
        nil,
        FRAME_VAR
    )
    -- "Wood", not "WoodPlanks". A MaterialVariant is SILENTLY IGNORED unless the part's Material
    -- equals the variant's BaseMaterial, and CypressVertical is base Wood — so this floor was set
    -- to the dark variant twice and stayed pale both times, with nothing anywhere to say why.
    --
    -- FOUR PIECES, NOT ONE, because the stair has to come through it. A rectangular well is cut in
    -- the east side and the floor is laid around it: the main span west of the well, the two ends
    -- north and south of it, and a strip along the east wall that keeps the wall standing on
    -- floor rather than on air. The floor NORTH of the well is the landing the stair arrives on.
    local uy = FLOOR + STOREY_H + SLAB_T / 2
    if shop.interior ~= "full" then
        -- SHALLOW/NONE INTERIORS HAVE NO STAIR, SO THEY HAVE NO WELL: the storey floor is one
        -- uncut board. The four-piece lay-up below exists only to go around a stairwell.
        add("UpperFloor", { W, SLAB_T, D }, { CX, uy, CZ }, timber, "Wood", nil, FRAME_VAR)
    else
        add(
            "UpperFloor",
            { WELL_X0 - X0, SLAB_T, D },
            { (X0 + WELL_X0) / 2, uy, CZ },
            timber,
            "Wood",
            nil,
            FRAME_VAR
        )
        add(
            "UpperFloorNorth",
            { X1 - WELL_X0, SLAB_T, WELL_Z0 - Z0 },
            { (WELL_X0 + X1) / 2, uy, (Z0 + WELL_Z0) / 2 },
            timber,
            "Wood",
            nil,
            FRAME_VAR
        )
        add(
            "UpperFloorSouth",
            { X1 - WELL_X0, SLAB_T, Z1 - WELL_Z1 },
            { (WELL_X0 + X1) / 2, uy, (WELL_Z1 + Z1) / 2 },
            timber,
            "Wood",
            nil,
            FRAME_VAR
        )
        -- TUCKED INTO THE WALL, not flush with it. The east wall's inner face and this strip's west
        -- face both sat on x = STAIR_X1, both looking west into the stairwell — two coplanar faces
        -- claiming one plane, which flickered exactly at attic-floor level as you climbed the stairs
        -- and read as a horizontal beam laid against the wall. Starting the strip inside the wall
        -- hides its face entirely; the wall itself fills the sliver, so nothing opens up.
        local EDGE_TUCK = 0.08
        add(
            "UpperFloorEdge",
            { X1 - STAIR_X1 - EDGE_TUCK, SLAB_T, WELL_Z1 - WELL_Z0 },
            { (STAIR_X1 + EDGE_TUCK + X1) / 2, uy, (WELL_Z0 + WELL_Z1) / 2 },
            timber,
            "Wood",
            nil,
            FRAME_VAR
        )
        assert(
            EDGE_TUCK < WALL_T,
            "the floor strip is tucked deeper than the wall is thick — it would leave a slot at the well"
        )

        -- ----- the stair -----
        -- Treads are edge to edge in plan (run == tread depth), so there is no gap to drop through
        -- even though the risers are open. Two stringers carry them, pitched at the same angle the
        -- treads climb. The stair's low end is at +Z, and by the sign convention above a POSITIVE
        -- angle lowers the +Z end — the same trap that inverted the roof.
        local stairDeg = math.deg(math.atan2(STAIR_RISE, STAIR_RUN))
        local stairCX = (STAIR_X0 + STAIR_X1) / 2
        for k = 1, STAIR_TREADS do
            add(
                `StairTread{k}`,
                { TREAD_W, TREAD_T, STAIR_RUN },
                { stairCX, FLOOR + k * STAIR_RISE - TREAD_T / 2, COUNTER_BACK_Z - (k - 0.5) * STAIR_RUN },
                timber,
                "Wood",
                nil,
                STAIR_VAR
            )
        end

        -- THE NOSE LINE runs through the back-top corner of every tread, and the stair is laid out so
        -- that it arrives at the upper floor's WALKING SURFACE exactly at the well's north edge. The
        -- stringers follow that line, so they land on the floor rather than stopping a step short of
        -- it — which is what they did, because they were built from the top TREAD instead.
        local NOSE_Y0 = FLOOR + STAIR_RISE -- the line's height at z = COUNTER_BACK_Z
        local noseRun = COUNTER_BACK_Z - WELL_Z0
        assert(
            math.abs((NOSE_Y0 + noseRun * (STAIR_RISE / STAIR_RUN)) - UPPER_SURFACE) < 1e-9,
            "the stair does not land flush on the upper floor — the nose line misses the well's edge"
        )
        local rad = math.rad(stairDeg)
        -- Dropped so the stringer's TOP FACE lies on the nose line. Measured vertically, a
        -- perpendicular half-thickness is t/2 over cos(pitch) — at 48° that is half again as much
        -- as t/2, and using t/2 directly buries the treads.
        local stringerCY = (NOSE_Y0 + UPPER_SURFACE) / 2 - (STRINGER_H / 2) / math.cos(rad)
        -- AND THEN EXTENDED, because the end is cut SQUARE to the run. A stringer whose top face
        -- reaches the floor still stops short of it in the flesh: the square cut leaves the top corner
        -- (H/2)*sin(pitch) back down the slope, a gap you can see from the landing and cannot see in
        -- any number. Lengthening by (H/2)*tan(pitch), all of it at the top, walks that corner onto
        -- the floor edge; the rest of the end face tucks up under the landing, which is where a real
        -- stringer dies into its trimmer.
        local topExtra = (STRINGER_H / 2) * math.tan(rad)
        -- AND THE SAME ARITHMETIC AT THE FOOT, which was left undone: the square cut put the low end's
        -- bottom corner at 113.25 against a floor of 113.10, so both stringers HOVERED an eighth of a
        -- stud above the boards they were supposed to stand on. Bury the corner instead of touching
        -- it — a joint that merely touches shows a seam the moment anything moves.
        local STRINGER_BURY = 0.25
        local footY = NOSE_Y0 - (STRINGER_H / 2) / math.cos(rad) - (STRINGER_H / 2) * math.cos(rad)
        local bottomExtra = math.max(0, (footY - (FLOOR - STRINGER_BURY)) / math.sin(rad))
        local stairLen = math.sqrt(noseRun * noseRun + (UPPER_SURFACE - NOSE_Y0) ^ 2) + topExtra + bottomExtra
        -- Each extension grows the part by its full length but moves the centre by only half, and they
        -- pull in opposite directions along the slope — so the net shift is their difference, halved.
        local shift = (topExtra - bottomExtra) / 2
        for _, s in { { "West", STAIR_X0 + STRINGER_T / 2 }, { "East", STAIR_X1 - STRINGER_T / 2 } } do
            add(`StairStringer{s[1]}`, { STRINGER_T, STRINGER_H, stairLen }, {
                s[2] :: number,
                stringerCY + math.sin(rad) * shift,
                (COUNTER_BACK_Z + WELL_Z0) / 2 - math.cos(rad) * shift,
            }, timber, "Wood", rotX(stairDeg), STAIR_VAR)
        end
    end -- interior == "full": the well-cut floor and the stair end here

    -- ----- the closed upper storey: kōshi lattice to the street, boards elsewhere -----
    -- THE UPPER STOREY HAD NO STREET WALL — just a row of lattice bars with the building's inside
    -- visible between them (owner's gate). A machiya's upper floor is a plastered wall with a
    -- mushiko-mado, an "insect-cage" window: mostly wall, one banded lattice opening. So the wall
    -- is built in four pieces AROUND the window, and the kōshi fills the opening rather than
    -- standing in for the wall.
    local UPPER_Y0 = FLOOR + STOREY_H
    local WIN_H = 2.0
    local WIN_Y0 = UPPER_Y0 + (UPPER_H - WIN_H) / 2
    -- The opening reaches WIN_HALF either side of centre — 6.0, CAPPED so the window
    -- follows the stucco box on a narrow front: unconditionally 6.0, a 10-wide envelope
    -- (stats, SW 9.4) got NEGATIVE jamb widths. SW/2 - WIN_HALF is each jamb, floored at
    -- 1.0 (twice the wall's own thickness — enough render to read as wall, not trim).
    -- Every wider shop lands on the literal 6.0 exactly (accessories' SW/2 - 1.0 = 6.145
    -- is the tightest), so their emitted floats are untouched.
    local WIN_HALF = math.min(6.0, SW / 2 - 1.0)
    local WIN_X0, WIN_X1 = CX - WIN_HALF, CX + WIN_HALF
    local UF_Z = SZ0 + WALL_T / 2 -- the box's street face; the kōshi and the sign stand proud of it

    local belowH = WIN_Y0 - UPPER_Y0
    local aboveH = (UPPER_Y0 + UPPER_H) - (WIN_Y0 + WIN_H)
    add(
        "UpperWallFrontLow",
        { SW, belowH, WALL_T },
        { CX, UPPER_Y0 + belowH / 2, UF_Z },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    add(
        "UpperWallFrontHigh",
        { SW, aboveH, WALL_T },
        { CX, WIN_Y0 + WIN_H + aboveH / 2, UF_Z },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    local jambW = WIN_X0 - SX0
    add(
        "UpperWallFrontWest",
        { jambW, WIN_H, WALL_T },
        { SX0 + jambW / 2, WIN_Y0 + WIN_H / 2, UF_Z },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    add(
        "UpperWallFrontEast",
        { jambW, WIN_H, WALL_T },
        { SX1 - jambW / 2, WIN_Y0 + WIN_H / 2, UF_Z },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )

    -- the kōshi, now filling the window band only. The count follows the width at the
    -- band's own pitch — 18 bars over the full 12-stud window, 1.5 per stud, the same
    -- integer-derived rule the kōshi frontage uses — so a capped (narrower) window keeps
    -- the pitch instead of packing 18 bars into less wall. 2 * WIN_HALF * 1.5 is exact
    -- at the default (2 * 6.0 * 1.5 = 18), so wider shops emit the same 18 bars.
    local KOSHI_N = math.max(6, math.round(2 * WIN_HALF * 1.5))
    for i = 1, KOSHI_N do
        local t = (i - 0.5) / KOSHI_N
        add(
            `Koshi{i}`,
            { KOSHI_T, WIN_H, KOSHI_T },
            -- IN the opening, centred in the wall's thickness. At Z0 + KOSHI_T/2 they stood a
            -- third of a stud proud of the render — a lattice floating in front of its own window.
            { WIN_X0 + (WIN_X1 - WIN_X0) * t, WIN_Y0 + WIN_H / 2, UF_Z },
            timber,
            "Wood",
            nil,
            FRAME_VAR
        )
    end

    add(
        "UpperWallWest",
        { WALL_T, UPPER_H, SZ1 - SZ0 },
        { SX0 + WALL_T / 2, FLOOR + STOREY_H + UPPER_H / 2, (SZ0 + SZ1) / 2 },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    add(
        "UpperWallEast",
        { WALL_T, UPPER_H, SZ1 - SZ0 },
        { SX1 - WALL_T / 2, FLOOR + STOREY_H + UPPER_H / 2, (SZ0 + SZ1) / 2 },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )
    add(
        "UpperWallBack",
        { SW - 2 * WALL_T, UPPER_H, WALL_T }, -- between the side walls; see WallBack
        { CX, FLOOR + STOREY_H + UPPER_H / 2, SZ1 - WALL_T / 2 },
        stucco,
        STUCCO_MAT,
        nil,
        STUCCO_VAR
    )

    -- ----- the eave over the shopfront: aerial, a full storey up -----
    -- It TILTS. A flat hisashi reads as a shelf; the whole point of the shopfront eave is that it
    -- sheds toward the street and throws the goods into shade. It springs from the upper-floor
    -- line and drops HISASHI_DROP over its projection — so its +Z end (at the building) is the
    -- high one, which by the sign convention above means a NEGATIVE angle.
    local HISASHI_DROP = 0.5
    local hisashiDeg = math.deg(math.atan2(HISASHI_DROP, EAVE_OVERHANG))
    local hisashiLen = math.sqrt(EAVE_OVERHANG * EAVE_OVERHANG + HISASHI_DROP * HISASHI_DROP)
    add(
        "Eave",
        { W + 1.0, EAVE_T, hisashiLen },
        { CX, FLOOR + STOREY_H - HISASHI_DROP / 2, Z0 - EAVE_OVERHANG / 2 },
        tile,
        "Slate",
        rotX(-hisashiDeg),
        "SlateTile"
    )

    -- ----- the roof: a gabled kirizuma, ridge running east-west along the street -----
    -- Machiya are hirairi — you enter on the long side, under the eave, with the gables at the
    -- ends. Two slopes, symmetric about a ridge centred on the ROOF span (which reaches further
    -- north than the walls because of the overhang).
    local frontRun = ROOF_RIDGE_Z - (Z0 - ROOF_EAVE)
    local backRun = (Z1 + ROOF_EAVE) - ROOF_RIDGE_Z
    local frontLen = math.sqrt(frontRun * frontRun + ROOF_RISE * ROOF_RISE)
    local backLen = math.sqrt(backRun * backRun + ROOF_RISE * ROOF_RISE)
    local frontDeg = math.deg(math.atan2(ROOF_RISE, frontRun))
    local backDeg = math.deg(math.atan2(ROOF_RISE, backRun))

    add(
        "RoofNorth",
        { W + 1.0, ROOF_T, frontLen },
        { CX, EAVE_Y + ROOF_RISE / 2, (Z0 - ROOF_EAVE + ROOF_RIDGE_Z) / 2 },
        tile,
        "Slate",
        rotX(-frontDeg), -- +Z end is the RIDGE: negative angle raises it
        "SlateTile"
    )
    add(
        "RoofSouth",
        { W + 1.0, ROOF_T, backLen },
        { CX, EAVE_Y + ROOF_RISE / 2, (ROOF_RIDGE_Z + Z1 + ROOF_EAVE) / 2 },
        tile,
        "Slate",
        rotX(backDeg), -- +Z end is the back EAVE: positive angle drops it
        "SlateTile"
    )
    add("Ridge", { W + 1.2, 0.4, 0.6 }, { CX, TOP - 0.2, ROOF_RIDGE_Z }, ink, "Slate", nil, "SlateTile")

    -- Gable ends. Each is TWO right triangles back to back, which is what an isosceles gable is.
    --
    -- A WedgePart's TALL EDGE IS AT +Z, its thin edge at -Z. Established by building it the other
    -- way round first (2026-08-05): the gables came out as a notch — tall at both eaves, dipping
    -- at the ridge — the exact inverse of the roof. So the half whose +Z end is the RIDGE is the
    -- wedge unturned, and the half whose +Z end is the EAVE is turned 180° about Y.
    --
    -- North half spans front eave (low, -Z) -> ridge (high, +Z): unturned.
    -- South half spans ridge (high, -Z) -> back eave (low, +Z): turned.
    local GABLE_T = 0.4
    -- on the BOX faces, so the triangles sit over the walls they close rather than 0.3 outboard
    for _, end_ in { { "West", SX0 + GABLE_T / 2 }, { "East", SX1 - GABLE_T / 2 } } do
        local name, x = end_[1] :: string, end_[2] :: number
        table.insert(
            children,
            Spec.part(`Gable{name}North`, {
                className = "WedgePart",
                Size = { GABLE_T, ROOF_RISE, frontRun },
                CFrame = Spec.cframe({ x, EAVE_Y + ROOF_RISE / 2, (Z0 - ROOF_EAVE + ROOF_RIDGE_Z) / 2 }),
                Color = stucco,
                Material = STUCCO_MAT,
                MaterialVariant = STUCCO_VAR,
                CanCollide = true,
                CastShadow = false,
            })
        )
        table.insert(
            children,
            Spec.part(`Gable{name}South`, {
                className = "WedgePart",
                Size = { GABLE_T, ROOF_RISE, backRun },
                CFrame = Spec.cframe(
                    { x, EAVE_Y + ROOF_RISE / 2, (ROOF_RIDGE_Z + Z1 + ROOF_EAVE) / 2 },
                    { -1, 0, 0, 0, 1, 0, 0, 0, -1 }
                ),
                Color = stucco,
                Material = STUCCO_MAT,
                MaterialVariant = STUCCO_VAR,
                CanCollide = true,
                CastShadow = false,
            })
        )
    end

    -- ----- the attic tie beams -----
    -- The flank already carries a beam at the eave line OUTSIDE (SideEaveBeam); from within the
    -- attic the same walls were bare render up to the gable. One beam along each, at the height
    -- the roof springs, running the whole way between the roof edges — the hari of a small
    -- koyagumi, and the one member that makes an attic read as framed rather than as a void.
    --
    -- Ends buried in the upper front and back walls, so the beam reads as spanning wall to wall
    -- and shows no cut end. CypressWeathered, not the frame's CypressVertical: this is a
    -- horizontal member, which is the distinction the stair timber turned on.
    --
    -- STOPPING AN INCH SHORT OF SZ0/SZ1. At the full span the end faces landed exactly on the
    -- upper walls' OUTER faces — coplanar and same-facing, so they flickered on the street
    -- elevation. Buried is the intent; flush is a z-fight. The ends still sit a third of a stud
    -- inside each wall, so nothing opens up.
    -- Attic framing is INTERIOR: only a full interior has an attic anyone can climb to, so only
    -- a full interior carries the beams that make it read as framed.
    if shop.interior == "full" then
        local TIE_TUCK = 1 / 12 -- one inch
        local TIE_T, TIE_H = 0.55, 0.70
        assert(TIE_TUCK < WALL_T, "the attic tie stops short of the wall it is meant to be buried in")
        for _, side in { { "West", SX0 + WALL_T + TIE_T / 2 }, { "East", SX1 - WALL_T - TIE_T / 2 } } do
            add(
                `AtticTie{side[1]}`,
                { TIE_T, TIE_H, (SZ1 - SZ0) - 2 * TIE_TUCK },
                { side[2] :: number, EAVE_Y - TIE_H / 2, (SZ0 + SZ1) / 2 },
                timber,
                "Wood",
                nil,
                STAIR_VAR
            )
        end
    end

    -- ----- noren: equal panels PER OPEN BAY (three by default; identity can override) -----
    -- They were three panels spread across BOTH bays, so they straddled the middle post and came
    -- out uneven — one wide, one narrow. A noren belongs to its own doorway: each opening gets its
    -- own set of three, sized to that bay, so the panels are identical and the post between them
    -- reads as a post rather than as a seam.
    -- EACH PANEL IS A CHAIN, NOT A BOARD. One rigid rectangle per panel reads as painted plywood
    -- no matter what material it wears — cloth is recognised by its BEND. So a panel is three
    -- stacked segments hung end to end from the head rail, each tilting a little further out than
    -- the one above, and the whole chain is what NorenSway.client.luau then animates. The rest
    -- pose below is the still-air pose, and it is the ONLY place the hang is described: the
    -- client reads the segments' own angles at startup and adds its wave on top, so there is no
    -- second copy of these numbers to go stale.
    local NOREN_TOP = HEAD_Y
    local NOREN_H = 2.6
    local NOREN_PER_BAY = 3
    local NOREN_SEGS = 3
    -- 0.05 IS THE FLOOR — Roblox refuses a Part thinner than that on any axis, so this is as close
    -- to cloth-thick as boxed geometry gets. The remaining "it still looks solid" is answered by
    -- the transparency below, not by more thinness.
    local NOREN_T = 0.05
    -- ROBLOX'S SCALE: 0 is solid, 1 is invisible. Worth stating because it is the opposite of how
    -- the number gets read out loud — "25% transparency" sounds like a quarter as SOLID, and on
    -- that reading every increase looks like a request for more body when it delivers less. This
    -- ran 0.25 -> 0.5 -> 0.75 in the wrong direction before the units were caught.
    --
    -- A tenth: cotton, hung in a doorway, with just enough light coming through to say it is
    -- cloth and not a painted board. Noren SCREEN a shopfront; that is the job.
    local NOREN_ALPHA = 0.1
    -- Total lean from vertical at the hem. Small: a noren hangs, it does not billow. NEGATIVE
    -- leans the hem toward +Z — back under the eave, INTO the shop.
    --
    -- THE PROMENADE RULE, stated precisely (owner's round-4 clarification): the promenade
    -- excludes BUILDINGS; signage may stand on it — the nobori does, out front, and this
    -- hang was once justified by an over-read of that rule ("inviolable at ground level").
    -- The inward lean is RETAINED anyway, for its own reasons: it is the pose every
    -- accepted shop shipped with, and moving it moves every model.json byte gate — not
    -- because a hem a hair over the frontage line would be forbidden.
    local NOREN_BELLY = -3.6
    -- GENERALIZED FOR THE IDENTITY KIT (Task 3): the colour and the segment count are the
    -- caller's; the hang itself — per-bay panels, the chain, the still-air pose — stays the
    -- archetype's. Only meaningful over an OPEN frontage: a kōshi frontage has no doorway to
    -- screen, and its postX/CLOSED are empty, so this emits nothing there by construction.
    -- perBay is a PER-SHOP opt-in (identity.noren.perBay, round-1 accessories gate:
    -- two wider panels per doorway). It DEFAULTS to NOREN_PER_BAY so 花火屋's inline
    -- call and every non-opting identity stay byte-for-byte unchanged — the
    -- model.json snapshot gates hold that. The width formula below widens the
    -- panels automatically at a lower count; the 0.16 slit between panels is the
    -- constant the whole row shares.
    -- monChar (round 3, owner's ruling): ONE 丸に文字 crest per doorway, riding
    -- the cloth on the SECOND segment from the top — the upper-middle of the
    -- hang, where a real noren carries its crest, and squarely on a
    -- NorenSway-animated part so the sway carries the mon. Odd panel counts
    -- centre it on the middle panel; with an EVEN count the doorway's true
    -- centre is the slit, so the crest rides the panel nearest the frontage's
    -- CENTRAL post (owner, round 4): across the two open bays the pair then
    -- FLANKS that post, reading as a matched set. See monFace above for why it
    -- must be the segment's own SurfaceGui rather than a part in front of the
    -- cloth.
    local function emitNoren(norenColour: { number }, nSegs: number, perBay: number?, monChar: string?)
        if shop.frontage ~= "open" then
            return
        end
        local nPanels = perBay or NOREN_PER_BAY
        local segH = NOREN_H / nSegs
        local centrePostIdx = math.ceil(FRONT_POSTS / 2)
        for i = 1, FRONT_POSTS - 1 do
            if not CLOSED[i] then
                local a, b = postX[i], postX[i + 1]
                local openW = (b - a) - POST_W
                local panelW = openW / nPanels - 0.16
                -- this bay's crest panel: the middle one, or (even counts) the
                -- one nearest the central post — bays west of it take their east
                -- panel, bays east of it their west panel
                local monPanel = if nPanels % 2 == 1
                    then math.ceil(nPanels / 2)
                    elseif i < centrePostIdx then nPanels
                    else 1
                for k = 1, nPanels do
                    local t = (k - 0.5) / nPanels
                    local px = a + POST_W / 2 + openW * t
                    -- Hang the chain: start at the rail and walk down, each segment's top sitting on
                    -- the one above so the panel stays joined however far it leans.
                    local hy, hz = NOREN_TOP, Z0 + 0.06
                    local segs = {}
                    for s = 1, nSegs do
                        -- Deterministic, integer-derived variation — no trig on a hash, so the asset
                        -- hashes identically on arm64 and x86_64 (the CI drift check depends on it).
                        local lean = NOREN_BELLY * (s / nSegs) + ((i * 3 + k) % 3 - 1) * 0.35
                        local lr = math.rad(lean)
                        local dy, dz = math.cos(lr) * segH, -math.sin(lr) * segH
                        table.insert(
                            segs,
                            Spec.part(`Seg{s}`, {
                                Size = { panelW, segH, NOREN_T },
                                CFrame = Spec.cframe({ px, hy - dy / 2, hz + dz / 2 }, rotX(lean)),
                                children = if monChar
                                        and k == monPanel
                                        and s == 2
                                    then { monFace(monChar, panelW, segH) }
                                    else nil,
                                Color = norenColour,
                                Material = "Fabric",
                                -- Bare Fabric renders at Roblox's own tile scale, which on a panel
                                -- this small is a weave the size of a fist. NorenCloth is the same
                                -- pitch problem MachiyaPlaster solved for the render, and it fails
                                -- SOFT: a place without the variant just shows plain Fabric.
                                MaterialVariant = "NorenCloth",
                                Transparency = NOREN_ALPHA,
                                Tags = { "NorenSeg" },
                                CanCollide = false,
                                CanQuery = false,
                                CanTouch = false,
                                CastShadow = false,
                            })
                        )
                        hy, hz = hy - dy, hz + dz
                    end
                    table.insert(children, Spec.model(`Noren{i}_{k}`, segs))
                end
            end
        end
    end
    -- ----- the rear doorway's noren (identity.rearDoor.noren) -----
    -- The same construction as the frontage hang — per-doorway panels, each a CHAIN of segments
    -- (cloth is recognised by its bend), the 0.16 slit, the still-air pose the client reads back —
    -- MIRRORED IN Z and hung on the VESTIBULE side of the rear opening: the frontage hem walks +Z
    -- (back under the eave, into the shop); this hem walks −Z (into the vestibule, away from the
    -- wall the tunnel bore will meet), so the walk and the rotation are both negated together and
    -- the chain stays joined by the same arithmetic. Tagged NorenSeg like the frontage panels:
    -- NorenSway.client.luau groups by PARENT model and rebuilds with yaw 0, which these panels
    -- satisfy (±z-facing, rotX only — a test pins the top row at {1,0,0}).
    local function emitRearNoren(rd: any)
        local nPanels = rd.noren.panels or NOREN_PER_BAY
        local nSegs = rd.noren.segments or NOREN_SEGS
        local segH = NOREN_H / nSegs
        local panelW = rd.width / nPanels - 0.16
        -- just off the wall's INNER face, the frontage's own 0.06 standoff mirrored
        local hangZ = (SZ1 - WALL_T) - 0.06
        for k = 1, nPanels do
            local px = (CX - rd.width / 2) + rd.width * (k - 0.5) / nPanels
            local hy, hz = NOREN_TOP, hangZ
            local segs = {}
            for s = 1, nSegs do
                -- the frontage's own lean and jitter (bay index 0 — this doorway is not a bay)
                local lean = NOREN_BELLY * (s / nSegs) + (k % 3 - 1) * 0.35
                local lr = math.rad(lean)
                -- dz = +sin (the frontage's −sin, mirrored): a negative lean walks −Z here
                local dy, dz = math.cos(lr) * segH, math.sin(lr) * segH
                table.insert(
                    segs,
                    Spec.part(`Seg{s}`, {
                        Size = { panelW, segH, NOREN_T },
                        CFrame = Spec.cframe({ px, hy - dy / 2, hz + dz / 2 }, rotX(-lean)),
                        Color = rd.noren.color,
                        Material = "Fabric",
                        MaterialVariant = "NorenCloth",
                        Transparency = NOREN_ALPHA,
                        Tags = { "NorenSeg" },
                        CanCollide = false,
                        CanQuery = false,
                        CanTouch = false,
                        CastShadow = false,
                    })
                )
                hy, hz = hy - dy, hz + dz
            end
            table.insert(children, Spec.model(`RearNoren_{k}`, segs))
        end
    end

    -- 花火屋's IDENTITY STAYS INLINE (Task 3 brief): the vermilion three-segment noren, the
    -- counter and the kanban below belong to the firework shop's own full-interior build, not
    -- to the kit — variant shells get theirs through shop.identity instead.
    if shop.interior == "full" then
        -- 丸に花 — the firework shop's own crest, the first kanji of its name,
        -- inline like the rest of its identity (owner's round-3 ruling)
        emitNoren(palette.vermilion, NOREN_SEGS, nil, "花")
    end

    -- ----- the counter -----
    -- FULL INTERIORS ONLY: the counter is shop furniture, and it registers to the open bays —
    -- a shallow or empty shell has neither the trade nor (under a kōshi frontage) the bays.
    if shop.interior == "full" then
        add(
            "Counter",
            -- Spans only the OPEN bays now that the outer two are closed, and stands at the BACK of
            -- the shop so the goods are behind it rather than on the street.
            --
            -- MEASURED FROM Z1, NOT Z0. It used to sit at Z0 + 4.6, which was the same place while the
            -- shop was 8 deep and became a counter marooned in the middle of the street the moment the
            -- frontage moved north. The counter belongs to the back wall; the customers get the rest.
            { OPEN_X1 - OPEN_X0 - POST_W, COUNTER_H, COUNTER_D },
            { (OPEN_X0 + OPEN_X1) / 2, FLOOR + COUNTER_H / 2, COUNTER_Z },
            timber,
            "Wood",
            nil,
            FRAME_VAR
        )

        -- ----- the sign: ONE FRAMED BOARD (inline identity — still inside the full-interior gate) -----
        -- Three separate boards were a workaround for a bug: the glyphs were tiny because SizingMode
        -- was ignoring PixelsPerStud, and splitting them was the only way to make each one big enough
        -- to read. With the canvas fixed they no longer need to be split, so the sign is one board
        -- again — dark ink on a light ground in a plain timber frame, which is what a kanban is.
        -- Sized to the CHARACTERS, not to the building. At 0.62 of the frontage the board was half
        -- empty and the name floated in the middle of it. Three glyphs on a 2.6-stud board want about
        -- 3:1 — the text then fills ~86% of the canvas instead of 60%.
        local SIGN_H = 2.6
        local SIGN_W = SIGN_H * 3.0
        local SIGN_Y = FLOOR + STOREY_H + UPPER_H / 2
        local SIGN_Z = Z0 - 0.65 -- owner's gate: half a stud further out, so it reads off the facade
        local FRAME_W = 0.32 -- the surround's member width
        local FRAME_D = 0.34 -- deeper than the panel, so the frame stands proud of it

        -- TILTED 15 DEGREES, TOP TOWARD THE PATH (owner's gate). A sign flat against the facade is
        -- read edge-on by anyone standing under it; leaning the top out turns its face toward the
        -- promenade below. By the rotX sign convention, tipping the TOP toward -Z (north, the street)
        -- is a NEGATIVE angle.
        local SIGN_TILT = -15
        local ST = rotX(SIGN_TILT)
        -- offsets in the board's own plane, rotated with it, so the frame stays on the board
        local function signPos(dx: number, dy: number): { number }
            return { CX + dx, SIGN_Y + ST[5] * dy, SIGN_Z + ST[8] * dy }
        end

        table.insert(
            children,
            Spec.part("Kanban", {
                Size = { SIGN_W, SIGN_H, 0.11 }, -- owner's gate: half the first pass
                CFrame = Spec.cframe({ CX, SIGN_Y, SIGN_Z }, ST),
                -- A WHITE BOARD IN A DARK FRAME, as the reference shows. "The darker wood" meant the
                -- SURROUND; I applied it to the backing as well and lost the sign. The board is
                -- plaster and the letters are ink; only the frame is timber.
                Color = paper,
                Material = STUCCO_MAT,
                MaterialVariant = STUCCO_VAR,
                CanCollide = false,
                CanQuery = false,
                CanTouch = false,
                CastShadow = false,
                children = {
                    -- PER-CHARACTER (owner's gate, 2026-08-15: "slightly more spacing").
                    -- Same canvas configuration as the single label it replaces —
                    -- Face = Front (-Z, north: onto the promenade), PixelsPerStud 32,
                    -- TextSize 72, dark ink on the white board — but each kanji is
                    -- centred in its own third of the board, which opens the packed
                    -- fallback run to a 2.6-stud advance. See kanjiFace above.
                    kanjiFace("Face", "花火屋", "Front", ink, 72, 32, false),
                },
            })
        )

        -- The surround: four plain members, mitre-free, lapped at the corners the way a cheap shop
        -- sign is actually made.
        for _, m in
            {
                { "KanbanFrameTop", SIGN_W + 2 * FRAME_W, FRAME_W, 0, SIGN_H / 2 + FRAME_W / 2 },
                { "KanbanFrameBottom", SIGN_W + 2 * FRAME_W, FRAME_W, 0, -(SIGN_H / 2 + FRAME_W / 2) },
                { "KanbanFrameWest", FRAME_W, SIGN_H, -(SIGN_W / 2 + FRAME_W / 2), 0 },
                { "KanbanFrameEast", FRAME_W, SIGN_H, SIGN_W / 2 + FRAME_W / 2, 0 },
            }
        do
            add(
                m[1] :: string,
                { m[2] :: number, m[3] :: number, FRAME_D },
                signPos(m[4] :: number, m[5] :: number),
                timber,
                "Wood",
                ST,
                FRAME_VAR
            )
        end
    end -- interior == "full": counter + kanban (花火屋's inline identity) end here

    -- ----- the trigger volume -----
    -- Inset one stud from the frontage. See ShopThreshold.FRONT_INSET for why: flush with the
    -- frontage it would fire on everyone crossing the square.
    local tz0 = Z0 + 1
    -- TALL ENOUGH THAT A JUMP CANNOT LEAVE IT. The test is against the HumanoidRootPart, which
    -- stands ~3 studs above the floor and rises ~7 more at the apex of a default jump — so a box
    -- only storey-high (it was 4.9) lets the panel blink off mid-air while the player never left
    -- the shop. 14 puts the ceiling ~4 studs clear of that apex. It costs nothing to be generous:
    -- this is a trigger volume, invisible and non-colliding, so its height is not geometry and
    -- rising past the eave line is not a visual fact anyone can see.
    local TH_H = 14
    table.insert(
        children,
        Spec.part("Threshold", {
            Size = { W, TH_H, Z1 - tz0 },
            CFrame = Spec.cframe({ CX, FLOOR + TH_H / 2, (tz0 + Z1) / 2 }),
            Transparency = 1,
            CanCollide = false,
            CanQuery = false,
            CanTouch = false,
            CastShadow = false,
        })
    )

    -- ===== the identity kit (Task 3) =====
    -- shop.identity is OPTIONAL and so is every field inside it — 花火屋 passes nil and must
    -- emit exactly what it always did (the byte gate on assets/Hanabiya.model.json holds that).
    -- This is the contract Tasks 4–6 dress their shells through.
    local identity = shop.identity
    if identity then
        if identity.noren then
            -- the archetype's own hang, in the shop's colour — and its mon, if named
            emitNoren(
                identity.noren.color,
                identity.noren.segments or 3,
                identity.noren.perBay,
                identity.noren.mon
            )
        end
        if identity.rearDoor and identity.rearDoor.noren then
            -- the rear doorway's own hang — the wall itself opened back in the walls section
            emitRearNoren(identity.rearDoor)
        end
        if identity.chochin then
            -- THE EAVE-CORNER PAIR, 花火屋's pattern — built by tools/builders/Chochin, the
            -- module reproducing tools/studio/buildHanabiyaChochin.luau (the owner-gated Studio
            -- tool, LS 0.65/0.9) at full fidelity. This branch does not restate the lantern
            -- recipe; it only works out WHERE to hang two of them (the eave's outside corners)
            -- and hands that off to Chochin.build. One recipe, not a redrawn lookalike.
            --
            -- identity.chochin is `true` (canonical cream, the shop asks for nothing special)
            -- OR a table `{ paper = {r, g, b} }` (0-255, same units as the Studio tool's PAPER
            -- literal) tinting the paper barrel only — never the glyph plate, which stays
            -- untinted so the World Throw glyph keeps its contrast (owner's merchant-row rule:
            -- paths/canyon-wide lanterns stay uniform; the row varies, shops advertise
            -- themselves). Chochin.build defaults to canonical cream when this is nil.
            local paperRGB255 = if type(identity.chochin) == "table" then identity.chochin.paper else nil
            local HOOK_DROP = Chochin.HOOK_DROP
            local CORNER_INSET = 0.35 -- back from the eave's edge, so they hang under it
            local hangZ = (Z0 - EAVE_OVERHANG) + CORNER_INSET
            -- The eave is a TILTED slab, so its underside is a plane, not a number: the mid-plane
            -- drops HISASHI_DROP over EAVE_OVERHANG, and the vertical half-thickness of a tilted
            -- slab is (t/2) / cos(pitch) = (t/2) * hisashiLen / EAVE_OVERHANG — sqrt, not trig.
            local midY = FLOOR + STOREY_H - HISASHI_DROP * (Z0 - hangZ) / EAVE_OVERHANG
            local armY = midY - (EAVE_T / 2) * (hisashiLen / EAVE_OVERHANG) - HOOK_DROP
            -- The owner ruled the corner hang MAY be low ("it's okay if they're low"): this
            -- catches a lantern at chest height, not one you merely duck under.
            local hemY = Chochin.hemY(armY)
            assert(hemY - FLOOR >= 5.0, `chōchin hem {hemY} sits under 5 studs off the floor`)
            local eaveHalfX = (W + 1.0) / 2 -- the Eave part's own extents, not the wall's
            -- ⚠ THE X INSET IS ITS OWN NUMBER, deliberately larger than the Z one. CORNER_INSET
            -- sets how far back under the eave a lantern hangs (a depth); this sets how far in
            -- from the eave's END it sits (a width), and the owner widened it half a stud on
            -- 2026-09-06 for a reason the depth does not share: adjacent shops sit only 1.5 studs
            -- apart across the roji, so two lanterns on two DIFFERENT buildings were hanging
            -- closer to each other than either sat from its own corner. Half a stud each way puts
            -- a stud of air between neighbours. Changing CORNER_INSET instead would have dragged
            -- every lantern backwards under its eave as well, which is not what was asked.
            local CORNER_INSET_X = CORNER_INSET + 0.5
            -- corners (stats, 2026-08-15): "west" | "east" hangs ONE lantern at that
            -- corner instead of the pair. The stats front's east corner sits on the 1.5
            -- roji, where a barrel would truly intersect apparel's own west lantern —
            -- the two shops share z0 AND floorY, so the pair would hang at identical
            -- y/z just 1.2 apart against 1.3 studs of summed barrel radii. nil keeps
            -- the pair, byte-identically, for every shop that doesn't opt in.
            local corners: string? = if type(identity.chochin) == "table"
                then identity.chochin.corners
                else nil
            for _, corner in
                { { "West", CX - eaveHalfX + CORNER_INSET_X }, { "East", CX + eaveHalfX - CORNER_INSET_X } }
            do
                local cnm, lx = corner[1] :: string, corner[2] :: number
                if corners == nil or string.lower(cnm) == corners then
                    table.insert(children, Chochin.build(cnm, lx, hangZ, armY, paperRGB255))
                end
            end
        end
        if identity.board then
            -- ===== the sign (owner's signage pass, 2026-08-15) =====
            -- `board = true` is the ORIGINAL contract and still means one blank framed
            -- wall kanban, emitted byte-identically (the sports book carries no signage
            -- copy — the wager-language ruling). A TABLE opts a shop into a sign TYPE:
            -- the owner's finding at this round's gate was that the row read as three
            -- copies of the same board, and the fix is different SILHOUETTES, not
            -- different colours —
            --   kind = "wall"    — 板看板: the framed board on the upper storey (default)
            --   kind = "nobori"  — 幟: a cloth banner on a pole at the shop mouth,
            --                      lettered down its length — reads down the promenade
            --                      where every wall board is edge-on. (It replaced a
            --                      袖看板 blade at the round-3 gate: a high
            --                      perpendicular blade is Shōwa, not Edo/Meiji, and
            --                      the rejected kind was deleted, not kept.)
            --   kind = "hanging" — 掛看板: a plaque hung under the eave on visible hooks
            -- text letters it (per-character, kanjiFace above; nil stays blank);
            -- panel/ink restyle the board and its characters, defaulting to the wall
            -- board's own cream plaster and sumi.
            local b: any = identity.board
            local kind: string = if type(b) == "table" then b.kind or "wall" else "wall"
            local bText: string? = if type(b) == "table" then b.text else nil
            local panelColor: { number } = if type(b) == "table" and b.panel then b.panel.color else paper
            local panelMat: string = if type(b) == "table"
                    and b.panel
                    and b.panel.material
                then b.panel.material
                else STUCCO_MAT
            local panelVar: string? = if type(b) == "table" and b.panel then b.panel.variant else STUCCO_VAR
            local inkColor: { number } = if type(b) == "table" and b.ink then b.ink.color else ink

            if kind == "wall" then
                -- THE FRAMED WALL KANBAN, ON THE UPPER STOREY (owner's finding,
                -- accessories gate): the kit's first board was a frameless slab at the
                -- kamoi line whose whole z-span fell INSIDE the Eave's — the eave
                -- covered its top and shaded the rest, a cream slab under a cream
                -- soffit. The archetype's own header says where a machiya's sign goes
                -- ("a closed upper storey of kōshi lattice carrying the sign high
                -- enough to read from the bridge"), and 花火屋's inline kanban already
                -- sits there. This is that construction, generalized:
                --   panel: 花火屋's 2.6 height and 0.11 thickness; WIDTH sized to the
                --     FRONTAGE at 花火屋's own ratio (its 7.8 panel on its 17.93-wide
                --     envelope) — the inline sign is sized to its three characters instead;
                --   y: centred on the shop's own mushiko-mado band (derived from the
                --     band, which is itself centred on the upper storey);
                --   z: proud of the upper wall's front face (SZ0) by 花火屋's own standoff
                --     — its sign centre hangs at Z0 - 0.65 against a face at Z0 + 0.30,
                --     i.e. 0.95 proud (derived, not copied blind);
                --   tilt: 花火屋's -15°, top toward the path, so anyone on the promenade
                --     reads the face and not the edge;
                --   frame: the same four lapped members, 0.32 section, 0.34 deep so the
                --     surround stands proud of the panel.
                local SIGN_H = 2.6
                local SIGN_W = W * (7.8 / 17.93)
                local SIGN_Y = WIN_Y0 + WIN_H / 2
                local SIGN_Z = SZ0 - 0.95
                local FRAME_W = 0.32
                local FRAME_D = 0.34
                local ST = rotX(-15)
                -- offsets in the board's own plane, rotated with it, so the frame stays on
                -- the board — 花火屋's signPos, restated against this shop's centre
                local function kanbanPos(dx: number, dy: number): { number }
                    return { CX + dx, SIGN_Y + ST[5] * dy, SIGN_Z + ST[8] * dy }
                end
                table.insert(
                    children,
                    Spec.part("Kanban", {
                        Size = { SIGN_W, SIGN_H, 0.11 },
                        CFrame = Spec.cframe({ CX, SIGN_Y, SIGN_Z }, ST),
                        Color = panelColor,
                        Material = panelMat,
                        MaterialVariant = panelVar,
                        CanCollide = false,
                        CanQuery = false,
                        CanTouch = false,
                        CastShadow = false,
                        children = if bText
                            then { kanjiFace("Face", bText, "Front", inkColor, 72, 32, false) }
                            else nil,
                    })
                )
                for _, mfr in
                    {
                        { "KanbanFrameTop", SIGN_W + 2 * FRAME_W, FRAME_W, 0, SIGN_H / 2 + FRAME_W / 2 },
                        {
                            "KanbanFrameBottom",
                            SIGN_W + 2 * FRAME_W,
                            FRAME_W,
                            0,
                            -(SIGN_H / 2 + FRAME_W / 2),
                        },
                        { "KanbanFrameWest", FRAME_W, SIGN_H, -(SIGN_W / 2 + FRAME_W / 2), 0 },
                        { "KanbanFrameEast", FRAME_W, SIGN_H, SIGN_W / 2 + FRAME_W / 2, 0 },
                    }
                do
                    add(
                        mfr[1] :: string,
                        { mfr[2] :: number, mfr[3] :: number, FRAME_D },
                        kanbanPos(mfr[4] :: number, mfr[5] :: number),
                        timber,
                        "Wood",
                        ST,
                        FRAME_VAR
                    )
                end
            elseif kind == "nobori" then
                -- 幟: a tall cloth banner on a pole at the shop mouth, the name
                -- running down it. This REPLACED the sode-kanban blade at the round-3
                -- gate: a perpendicular blade mounted high reads Shōwa, not Edo/Meiji —
                -- period signage sat at human level and the tsushi-nikai was
                -- deliberately not display space. The banner does the blade's
                -- read-down-the-promenade job (faces east/west), and a cloth merchant
                -- advertising with cloth is thematically right. The blade branch was
                -- DELETED, not stranded: the owner ruled the type an anachronism for
                -- this world, so the kit must not keep offering it.
                --
                -- SITING (owner's round-4 rule clarification, verbatim: the promenade
                -- "isn't exactly 'inviolable' when it comes to e.g. signage. It's
                -- simply not someplace we want to place buildings. The sign can't
                -- really be seen inside the shop, so let's get it out front."). So the
                -- banner stands OUT FRONT, on the promenade — flanking the shopfront
                -- at its END (default west, in front of the CLOSED end bay, so it
                -- blocks neither doorway) and BEYOND the eave's drip line, never under
                -- the soffit: a sign tucked under an overhang was the first kanban's
                -- exact defect. Freed from the kamoi/transom ceiling it stood under
                -- indoors, the banner takes a real nobori's height.
                assert(
                    shop.frontage == "open",
                    "a nobori flanks a shopfront's end bay: it needs the open frontage"
                )
                local POLE_R = 0.09
                local POLE_H = 9.2
                local BAR_R = 0.06
                local CLOTH_W = 1.2 -- along z, hanging from the bar
                local CLOTH_H = 5.2 -- ~4.3:1, a nobori's proportions; hem ~3 off the ground
                local CLOTH_T = 0.05 -- Roblox's minimum, same as the noren
                -- one segment PER CHARACTER: the chain is the cloth's bend, and the
                -- characters ride the segments, bending with it
                local chars: { string } = {}
                if bText then
                    for _, code in utf8.codes(bText :: string) do
                        table.insert(chars, utf8.char(code))
                    end
                end
                local nSegs = math.max(#chars, 3)
                local segH = CLOTH_H / nSegs
                -- x: 1.5 in from the frontage's corner (default the west end;
                -- b.side = "east" mirrors it) — in front of the closed end bay, clear
                -- of both doorways, and a full stud inside the eave-corner chōchin's
                -- barrel in x, so nothing hangs over the banner
                local sideSign: number = if type(b) == "table" and b.side == "east" then 1 else -1
                local px = (if sideSign < 0 then X0 else X1) - sideSign * 1.5
                -- z: BEYOND the drip line (Z0 - EAVE_OVERHANG), with air — nothing of
                -- the building may stand over the banner. The pole is the rig's
                -- southmost element, planted 0.43 clear of the drip; the bar and cloth
                -- run NORTH from it, out over the promenade, so the whole rig's
                -- z-extent tops out at the base's south face, 0.21 short of the drip.
                local pz = Z0 - EAVE_OVERHANG - 0.43
                assert(
                    pz + 0.25 <= Z0 - EAVE_OVERHANG - 0.15,
                    `nobori base {pz + 0.25} crowds the eave's drip line {Z0 - EAVE_OVERHANG}`
                )
                local kids: { any } = {}
                table.insert(
                    kids,
                    Spec.part("NoboriBase", {
                        -- bottom a tenth of a stud below the shop's FLOOR datum: the
                        -- stand sits on the promenade's terrain, which the survey
                        -- probed at exactly floorY on this shop's NW front corner
                        -- (the nearest probe to this site); the bury absorbs local
                        -- grade variance instead of floating on it
                        Size = { 0.5, 0.35, 0.5 },
                        CFrame = Spec.cframe({ px, FLOOR + 0.075, pz }),
                        Color = timber,
                        Material = "Wood",
                        MaterialVariant = FRAME_VAR,
                    })
                )
                table.insert(
                    kids,
                    Spec.part("NoboriPole", {
                        Shape = "Cylinder",
                        Size = { POLE_H, 2 * POLE_R, 2 * POLE_R },
                        CFrame = Spec.cframe({ px, FLOOR + POLE_H / 2, pz }, Spec.ROT.CYL_VERTICAL),
                        Color = timber,
                        Material = "Wood",
                        MaterialVariant = "CypressVertical",
                    })
                )
                -- the yokobō: the horizontal top bar a nobori actually hangs from,
                -- running NORTH from the pole (out over the promenade, away from the
                -- building), the pole tip standing proud above it the way a real
                -- nobori pole does
                local BAR_L = 0.3 + CLOTH_W + 0.15
                local barY = FLOOR + POLE_H - 0.85 -- the tip stands proud above the bar
                table.insert(
                    kids,
                    Spec.part("NoboriBar", {
                        Shape = "Cylinder",
                        Size = { BAR_L, 2 * BAR_R, 2 * BAR_R },
                        CFrame = Spec.cframe({ px, barY, pz + BAR_R - BAR_L / 2 }, Spec.ROT.CYL_ALONG_Z),
                        Color = timber,
                        Material = "Wood",
                        MaterialVariant = "CypressWeathered",
                        CanCollide = false,
                        CanQuery = false,
                        CanTouch = false,
                        CastShadow = false,
                    })
                )
                -- the cloth: hung from the bar's underside, drifting gently toward
                -- the shop's centre (away from the corner and the eave-corner chōchin
                -- that hangs there) so it reads as cloth. Still-air pose only:
                -- NorenSway rebuilds tagged segments as
                -- CFrame.Angles(rx, 0, rz) from the X-euler alone — it assumes yaw-0
                -- street-facing panels, and these face east/west and lean about Z, so
                -- adopting it means teaching the client script to preserve yaw: a
                -- client-script change, which is its own gate. Tagging them today
                -- would snap the cloth flat on the first frame. So: UNTAGGED.
                local NOBORI_DRIFT = -2.5 * sideSign -- total lean at the hem, toward the shop's centre
                local clothColor: { number } = if type(b) == "table" and b.panel
                    then b.panel.color
                    elseif identity.noren then identity.noren.color
                    else paper
                local clothInk: { number } = if type(b) == "table" and b.ink then b.ink.color else SHIRO
                local clothZ = pz - 0.15 - CLOTH_W / 2
                local function rotZ(deg: number): { number }
                    local r = math.rad(deg)
                    local c, sn = math.cos(r), math.sin(r)
                    return { c, -sn, 0, sn, c, 0, 0, 0, 1 }
                end
                local hx, hy = px, barY - BAR_R
                local joints: { { number } } = {} -- chain joints, for the ties below
                for si = 1, nSegs do
                    local lean = NOBORI_DRIFT * (si / nSegs)
                    local lr = math.rad(lean)
                    local dy, dx = math.cos(lr) * segH, math.sin(lr) * segH
                    local ch = chars[si]
                    table.insert(
                        kids,
                        Spec.part(`Seg{si}`, {
                            Size = { CLOTH_T, segH, CLOTH_W },
                            CFrame = Spec.cframe({ hx + dx / 2, hy - dy / 2, clothZ }, rotZ(lean)),
                            Color = clothColor,
                            Material = "Fabric",
                            MaterialVariant = "NorenCloth",
                            Transparency = NOREN_ALPHA,
                            CanCollide = false,
                            CanQuery = false,
                            CanTouch = false,
                            CastShadow = false,
                            -- one character per segment, on BOTH faces: the banner
                            -- reads down the promenade from either direction
                            children = if ch
                                then {
                                    kanjiFace("FaceEast", ch, "Right", clothInk, 96, 64, false),
                                    kanjiFace("FaceWest", ch, "Left", clothInk, 96, 64, false),
                                }
                                else nil,
                        })
                    )
                    hx, hy = hx + dx, hy - dy
                    table.insert(joints, { hx, hy })
                end
                -- ring/tie attachments down the pole side, seated ON the chain's own
                -- joints so they follow the cloth's drift instead of pointing at
                -- where it used to be
                for ti, j in joints do
                    local jx, jy = j[1], j[2]
                    table.insert(
                        kids,
                        Spec.part(`NoboriTie{ti}`, {
                            Size = { math.abs(jx - px) + 0.12, 0.07, 0.18 },
                            CFrame = Spec.cframe({ (jx + px) / 2, jy, pz - 0.12 }),
                            Color = ink,
                            Material = "Fabric",
                            CanCollide = false,
                            CanQuery = false,
                            CanTouch = false,
                            CastShadow = false,
                        })
                    )
                end
                table.insert(children, Spec.model("Nobori", kids))
            else
                -- 掛看板: a plaque hung under the hisashi on two VISIBLE hooks, over the
                -- doorway. Under the eave is where a kake-kanban lives — it reads by
                -- silhouette and proximity, not from across the square — so the
                -- wall-board occlusion guard inverts here: BELOW the eave with real
                -- air, and above head height.
                local PLAQUE_W, PLAQUE_H, PLAQUE_T = 4.4, 1.3, 0.15
                local HOOK_T = 0.12
                local HOOK_LEN = 0.4 -- eave underside to plaque top: the visible hang
                local pz = Z0 - 1.0
                -- the eave's underside is a tilted PLANE: the mid-plane springs at
                -- FLOOR + STOREY_H and drops HISASHI_DROP over EAVE_OVERHANG, minus the
                -- slab's vertical half-thickness — the chōchin hang's own math
                local undersideY = FLOOR
                    + STOREY_H
                    - HISASHI_DROP * (Z0 - pz) / EAVE_OVERHANG
                    - (EAVE_T / 2) * (hisashiLen / EAVE_OVERHANG)
                local plaqueTop = undersideY - HOOK_LEN
                local plaqueBot = plaqueTop - PLAQUE_H
                -- head height: the kamoi's own 6.8, the number every doorway clears
                assert(plaqueBot >= FLOOR + 6.8, `hanging plaque underside {plaqueBot} is below head height`)
                -- and REAL air below even the eave's lowest (outer) corner, so the
                -- plaque never reads as part of the soffit — the occlusion-guard
                -- defect class, restated for a sign that belongs under the eave
                local eaveLoY = (FLOOR + STOREY_H - HISASHI_DROP / 2)
                    - (HISASHI_DROP + EAVE_T * (EAVE_OVERHANG / hisashiLen)) / 2
                assert(plaqueTop <= eaveLoY - 0.05, `hanging plaque top {plaqueTop} crowds the eave`)
                local kids: { any } = {
                    Spec.part("Plaque", {
                        Size = { PLAQUE_W, PLAQUE_H, PLAQUE_T },
                        CFrame = Spec.cframe({ CX, (plaqueTop + plaqueBot) / 2, pz }),
                        Color = panelColor,
                        Material = panelMat,
                        MaterialVariant = panelVar,
                        CanCollide = false,
                        CanQuery = false,
                        CanTouch = false,
                        CastShadow = false,
                        children = if bText
                            then { kanjiFace("Face", bText, "Front", inkColor, 76, 64, false) }
                            else nil,
                    }),
                }
                -- the hooks: 0.5 in from the plaque's ends, spanning plaque top to the
                -- underside plane exactly — attached, never buried (the audit holds
                -- the plaque itself strictly clear; the hooks ARE the contact)
                for _, hook in { { "PlaqueHookWest", -1 }, { "PlaqueHookEast", 1 } } do
                    table.insert(
                        kids,
                        Spec.part(hook[1] :: string, {
                            Size = { HOOK_T, HOOK_LEN, HOOK_T },
                            CFrame = Spec.cframe({
                                CX + (hook[2] :: number) * (PLAQUE_W / 2 - 0.5),
                                plaqueTop + HOOK_LEN / 2,
                                pz,
                            }),
                            Color = palette.ironDark,
                            Material = "Metal",
                            CanCollide = false,
                            CanQuery = false,
                            CanTouch = false,
                            CastShadow = false,
                        })
                    )
                end
                table.insert(children, Spec.model("KakeKanban", kids))
            end
        end

        if identity.glow and shop.interior ~= "none" then
            -- INTERIOR LIGHTING HOOKS: invisible anchored carriers, one PointLight each. An
            -- interior of "none" is a sealed shell and gets no hooks — that is the brief's
            -- ladder: none = shallow minus exactly these.
            for i, gx in { CX - W / 4, CX + W / 4 } do
                table.insert(
                    children,
                    Spec.part(`InteriorGlow_{i}`, {
                        Size = { 0.5, 0.5, 0.5 },
                        CFrame = Spec.cframe({ gx, FLOOR + STOREY_H * 0.6, CZ }),
                        Transparency = 1,
                        CanCollide = false,
                        CanQuery = false,
                        CanTouch = false,
                        CastShadow = false,
                        children = {
                            {
                                name = "Glow",
                                className = "PointLight",
                                properties = {
                                    Color = identity.glow.color,
                                    Brightness = identity.glow.brightness or 1.0,
                                    Range = 14,
                                    Shadows = false,
                                },
                            },
                        },
                    })
                )
            end
        end
        -- dress is called LAST of the kit so it sees a finished shell, and its parts land under
        -- their own child model — kit dressing never interleaves with the archetype's parts.
        if identity.dress then
            local ctx = {
                env = {
                    x0 = X0,
                    x1 = X1,
                    z0 = Z0,
                    z1 = Z1,
                    floorY = FLOOR,
                    w = W,
                    d = D,
                    cx = CX,
                    cz = CZ,
                },
                palette = palette,
                consts = { SLAB_T = SLAB_T, COUNTER_H = COUNTER_H, POST_W = POST_W, KOSHI_T = KOSHI_T },
            }
            table.insert(children, Spec.model("Dressing", identity.dress(ctx)))
        end
    end

    local root = Spec.model(shop.name, children)

    -- ===== the FINAL pass: yaw about the envelope centre =====
    -- EVERY part turns, including those nested inside child models — the noren panels are
    -- chains of segments in their own models, exactly the class of part a shallow walk misses
    -- (see Machiya.spec's allParts note). Positions go through Spec.rotY about (CX, CZ),
    -- rotations through Spec.rotYMat/matMul. yaw == 0 skips the pass entirely, so an unyawed
    -- shop's floats are byte-for-byte untouched (the Hanabiya snapshot gate depends on that).
    if shop.yaw ~= 0 then
        local function turn(node: any)
            local cf = node.properties and node.properties.CFrame
            if cf then
                local p = Spec.rotY({ cf[1] - CX, cf[2], cf[3] - CZ }, shop.yaw)
                local r = Spec.matMul(
                    Spec.rotYMat(shop.yaw),
                    { cf[4], cf[5], cf[6], cf[7], cf[8], cf[9], cf[10], cf[11], cf[12] }
                )
                node.properties.CFrame = {
                    p[1] + CX,
                    p[2],
                    p[3] + CZ,
                    r[1],
                    r[2],
                    r[3],
                    r[4],
                    r[5],
                    r[6],
                    r[7],
                    r[8],
                    r[9],
                }
            end
            for _, c in (node.children or {}) :: { any } do
                turn(c)
            end
        end
        turn(root)
    end

    return root
end

return Machiya
