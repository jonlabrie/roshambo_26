--!strict
-- Pure destination resolver for the home portal (2026-07-19 spec). No Roblox datatypes (the
-- runtime composes CFrames from these 12-number arrays where CFrame exists) -> Lune-testable.
-- Forward-compat: deckLanding resolves from a pad's deck CFrame, so a future guest pass supplies a
-- friend's pad and gets the same resolution; ARENA_LANDING is a single destination that later
-- becomes a parameter without reworking callers.
local PortalTarget = {}

-- local {dx,dy,dz} where a portal arrival stands ON the deck: up to HRP height, back toward the
-- walkable centre, facing the deck's forward (= the view). Gate-tuned; placeholder identical per
-- size for now (per-size tuning waits for the visual gate).
PortalTarget.DECK_LANDING_LOCAL = {
    S = { 0, 3, -4 },
    M = { 0, 3, -4 },
    L = { 0, 3, -4 },
} :: { [string]: { number } }

-- Where the Arena Portal structure builds, and where arrivals land beside it. Gate-tuned
-- placeholders near ArenaSpawn (dialed in during the visual gate).
PortalTarget.ARENA_PORTAL_CF = { 0, 30, 40, 1, 0, 0, 0, 1, 0, 0, 0, 1 } :: { number }
PortalTarget.ARENA_LANDING = { 0, 30, 46, 1, 0, 0, 0, 1, 0, 0, 0, 1 } :: { number }

function PortalTarget.deckLanding(deckCF12: { number }, deckSize: string): { number }
    local o = PortalTarget.DECK_LANDING_LOCAL[deckSize] or PortalTarget.DECK_LANDING_LOCAL.L
    local px, py, pz = deckCF12[1], deckCF12[2], deckCF12[3]
    local r00, r01, r02 = deckCF12[4], deckCF12[5], deckCF12[6]
    local r10, r11, r12 = deckCF12[7], deckCF12[8], deckCF12[9]
    local r20, r21, r22 = deckCF12[10], deckCF12[11], deckCF12[12]
    -- world = deckPos + deckRot * localOffset (offset has identity rotation, so only its
    -- translation is rotated); the deck's rotation is preserved so the arrival faces the view.
    local wx = px + r00 * o[1] + r01 * o[2] + r02 * o[3]
    local wy = py + r10 * o[1] + r11 * o[2] + r12 * o[3]
    local wz = pz + r20 * o[1] + r21 * o[2] + r22 * o[3]
    return { wx, wy, wz, r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

return PortalTarget
