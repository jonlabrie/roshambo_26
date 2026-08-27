### Task 4: The ring, built and driven

**Files:** Modify `roblox/src/client/HudController.client.luau`.

**Interfaces:** Consumes `RingTimer`, `HudModel.ESCALATE_AT`, `HudLayout.RING_*`, `Glyphs.render`,
`view.secondsLeft`, `aux.timerKnown`, and a new `aux.worldThrow` (see Step 4).

- [ ] **Step 1: Build the ring**

Between the plate and the tape in the bottom row. Require `RingTimer` beside the other shared
modules.

```luau
-- ===== The round-timer ring (spec §5) =====
-- The PWA's PieTimer, rebuilt. Roblox has no SVG and no radial fill, so the sweep is a ring of
-- discrete segments — RingTimer says how many are lit, this paints them. Green while there is
-- time, red at HudModel.ESCALATE_AT, which is the SAME constant the escalation prompt reads:
-- two signals about one fact must not turn urgent at different moments.
--
-- Everything here is Active = false. It is a readout.
local RING_D = if TOUCH then HudLayout.RING_D_TOUCH else HudLayout.RING_D
local RING_GAP = HudLayout.RING_GAP
local RING_THICKNESS = if TOUCH then HudLayout.RING_THICKNESS_TOUCH else HudLayout.RING_THICKNESS
local RING_R = RING_D / 2 - RING_THICKNESS / 2
local SEG_W = RingTimer.segmentWidth(RING_R, RingTimer.SEGMENTS)

-- A BUTTON, not a Frame: the ring is the ledger's door now (spec §6). The hamburger it replaces
-- is deleted in Task 5. Its segments and labels all stay Active = false; only this outer frame
-- sinks, which is the same interactive cost the hamburger carried, in the same row.
local ring = Instance.new("TextButton")
ring.Name = "RoundRing"
ring.AutoButtonColor = false
ring.Text = ""
ring.AnchorPoint = Vector2.new(1, 1)
ring.Position = UDim2.new(1 - JUMP_CLEARANCE, -(TAPE_W + RING_GAP), 1, -EDGE)
ring.Size = UDim2.fromOffset(RING_D, RING_D)
ring.BackgroundTransparency = 1
ring.Parent = gui

local segments: { Frame } = {}
for i = 1, RingTimer.SEGMENTS do
    local a = math.rad(RingTimer.angleAt(i, RingTimer.SEGMENTS))
    local seg = Instance.new("Frame")
    seg.Name = `S{i}`
    seg.AnchorPoint = Vector2.new(0.5, 0.5)
    -- Screen space: +x right, +y DOWN, so the top of the circle is -y and the sweep runs
    -- clockwise as the angle grows.
    seg.Position = UDim2.fromOffset(
        RING_D / 2 + RING_R * math.sin(a),
        RING_D / 2 - RING_R * math.cos(a)
    )
    seg.Size = UDim2.fromOffset(SEG_W, RING_THICKNESS)
    seg.Rotation = RingTimer.angleAt(i, RingTimer.SEGMENTS)
    seg.BorderSizePixel = 0
    seg.Parent = ring
    segments[i] = seg
end
```

Add `RING_TRACK = Color3.fromRGB(38, 36, 42)`, `RING_LIVE = Color3.fromRGB(76, 187, 106)` and
`RING_HOT` (reuse `LOSS_RED`) to the palette.

- [ ] **Step 1b: Move the plate left in the SAME commit**

The ring's slot is where the plate sits today (`-(TAPE_W + LEDGER_GAP)`). Leaving the plate there
until Task 5 would stack the two on top of each other for a whole task. Move it now:

```luau
plate.Position = UDim2.new(1 - JUMP_CLEARANCE, -(TAPE_W + RING_GAP + RING_D + RING_GAP), 1, -EDGE)
```

Task 5 changes its vertical anchor and makes it a button; only the horizontal moves here.

