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

-- The tape+buttons cluster's own height.
HudLayout.AREA_H = HudLayout.TILE + HudLayout.ROW_GAP + HudLayout.BTN_H

-- The band the minimal HUD does NOT own, both measured in the HUD ScreenGui's own coordinate space
-- (which leaves IgnoreGuiInset at its default false — see OnboardingController).
--   PLATE_BOTTOM           : where the plate's footprint ends, measured DOWN from the top edge.
--   CLUSTER_TOP_FROM_BOTTOM: where the tape+buttons+slot cluster's footprint begins, measured UP
--                            from the bottom edge. The slot's frame occupies its space whether or
--                            not its tenant is visible, so it counts even when empty.
HudLayout.PLATE_BOTTOM = HudLayout.EDGE + HudLayout.PLATE_H
HudLayout.CLUSTER_TOP_FROM_BOTTOM = HudLayout.EDGE + HudLayout.AREA_H + HudLayout.ROW_GAP + HudLayout.SLOT_H

return HudLayout
