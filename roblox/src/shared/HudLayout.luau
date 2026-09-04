--!strict
-- The minimal HUD's layout skeleton — the handful of numbers MORE THAN ONE file has to agree on
-- exactly (spec: docs/superpowers/specs/2026-08-02-play-hud-design.md).
--
-- HudController places the plate, the tape+throw cluster and the bank button; OnboardingController has
-- to put cards BESIDE them without ever covering a live button, so it derives its safe band from the
-- same numbers. That derivation was hand-copied — `AREA_H = 120 -- TILE(34) + ROW_GAP(10) + BTN_H(76)`
-- — which means a later tweak to BTN_H would silently move the cluster while the onboarding clamp
-- went on believing the old height, and the safe band is the only thing standing between a card and
-- the BANK THESE button. One source, imported by both.
--
-- Numbers that only ONE file uses (BTN_W, TILE_GAP, the toast sizes, the plate's own
-- reveal/fade timing) stay local to that file — this module is for the shared skeleton, not for
-- every constant in the HUD. The round-timer ring is the exception among "timer" numbers: it
-- replaced the bottom hairline and its geometry has to agree with BTN_H, so it lives here too —
-- but it takes the hamburger's old slot beside the button row, not a slot in the tape's row.
--
-- No Roblox globals: plain numbers, and pure arithmetic over them, so it stays Lune-testable like
-- everything else in src/shared. This used to also hold `plateBottomOffset`, a function rather
-- than a bare constant, because the plate once sat above the jump button and had to measure it at
-- runtime. The owner moved the plate into the bottom row instead (2026-08-03, mid-execution) —
-- nothing in the HUD is positioned against geometry Roblox owns any more, and this module is back
-- to numbers only.
local HudLayout = {}

-- SCALE, not pixels: the jump button occupies roughly the right 3-13% of the screen, so the throw
-- area is held inboard by a fraction of the width rather than a pixel guess.
HudLayout.JUMP_CLEARANCE = 0.15

HudLayout.EDGE = 12 -- margin from every screen edge
HudLayout.TILE = 34 -- one World-Throw tape tile
HudLayout.ROW_GAP = 10 -- tape -> throw buttons, and cluster -> bank row
HudLayout.BTN_H = 76 -- one throw button

-- ===== The touch tier (gate 2026-08-02) =====
-- On a phone/tablet the throw cluster crowded the play space, so the owner asked for throw buttons
-- "50% smaller on a mobile device, and the previous round buttons smaller as well". The DETECTION
-- (`UserInputService.TouchEnabled and not KeyboardEnabled`) belongs to the controllers — this module
-- holds no Roblox globals — but the NUMBERS live here, because OnboardingController's safe band has
-- to shrink in lockstep with the cluster or a card lands on top of BANK THESE. Both files pick the
-- same variant from the same boolean.
--
-- The first pass took "50% smaller" literally (0.5 -> 38px) and flagged that it sits under the ~44px
-- touch-target floor both the Apple HIG and this programme's own touch-first brief call for. The
-- owner has since chosen ~44px, so the scale is 0.58: 76 * 0.58 = 44.08 -> 44px, and the cluster
-- width, the onboarding safe band and the confirm strip all re-derive from it. This is the ONE lever
-- for the throw target's size; nothing downstream carries a literal.
-- The tape is read, never touched, so no floor applies to it at all — it stays where the last pass
-- left it.
HudLayout.THROW_TOUCH_SCALE = 0.58
HudLayout.TAPE_TOUCH_SCALE = 0.7

HudLayout.BTN_H_TOUCH = math.round(HudLayout.BTN_H * HudLayout.THROW_TOUCH_SCALE)
HudLayout.TILE_TOUCH = math.round(HudLayout.TILE * HudLayout.TAPE_TOUCH_SCALE)

-- ===== The round-timer ring (spec §5) =====
-- Sized to a throw button because it sits BESIDE one — the ring takes the hamburger's slot,
-- inboard-left of the cluster and level with the button row, so BTN_H is both its natural size
-- and exactly the height of the row it joins. It is NOT in the tape's row, and nothing in the
-- cluster grows to accommodate it.
HudLayout.RING_D = HudLayout.BTN_H
HudLayout.RING_D_TOUCH = HudLayout.BTN_H_TOUCH

-- The ring's band width — the painted annulus between the pie's outer edge and the centre disc.
-- A literal per tier now, not a fraction of RING_D: the pie's inner edge is exact (the disc IS
-- that edge), so there is nothing left for a proportional stroke to approximate. Desktop steps
-- 6 -> 5 and the centre grows to match, per the owner's "the inner circle can grow to fill the
-- newly downsized ring" (spec §4).
HudLayout.RING_THICKNESS = 5
HudLayout.RING_THICKNESS_TOUCH = 3
HudLayout.RING_GAP = 8 -- ring <-> tape, and ring <-> plate