- [ ] **Step 2: The digits and the glyph**

A `TextLabel` centred in the ring for the seconds, and a glyph box for the world throw. Both
`Active = false`; **no `UIStroke` on the label** — the ring's centre is open canyon, so give the
digits their own small opaque disc backing rather than an outline.

```luau
local ringDisc = Instance.new("Frame") -- the backing the digits sit on
…
local ringCount = Instance.new("TextLabel")
…
local ringGlyph = Glyphs.render(glyphBox(ring, 0.52), "R", INK_CREAM)
```
Build one glyph box per symbol as `glyphSet` already does elsewhere in this file, so the reveal
can show whichever the world threw.

- [ ] **Step 3: Paint it in `render`**

```luau
    -- The ring, the hairline's replacement. `span` is already tracked for the old hairline;
    -- reuse it rather than deriving a second notion of the round's length.
    local known = inputs.phase == "ACTIVE" and aux.timerKnown ~= false and span > 0
    local frac = if known then math.clamp(view.secondsLeft / span, 0, 1) else 0
    local litCount = RingTimer.lit(frac, RingTimer.SEGMENTS)
    local hot = RingTimer.isWarning(view.secondsLeft, HudModel.ESCALATE_AT)
    for i, seg in segments do
        seg.BackgroundColor3 = if i <= litCount then (if hot then RING_HOT else RING_LIVE) else RING_TRACK
    end
    ringCount.Text = if known then tostring(math.ceil(view.secondsLeft)) else ""
    ringCount.TextColor3 = if hot then RING_HOT else INK_CREAM
```

**Where the countdown is unknown** (the unsynced-clock path, where `secondsLeft` is a constant),
`frac` is 0 so no segment is lit and the digits are blank — the ring shows the track only. A full
ring that never moved would read as "plenty of time" and be a lie, which is exactly why the
hairline hid itself in that case.

- [ ] **Step 4: The glyph swap, on the drum-rest gate**

The world throw appears in the ring's centre **only once the drum has settled**. `main.client.luau`
already gates the tape tile and the headline on the `drumRest` cue with a `REVEAL_SAFETY`
fallback; add the world throw to the same `aux` payload it publishes so this controller inherits
that gate rather than building a second one.

In `main.client.luau`'s `publish()`, add to `aux`:

```luau
        -- The world's throw for the round the drum has FINISHED revealing, or nil. Gated by the
        -- same `revealedRoundId` the tape is, so the ring cannot spoil the wheel mid-spin.
        worldThrow = revealedWorldThrow,
```
with `local revealedWorldThrow: string? = nil` set in `maybeShowReveal` alongside `revealedRoundId`,
and cleared when ACTIVE reopens.

In `render`, show the glyph and hide the digits when `aux.worldThrow` is set, and vice versa.

- [ ] **Step 4b: The ring inherits the hamburger's two-stage gesture**

Move the `ledgerButton`'s `MouseButton1Down` (press feedback) and `MouseButton1Click` handlers
onto `ring`, unchanged in behaviour: the first tap reveals the plate, and a tap while the plate is
still on screen — hold **or** fade — fires `EventBus.OpenLedger`. Read the existing handler and
port its `plateVisible` test rather than rewriting the rule.

Keep `ledgerButton` itself in place for now; Task 5 deletes it. Two doors briefly coexisting is
harmless, whereas a task that both adds and removes the door cannot be reviewed against either.

- [ ] **Step 5: Verify and commit**

Run the standing check. Additionally confirm: at `secondsLeft = span` every segment is lit; at 0
none is; and the bottom row's three occupants — plate, ring, tape — do not overlap. **State the
full horizontal arithmetic at both tiers**, since the plate moved in this same commit. Confirm the
ring's segments and labels are all `Active = false` and only the outer button sinks.

```bash
cd roblox && stylua src tests tools && selene src tools
git commit -am "feat(roblox): the round's clock is a ring, not a hairline"
```

---

