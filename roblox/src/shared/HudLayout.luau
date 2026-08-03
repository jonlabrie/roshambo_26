--!strict
-- The minimal HUD's layout skeleton — the handful of numbers MORE THAN ONE file has to agree on
-- exactly (spec: docs/superpowers/specs/2026-08-02-play-hud-design.md).
--
-- HudController places the plate, the tape+throw cluster and the one slot; OnboardingController has
-- to put cards BESIDE them without ever covering a live button, so it derives its safe band from the
-- same numbers. That derivation was hand-copied — `AREA_H = 120 -- TILE(34) + ROW_GAP(10) + BTN_H(76)`
-- — which means a later tweak to BTN_H would silently move the cluster while the onboarding clamp
-- went on believing the old height, and the safe band is the only thing standing between a card and
-- the BANK THESE button. One source, imported by both.
--
-- Numbers that only ONE file uses (PLATE_W, BTN_W/BTN_GAP, TILE_GAP, the toast/timer sizes) stay
-- local to that file — this module is for the shared skeleton, not for every constant in the HUD.
--
-- No Roblox globals: plain numbers only, so it stays Lune-testable like everything else in
-- src/shared.
local HudLayout = {}

-- SCALE, not pixels: the jump button occupies roughly the right 3-13% of the screen, so the throw
-- area is held inboard by a fraction of the width rather than a pixel guess.
HudLayout.JUMP_CLEARANCE = 0.15

HudLayout.EDGE = 12 -- margin from every screen edge
HudLayout.PLATE_H = 46 -- the top-centre player-state plate
HudLayout.TILE = 34 -- one World-Throw tape tile
HudLayout.ROW_GAP = 10 -- tape -> throw buttons, and cluster -> slot
HudLayout.BTN_H = 76 -- one throw button
HudLayout.SLOT_H = 40 -- the one slot above the throw row (pot indicator / fate prompt)
HudLayout.SLOT_GAP = 8

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

-- The tape+buttons cluster's own height, per tier.
HudLayout.AREA_H = HudLayout.TILE + HudLayout.ROW_GAP + HudLayout.BTN_H
HudLayout.AREA_H_TOUCH = HudLayout.TILE_TOUCH + HudLayout.ROW_GAP + HudLayout.BTN_H_TOUCH

-- The confirm strip: the row directly above the slot, which carries "TAP AGAIN TO THROW" and the
-- "don't ask again" control while a throw is waiting on its second tap (see HudController). It is
-- TRANSIENT — it exists only while a confirm is pending — but its row is reserved here PERMANENTLY,
-- exactly as the slot's frame is: an onboarding card clamped into a band that ignored it would land
-- on top of the one message telling the player their throw has not gone in yet, and the moment it
-- appears (the round after a first win) is the same moment the "win" beat's card is on screen.
-- Reserving costs the band 36px of the 48 the touch tier just gave it back.
HudLayout.CONFIRM_H = 28
HudLayout.CONFIRM_GAP = 8

-- The band the minimal HUD does NOT own, both measured in the HUD ScreenGui's own coordinate space
-- (which leaves IgnoreGuiInset at its default false — see OnboardingController).
--   PLATE_BOTTOM           : where the plate's footprint ends, measured DOWN from the top edge.
--   CLUSTER_TOP_FROM_BOTTOM: where the tape+buttons+slot+confirm cluster's footprint begins,
--                            measured UP from the bottom edge. The slot's frame and the confirm
--                            strip's row occupy their space whether or not their tenants are
--                            visible, so both count even when empty.
-- The plate does not change with the tier, so PLATE_BOTTOM has no touch variant; the cluster does.
HudLayout.PLATE_BOTTOM = HudLayout.EDGE + HudLayout.PLATE_H
HudLayout.CLUSTER_TOP_FROM_BOTTOM = HudLayout.EDGE
    + HudLayout.AREA_H
    + HudLayout.ROW_GAP
    + HudLayout.SLOT_H
    + HudLayout.CONFIRM_GAP
    + HudLayout.CONFIRM_H
HudLayout.CLUSTER_TOP_FROM_BOTTOM_TOUCH = HudLayout.EDGE
    + HudLayout.AREA_H_TOUCH
    + HudLayout.ROW_GAP
    + HudLayout.SLOT_H
    + HudLayout.CONFIRM_GAP
    + HudLayout.CONFIRM_H

return HudLayout