-- The bank button's row, directly above the throw cluster. Reserved whether or not a pot is
-- riding: an onboarding card clamped into a band that ignored it would land on the button the
-- moment a first win put one there.
--
-- 36, down from 40 (owner's gate 2026-08-04, spec §3). The HUD is already 6px off the bottom
-- edge — that is the floor, not a thing to re-litigate — so the only slack in the stack is
-- here. NOT below 36: banking is the one irreversible action on this surface. The throw
-- buttons' 44px floor does not bind, because that floor was set for the three targets a player
-- hits every round under time pressure.
HudLayout.BANK_H = 36

-- BANK_GAP is now actually the gap. It was declared for it and then only OnboardingController
-- read it, while HudController and CLUSTER_TOP_FROM_BOTTOM positioned the row with ROW_GAP (10)
-- — so the constant named for this gap had never been this gap. All three read it now, and the
-- correction is worth 2 of the 6 pixels this round reclaims.
HudLayout.BANK_GAP = 8

-- The tape+buttons cluster's own height, per tier. The TAPE IS BELOW THE BUTTONS now (owner's
-- ruling); the height is unchanged because the same two rows and one gap are in it either way.
-- The ring does not live in this row (it takes the hamburger's old slot beside the buttons), so
-- this derivation is untouched by the ring's arrival.
HudLayout.AREA_H = HudLayout.BTN_H + HudLayout.ROW_GAP + HudLayout.TILE
HudLayout.AREA_H_TOUCH = HudLayout.BTN_H_TOUCH + HudLayout.ROW_GAP + HudLayout.TILE_TOUCH

-- The throw-button row's width — promoted from HudController on 2026-09-03, when
-- SplashController turned out to be the second file deriving it (with hand-copied literals),
-- and clusterRef below needed it too. The buttons are square (BTN_W tracks BTN_H), so the row
-- is three button-heights plus two gaps.
HudLayout.BTN_GAP = 10
HudLayout.BTN_GAP_TOUCH = 8
HudLayout.AREA_W = 3 * HudLayout.BTN_H + 2 * HudLayout.BTN_GAP
HudLayout.AREA_W_TOUCH = 3 * HudLayout.BTN_H_TOUCH + 2 * HudLayout.BTN_GAP_TOUCH

-- ===== The cluster's horizontal reference (owner's portrait gate, 2026-09-03) =====
-- Returns (scale, offset): the right edge of the throw area sits at
-- `UDim2.new(scale, offset + inboardDx, ...)`. LANDSCAPE is the owner's untouched right-thumb
-- registration ("players need to be able to reach it with their right thumbs to throw").
-- PORTRAIT breaks that expression — JUMP_CLEARANCE is a fraction of the WIDTH, and a portrait
-- phone's width makes 15% narrower than the jump button itself, which buried the scissors
-- button — so portrait centres the always-visible row (ring + gap + three buttons) at the
-- bottom, between Roblox's thumbstick and jump zones. A square viewport counts as landscape.
--
-- A PURE function of this module's own numbers — no Roblox globals, no runtime measuring —
-- which is what keeps it inside this module's Lune-testability rule (see HudLayout.spec's
-- amended numbers-only test). Callers pass their gui's AbsoluteSize and their own touch tier,
-- and MUST re-call on AbsoluteSize changes: rotation moves the reference.
-- Portrait's leftward nudge, in pixels. Dead-centre portrait still grazed the jump button on
-- the owner's iPhone (2026-09-03 cold walk: "the scissor throw button is still a bit beneath
-- the Roblox Jump button"), because the jump button is a FIXED-size zone eating the right edge
-- while the centred row scales with the screen. The whole cluster slides left by this much in
-- portrait only; landscape is untouched (the standing right-thumb ruling). THE tuning knob for
-- the next phone report — nothing downstream carries its own copy.
HudLayout.PORTRAIT_NUDGE = 20

function HudLayout.clusterRef(viewportX: number, viewportY: number, touch: boolean): (number, number)
    if viewportY > viewportX then
        local ringD = if touch then HudLayout.RING_D_TOUCH else HudLayout.RING_D
        local areaW = if touch then HudLayout.AREA_W_TOUCH else HudLayout.AREA_W
        return 0.5, (ringD + HudLayout.RING_GAP + areaW) / 2 - HudLayout.PORTRAIT_NUDGE
    end
    return 1 - HudLayout.JUMP_CLEARANCE, 0
end

-- Where the bank+throws+tape cluster's footprint begins, measured UP from the bottom edge.
-- The bank row counts whether or not its button is visible, exactly as the old slot did.
-- There is no PLATE_BOTTOM counterpart any more: the plate has left the top band entirely, so
-- the only thing an onboarding card has to clear up there is the toast (see
-- OnboardingController).
HudLayout.CLUSTER_TOP_FROM_BOTTOM = HudLayout.EDGE + HudLayout.AREA_H + HudLayout.BANK_GAP + HudLayout.BANK_H
HudLayout.CLUSTER_TOP_FROM_BOTTOM_TOUCH = HudLayout.EDGE
    + HudLayout.AREA_H_TOUCH
    + HudLayout.BANK_GAP
    + HudLayout.BANK_H

return HudLayout
